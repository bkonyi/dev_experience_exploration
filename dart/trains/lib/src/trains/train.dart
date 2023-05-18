// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:trains/src/trains/track.dart';
import 'package:trains/src/trains/train_conductor.dart';

class Train {
  Train({
    required this.conductor,
    required this.name,
    required this.track,
    required TrainDirection startDirection,
    required TrackNode startPosition,
  }) {
    position = TrainPosition(train: this, node: startPosition);
    physics.direction = startDirection;
  }

  final TrainConductor conductor;
  final String name;
  final Track track;

  final physics = TrainPhysics();
  late final TrainPosition position;

  late DateTime _lastUpdate;
  bool get isStopped => physics.currentVelocity == 0;

  TrainDirection get direction => physics.direction;

  bool _updatesActive = false;

  void startTrainUpdates() {
    if (_updatesActive) return;
    _updatesActive = true;
    const updateFrequencyMs = 10;
    _lastUpdate = DateTime.now();
    Timer.periodic(const Duration(milliseconds: updateFrequencyMs), (timer) {
      updatePosition(notify: timer.tick % (1000 / updateFrequencyMs) == 0);
      if (timer.tick % (1000 / updateFrequencyMs) == 0) {
        print(this);
      }
    });
  }

  /// Updates the current position of the train given a duration.
  ///
  /// [testDuration] can be provided to update the position of the train based
  /// on a known duration, which is useful for writing deterministic tests.
  ///
  /// If [testDuration] is not provided, the duration will be determined based
  /// on the time since the last update was performed.
  void updatePosition({Duration? testDuration, bool notify = false}) {
    double updateDuration;
    if (testDuration != null) {
      updateDuration = testDuration.inMicroseconds / 1000000;
      _lastUpdate = _lastUpdate.add(testDuration);
    } else {
      final currentTime = DateTime.now();
      updateDuration =
          currentTime.difference(_lastUpdate).inMicroseconds / 1000000;
      _lastUpdate = currentTime;
    }
    physics.update(
      updateDuration: updateDuration,
      positionState: position,
      notify: notify,
    );
  }

  /// Tells the train to accelerate in [direction].
  ///
  /// If the train is already moving in [direction], it will start accelerating
  /// in that direction if it was previously slowing down to a stop.
  ///
  /// If the train is moving in [TrainDirection.inverted], the train will first
  /// come to a stop before accelerating in the opposite direction.
  void accelerate({required TrainDirection direction}) {
    if (direction != physics.direction) {
      physics.changeDirection();
    } else {
      physics.stopping = false;
      physics.changingDirection = false;
    }
  }

  void changeDirection() {
    physics.changeDirection();
    position.changeDirection();
  }

  void start() {
    physics.stopping = false;
  }

  /// Tells the train to come to a stop.
  void stop() {
    physics.stopping = true;
  }

  @override
  String toString() => '[$name] position: $position physics: $physics';
}

enum TrainDirection {
  forward(1),
  backward(-1);

  TrainDirection get inverted => this == forward ? backward : forward;

  /// The velocity coefficient based on the train's direction.
  final int coefficient;

  const TrainDirection(this.coefficient);
}

class TrainPhysics {
  /// The rate at which the train will accelerate in units per second.
  final double accelerationRate = 2.0;

  /// The rate at which the train will decelerate in units per second.
  final double decelerationRate = -2.0;

  TrainDirection direction = TrainDirection.forward;
  bool stopping = true;
  bool changingDirection = false;

  /// Returns true if the train has a velocity of 0.
  bool get isStopped => _currentSpeed == 0;

  /// The stopping distance of the train given its current speed.
  double get currentStoppingDistance {
    final timeToStop = (_currentSpeed / decelerationRate).abs();
    return _distanceTravelledWithConstantAcceleration(
      v0: _currentSpeed,
      t: timeToStop,
      a: decelerationRate,
    );
  }

  /// The stopping distance of the train at its max speed.
  double get maxStoppingDistance {
    final timeToStop = (maxSpeed / decelerationRate).abs();
    return _distanceTravelledWithConstantAcceleration(
      v0: maxSpeed,
      t: timeToStop,
      a: decelerationRate,
    );
  }

  double get distanceTravelledWhileAcceleratingFromStop {
    return _distanceTravelledWithConstantAcceleration(
      v0: 0,
      t: timeToMaxSpeed,
      a: accelerationRate,
    );
  }

  double get timeToMaxSpeed {
    return (maxSpeed / accelerationRate);
  }

  double get currentVelocity => _currentSpeed * direction.coefficient;
  double _currentSpeed = 0.0;

  /// The maximum speed the train can travel.
  final double maxSpeed = 10.0;

  void update({
    required double updateDuration,
    required TrainPosition positionState,
    required bool notify,
  }) {
    if (changingDirection && isStopped) {
      direction = direction.inverted;
      changingDirection = false;
      stopping = false;
    }
    final updates = stopping
        ? _decelerating(updateDuration: updateDuration)
        : _accelerating(updateDuration: updateDuration);
    _currentSpeed = updates.speed;
    positionState.updatePosition(updates.position, notify);
  }

  void changeDirection() {
    if (isStopped) {
      direction = direction.inverted;
      return;
    }
    changingDirection = true;
    stopping = true;
  }

  void forceStop() {
    if (_currentSpeed > 0.1) {
      throw StateError(
          'Tried to force stop a moving train! Speed: $_currentSpeed');
    }
    _currentSpeed = 0;
  }

