// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'track.dart';
import 'train.dart';

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
