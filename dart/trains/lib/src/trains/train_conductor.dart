// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:trains/src/trains/track.dart';
import 'package:trains/src/trains/train.dart';

import 'dispatch_events.dart';
import 'navigation_events.dart';

late TrainConductor conductorInstance;

void trainConductorEntry(
  TrainConductorInitializationRequest initializationEvent,
) {
  runZonedGuarded(() {
    final track = initializationEvent.track;
    conductorInstance = TrainConductor(
      name: initializationEvent.name,
      track: track,
      startDirection:
          initializationEvent.startDirection ?? TrainDirection.forward,
      startPosition: initializationEvent.startPosition ??
          track.verticies[Random().nextInt(track.verticies.length)],
      sendPort: initializationEvent.sendPort,
    );
  }, (error, stack) {
    conductorInstance.log.shout(error, null, stack);
    conductorInstance.sendExceptionEvent();
  });
}

/// Handles pathfinding and train control.
class TrainConductor {
  TrainConductor({
    required this.name,
    required this.track,
    required TrainDirection startDirection,
    required TrackNode startPosition,
    required this.sendPort,
    Train? train,
  }) : receivePort = ReceivePort('Conductor for $name') {
    this.train = train ??
        Train(
          conductor: this,
          name: name,
          track: track,
          startDirection: startDirection,
          startPosition: startPosition,
        );
    Logger.root.level = Level.FINE;
    Logger.root.onRecord.listen((record) {
      if (record.stackTrace != null) {
        print(
            '[${DateTime.now()}][${record.loggerName}] EXCEPTION: ${record.message}\n${record.stackTrace}');
        return;
      }
      print('[${DateTime.now()}][${record.loggerName}] ${record.message}');
    });
    receivePort.listen(_messageHandler);
    sendPort.send(receivePort.sendPort);
    this.train.startTrainUpdates();
    sendPositionEvent();
  }

  late final log = Logger(name);
  final String name;
  final Track track;
  final edgePath = <TrackEdge>[];
  final currentReservations = <TrackElement>[];
  final events = <TrainNavigationEvent>[];
  late final Train train;

  final SendPort sendPort;
  final ReceivePort receivePort;
  Completer<void>? _trackReservationResponseCompleter;

  void _messageHandler(dynamic message) => switch (message) {
        TrainNavigateToRequest() => navigateTo(message),
        TrackReservationConfirmation() => _confirmReservation(),
        Object() || null => throw StateError(
            'Unrecognized message: ${message.runtimeType}',
          ),
      };

  void navigateTo(TrainNavigateToRequest request) {
    log.fine('Start node: ${train.position.node}');
    final path = track.findPath(
      start: train.position.node,
      finish: request.destination,
    );
    createEventsFromPath(
      initialDirection: train.direction,
      path: path,
    );
    execute();
  }

  void _confirmReservation() {
    final completer = _trackReservationResponseCompleter;
    if (completer == null) {
      throw StateError('Attempted to confirm non-existent reservation!');
    }
    _trackReservationResponseCompleter = null;
    completer.complete();
  }

  void sendExceptionEvent() {
    sendPort.send(const ExceptionEvent());
  }

  void sendPositionEvent() {
    final event = TrainPositionEvent(
      name: name,
      direction: train.direction,
      position: TrainPositionData.fromTrainPosition(train.position),
      velocity: train.physics.currentVelocity,
    );
    sendPort.send(event);
  }

  Future<void> sendTrackReservationRequest(TrackElement element) async {
    if (element is TrackEdge && !edgePath.contains(element)) {
      throw StateError(
        'Attempted to reserve $element, which is not in $edgePath!',
      );
    }
    sendPort.send(TrackReservationRequest(element: element));
    _trackReservationResponseCompleter = Completer<void>();
    await _trackReservationResponseCompleter!.future;
    log.fine('Reserved $element!');
    currentReservations.add(element);
    return;
  }

  void sendTrackReservationRelease(TrackElement element) {
    log.fine('Releasing reservation for $element');
    log.fine('Current reservations: $currentReservations');
    currentReservations.removeAt(0);
    log.fine('Remaining path: $edgePath');
    log.fine('Remaining reservations: $currentReservations');

    // TODO(bkonyi): check for nodes as well.
    if (element is TrackEdge) {
      final expected = edgePath.removeAt(0);
      if (expected != element) {
        throw StateError(
          'Attempted to release reservation for $element when the expected edge is $expected',
        );
      }
    }
    sendPort.send(TrackReservationRelease(element: element));
  }