  ({double position, double speed}) _accelerating({
    required double updateDuration,
  }) {
    double positionUpdate;
    final initialSpeed = _currentSpeed;
    final deltaV = updateDuration * accelerationRate;

    if (initialSpeed + deltaV > maxSpeed) {
      // Find time to accelerate to max velocity
      final timeToMaxSpeed = (maxSpeed - initialSpeed) / accelerationRate;
      final timeAtMaxSpeed = updateDuration - timeToMaxSpeed;

      // Calculate the distance travelled before we hit our max velocity
      positionUpdate = _distanceTravelledWithConstantAcceleration(
        v0: initialSpeed,
        t: timeToMaxSpeed,
        a: accelerationRate,
      );

      // Add distance travelled after we hit max velocity.
      positionUpdate += timeAtMaxSpeed * maxSpeed;
    } else {
      positionUpdate = _distanceTravelledWithConstantAcceleration(
        v0: initialSpeed,
        t: updateDuration,
        a: accelerationRate,
      );
    }
    final speed = min(_currentSpeed + deltaV, maxSpeed);
    return (position: positionUpdate, speed: speed);
  }

  ({double position, double speed}) _decelerating({
    required double updateDuration,
  }) {
    double positionUpdate;
    final initialSpeed = _currentSpeed;
    final deltaV = updateDuration * decelerationRate;

    if (initialSpeed + deltaV < 0) {
      // Find time to deccelerate to a stop
      final timeToStop = initialSpeed / decelerationRate.abs();

      // Calculate the distance travelled before we stop.
      positionUpdate = _distanceTravelledWithConstantAcceleration(
        v0: initialSpeed,
        t: timeToStop,
        a: decelerationRate,
      );
    } else {
      positionUpdate = _distanceTravelledWithConstantAcceleration(
        v0: initialSpeed,
        t: updateDuration,
        a: decelerationRate,
      );
    }
    final speed = max(_currentSpeed + deltaV, 0.0);
    return (position: positionUpdate, speed: speed);
  }

  // p = v * t + (a * t^2) / 2 for constant acceleration
  static double _distanceTravelledWithConstantAcceleration({
    required double v0,
    required double t,
    required double a,
  }) {
    return v0 * t + (a * pow(t, 2)) / 2.0;
  }

  @override
  String toString() =>
      '[acceleration rates: [$decelerationRate, $accelerationRate], velocity: ($currentVelocity / $maxSpeed)]';
}

class TrainPosition {
  TrainPosition({
    required this.train,
    required this.node,
  }) {
    currentEdge = train.direction == TrainDirection.forward
        ? node.straight
        : node.reverseStraight;
  }

  double offset = 0;
  final Train train;
  TrackNode node;
  TrackEdge? currentEdge;

  void handleBranchDirectionChange() {
    // TODO(bkonyi): merge logic with _nextEdge
    currentEdge = _findNextEdge(node);
    print('${node} Branch direction change: $currentEdge');
    train.conductor.sendPositionEvent();
  }

  void changeDirection() {
    currentEdge = _nextEdge;
    train.conductor.sendPositionEvent();
  }

  void updatePosition(double distanceTravelled, bool notify) {
    final edge = currentEdge;
    if (edge == null) {
      if (distanceTravelled != 0) {
        print('WARNING: Tried to move down an invalid edge!');
      }
      return;
    }
    offset += distanceTravelled;
    while (offset > edge.length) {
      offset = offset - edge.length;
      currentEdge = _nextEdge;
    }

    if (currentEdge == null) {
      // TODO: confirm this is right
      node = edge.destination;
    } else {
      node = currentEdge!.source;
    }
    if (notify) {
      train.conductor.sendPositionEvent();
    }
  }

  /// Forces the train's location to have zero offset, placing it directly on
  /// the current node.
  ///
  /// Called when a train has supposedly come to a full stop. Will throw if the
  /// train isn't within 1 unit of the closest node.
  void normalizeToClosestNode() {
    final edge = currentEdge;
    // The current edge may be null if we're at a terminating node. We're going
    // to assume that the train is coming to stop at the terminal, even if it
    // tries to overshoot.
    if (edge == null) {
      print('No next edge, normalizing to ${node.name}');
      offset = 0;
    } else {
      // If the train isn't within ~1 unit of a target node when we're trying to
      // stop, something went wrong and we're in a bad state.
      // TODO: confirm this is right
      if (edge.length - offset >= 1 && offset >= 1) {
        throw StateError('Train did not stop in range of the target node!');
      }
      if (edge.length - offset < 1) {
        node = edge.destination;
        currentEdge = _nextEdge;
      } else {
        node = edge.source;
      }
      offset = 0;
    }
    train.conductor.sendPositionEvent();
  }

  TrackEdge? get _nextEdge {
    final edge = currentEdge;
    final destinationNode = edge != null ? edge.destination : node;
    return _findNextEdge(destinationNode);
  }

  TrackEdge? _findNextEdge(TrackNode destinationNode) {
    TrackEdge? determineDirection(TrackEdge? straight, TrackEdge? curve) {
      // If there's only one edge in the direction the train is moving, the
      // train must take that edge.
      if (straight == null || curve == null) {
        return straight ?? curve;
      }
      return destinationNode.switchState == BranchDirection.straight
          ? straight
          : curve;
    }

    if (train.direction == TrainDirection.forward) {
      return determineDirection(
        destinationNode.straight,
        destinationNode.curve,
      );
    }
    return determineDirection(
      destinationNode.reverseStraight,
      destinationNode.reverseCurve,
    );
  }

  @override
  String toString() => '[node: $node segment: $currentEdge offset: $offset]';
}
