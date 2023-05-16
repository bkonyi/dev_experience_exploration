// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:trains/src/trains/track.dart';
import 'package:trains/src/trains/train.dart';

/// Handles pathfinding and train control.
class TrainConductor {
  TrainConductor({
    required this.name,
    required this.track,
    required TrainDirection startDirection,
    required TrackNode startPosition,
    bool autoUpdatePosition = true,
    Train? train,
  }) : train = train ??
            Train(
              name: name,
              track: track,
              startDirection: startDirection,
              startPosition: startPosition,
              autoUpdatePosition: autoUpdatePosition,
            );

  final String name;
  final Track track;
  final path = <TrackNode>[];
  final events = <TrainNavigationEvent>[];
  final Train train;

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

sealed class TrainNavigationEvent {
  TrainNavigationEvent({
    required this.train,
  });

  final Train train;

  Future<void> execute();
}

class TrainStopEvent extends TrainNavigationEvent {
  TrainStopEvent({
    required super.train,
    required this.origin,
    required this.destination,
    required this.distance,
  });

  final TrackNode origin;
  final TrackNode destination;
  final double distance;

  @override
  Future<void> execute() async {
    late double timeToTriggerStop;
    late double timeToStop;

    // TODO: this is assuming that the acceleration rate is the same as the
    // deceleration rate.
    if (train.physics.maxStoppingDistance > distance / 2) {
      // The train won't be able to get to max speed before needing to decelerate.
      timeToTriggerStop = sqrt(distance / train.physics.accelerationRate);
      timeToStop = timeToTriggerStop;
    } else {
      // If the train can get to its max speed, we just need to find out how long
      // it will take to get to (distance - maxStoppingDistance) and then set a
      // timer to start decelerating at that point.
      final decelarationThreshold =
          distance - train.physics.maxStoppingDistance;

      final distanceWhileAccelerating =
          train.physics.distanceTravelledWhileAcceleratingFromStop;
      final timeAccelerating =
          train.physics.maxSpeed / train.physics.accelerationRate;
      final distanceWhileAtMaxSpeed =
          decelarationThreshold - distanceWhileAccelerating;
      final timeAtMaxSpeed = distanceWhileAtMaxSpeed / train.physics.maxSpeed;

      timeToTriggerStop = timeAccelerating + timeAtMaxSpeed;
      timeToStop =
          train.physics.maxSpeed / train.physics.decelerationRate.abs();
    }

    final completer = Completer<void>();
    print('[${train.name}] Scheduling stop in ${timeToTriggerStop}s');
    Timer(
        Duration(
          milliseconds: (timeToTriggerStop * 1000).floor(),
        ), () {
      train.stop();
      print('[${train.name}] Stopping train');
      Timer(Duration(milliseconds: (timeToStop * 1000).floor()), () {
        print('[${train.name}] Stopped at ${train.position}');

        // The train probably won't stop exactly as the destination, but
        // we should be within ~1 unit and then just make an adjustment so we
        // stop at the destination exactly.
        train.position.normalizeToClosestNode();
        train.physics.forceStop();

        print('[${train.name}] Normalized: ${train.position}');

        completer.complete();
      });
    });
    return completer.future;
  }

  @override
  bool operator ==(Object other) {
    if (other is! TrainStopEvent) return false;
    return super.train == other.train &&
        origin == other.origin &&
        destination == other.destination;
  }

  @override
  int get hashCode => Object.hashAll([train, origin, destination]);

  @override
  String toString() =>
      '[TrainStopEvent] ${origin.name} -> ${destination.name} ($distance)';
}

class TrainStartEvent extends TrainNavigationEvent {
  TrainStartEvent({required super.train});

  @override
  Future<void> execute() async {
    if (!train.isStopped) {
      throw StateError('Tried to start train that is moving!');
    }
    print('[${train.name}] Starting acceleration');
    train.start();
  }

  @override
  bool operator ==(Object other) {
    if (other is! TrainStartEvent) return false;
    return super.train == other.train;
  }

  @override
  int get hashCode => Object.hashAll([train]);

  @override
  String toString() => '[TrainStartEvent]';
}

class TrainDirectionEvent extends TrainNavigationEvent {
  TrainDirectionEvent({
    required super.train,
    required this.direction,
  });

  final TrainDirection direction;

  @override
  Future<void> execute() async {
    if (!train.isStopped) {
      print('Train speed: ${train.physics.currentVelocity}');
      throw StateError('Tried to change train direction while moving!');
    }
    train.changeDirection();
    if (train.direction != direction) {
      throw StateError('Unexpected train direction!');
    }
    print('[${train.name}] Setting train direction to ${train.direction}');
  }

  @override
  bool operator ==(Object other) {
    if (other is! TrainDirectionEvent) return false;
    return super.train == other.train && direction == other.direction;
  }

  @override
  int get hashCode => Object.hashAll([train, direction]);

  @override
  String toString() => '[TrainDirectionEvent] ${direction.name}';
}

class SwitchDirectionEvent extends TrainNavigationEvent {
  SwitchDirectionEvent({
    required super.train,
    required this.node,
    required this.direction,
  });

  final TrackNode node;
  final BranchDirection direction;

  @override
  Future<void> execute() async {
    if (node.edgeCount != 3) {
      if (direction == BranchDirection.straight) {
        return;
      }
      throw StateError(
        'Tried to switch the branch direction on a node with no branch!',
      );
    }
    print(
      '[${train.name}] switching ${node.name} branch from ${node.switchState}->$direction',
    );
    node.switchState = direction;
    train.position.handleBranchDirectionChange();
  }

  @override
  bool operator ==(Object other) {
    if (other is! SwitchDirectionEvent) return false;
    return super.train == other.train &&
        direction == other.direction &&
        node == other.node;
  }

  @override
  int get hashCode => Object.hashAll([train, direction, node]);
  @override
  String toString() => '[SwitchDirectionEvent] ${node.name} ${direction.name}';
}