  /// Creates a sequence of [TrainNavigationEvent]s based on a valid path.
  List<TrainNavigationEvent> createEventsFromPath({
    required TrainDirection initialDirection,
    required List<TrackNode> path,
  }) {
    events.clear();
    edgePath.clear();
    if (path.length <= 1) {
      return events;
    }
    log.fine('Creating events for path: $path');
    TrackNode current = path.first;
    TrackNode origin = path.first;
    TrainDirection currentDirection = train.physics.direction;
    double segmentLength = 0.0;

    final (edge, _, directionToFirstNode) = _determineNextEdge(
      from: current,
      to: path[1],
    );

    // If the train is immediately changing direction at the beginning of the
    // path, just flip the direction of the train.
    if (directionToFirstNode != currentDirection) {
      currentDirection = directionToFirstNode;
      events.add(TrainDirectionEvent(
        train: train,
        direction: currentDirection,
      ));
    }

    // Acquire the first track reservation before starting to move.
    // TODO(bkonyi): this reservation is required for correctness.
    events.add(TrackReservationEvent(
      train: train,
      element: current,
    ));
    events.add(TrackReservationEvent(
      train: train,
      element: edge,
    ));
    events.add(TrackReservationEvent(
      train: train,
      element: path[1],
    ));

    // Start moving.
    events.add(TrainStartEvent(train: train));

    for (int i = 0; i < path.length - 1; ++i) {
      final next = path[i + 1];
      final (edge, branch, direction) =
          _determineNextEdge(from: current, to: next);

      // The train needs to stop when changing direction, so terminate the
      // navigation event and start the next one.
      if (direction != currentDirection) {
        // If the train requires a direction change to get to `next`, we need
        // to first stop, flip the direction, and then start moving.
        events.add(TrainStopEvent(
          train: train,
          origin: origin,
          destination: current,
          distance: segmentLength,
        ));

        events.add(TrainDirectionEvent(
          train: train,
          direction: direction,
        ));

        events.add(TrackReservationEvent(
          train: train,
          element: edge,
        ));

        events.add(TrackReservationEvent(
          train: train,
          element: next,
        ));

        // Ensure the switch is set to the right direction. This needs to be
        // done after the train has stopped and changed its direction,
        // otherwise the train will follow the wrong path.
        events.add(SwitchDirectionEvent(
          train: train,
          node: current,
          direction: branch,
        ));

        events.add(TrainStartEvent(
          train: train,
        ));

        // Reset state for next navigation segment.
        origin = current;
        currentDirection = direction;
        segmentLength = 0.0;
      } else {
        // Special case. We can't start moving until we've reserved the first
        // track edge.
        if (i != 0) {
          events.add(TrackReservationEvent(
            train: train,
            element: edge,
          ));

          events.add(TrackReservationEvent(
            train: train,
            element: next,
          ));
        }

        // Ensure the next switch is set to the right direction.
        events.add(SwitchDirectionEvent(
          train: train,
          node: current,
          direction: branch,
        ));
      }
      segmentLength += edge.length;
      edgePath.add(edge);
      current = next;
    }

    events.add(TrainStopEvent(
      train: train,
      origin: origin,
      destination: path.last,
      distance: segmentLength,
    ));

    log.fine('Events:');
    int i = 0;
    for (final event in events) {
      log.fine('  [$i] $event');
      ++i;
    }
    return events;
  }

  Future<void> execute() async {
    for (final event in events) {
      await event.execute();
    }
    sendPort.send(const TrainNavigationCompleteEvent());
  }

  (TrackEdge, BranchDirection, TrainDirection) _determineNextEdge({
    required TrackNode from,
    required TrackNode to,
  }) {
    if (from.curve?.destination == to) {
      return (
        from.curve!,
        BranchDirection.curve,
        TrainDirection.forward,
      );
    }
    if (from.straight?.destination == to) {
      return (
        from.straight!,
        BranchDirection.straight,
        TrainDirection.forward,
      );
    }
    if (from.reverseCurve?.destination == to) {
      return (
        from.reverseCurve!,
        BranchDirection.curve,
        TrainDirection.backward,
      );
    }
    if (from.reverseStraight?.destination == to) {
      return (
        from.reverseStraight!,
        BranchDirection.straight,
        TrainDirection.backward,
      );
    }
    throw StateError('Could not find next edge!');
  }
}
