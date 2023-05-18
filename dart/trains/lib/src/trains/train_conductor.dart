// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:trains/src/trains/track.dart';
import 'package:trains/src/trains/train.dart';

import 'dispatch_events.dart';
import 'navigation_events.dart';

void trainConductorEntry(
  TrainConductorInitializationRequest initializationEvent,
) {
  final track = initializationEvent.track;
  final conductor = TrainConductor(
    name: initializationEvent.name,
    track: track,
    startDirection:
        initializationEvent.startDirection ?? TrainDirection.forward,
    startPosition: initializationEvent.startPosition ??
        track.verticies[Random().nextInt(track.verticies.length)],
    sendPort: initializationEvent.sendPort,
  );
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
    receivePort.listen(_messageHandler);
    sendPort.send(receivePort.sendPort);
    this.train.startTrainUpdates();
    sendPositionEvent();
  }

  final String name;
  final Track track;
  final path = <TrackNode>[];
  final events = <TrainNavigationEvent>[];
  late final Train train;

  final SendPort sendPort;
  final ReceivePort receivePort;

  void _messageHandler(dynamic message) {
    switch (message.runtimeType) {
      case TrainNavigateToRequest:
        navigateTo(message);
      default:
        throw StateError(
          'Unrecognized message: ${message.runtimeType}',
        );
    }
  }

  void navigateTo(TrainNavigateToRequest request) {
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

  void sendPositionEvent() {
    final event = TrainPositionEvent(
      name: name,
      direction: train.direction,
      position: TrainPositionData.fromTrainPosition(train.position),
      velocity: train.physics.currentVelocity,
    );
    sendPort.send(event);
  }

  /// Creates a sequence of [TrainNavigationEvent]s based on a valid path.
  List<TrainNavigationEvent> createEventsFromPath({
    required TrainDirection initialDirection,
    required List<TrackNode> path,
  }) {
    events.clear();
    if (path.length <= 1) {
      return events;
    }
    TrackNode current = path.first;
    TrackNode origin = path.first;
    TrainDirection currentDirection = train.physics.direction;
    double segmentLength = 0.0;

    final (_, _, directionToFirstNode) = _determineNextEdge(
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
        // Ensure the next switch is set to the right direction.
        events.add(SwitchDirectionEvent(
          train: train,
          node: current,
          direction: branch,
        ));
      }
      segmentLength += edge.length;
      current = next;
    }

    events.add(TrainStopEvent(
      train: train,
      origin: origin,
      destination: path.last,
      distance: segmentLength,
    ));

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
