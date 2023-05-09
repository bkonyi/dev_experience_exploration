// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math';

class TrainConductor {
  TrainConductor({required this.name});

  final String name;
  final physics = TrainPhysics();
  final position = TrackPosition();
  late DateTime _lastUpdate;
  bool get isStopped => physics.currentVelocity == 0;

  void initialize() {
    _lastUpdate = DateTime.now();
  }

  /// Updates the current position of the train given a duration.
  /// 
  /// [testDuration] can be provided to update the position of the train based
  /// on a known duration, which is useful for writing deterministic tests.
  /// 
  /// If [testDuration] is not provided, the duration will be determined based
  /// on the time since the last update was performed.
  void updatePosition({Duration? testDuration}) {
    double updateDuration;
    if (testDuration != null) {
      updateDuration = testDuration.inMilliseconds / 1000;
      _lastUpdate = _lastUpdate.add(testDuration);
    } else {
      final currentTime = DateTime.now();
      updateDuration =
          currentTime.difference(_lastUpdate).inMilliseconds / 1000;
      _lastUpdate = currentTime;
    }
    physics.update(
      updateDuration: updateDuration,
      positionState: position,
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
  bool stopping = false;
  bool changingDirection = false;

  /// Returns true if the train has a velocity of 0.
  bool get isStopped => _currentSpeed == 0;

  double get currentVelocity => _currentSpeed * direction.coefficient;
  double _currentSpeed = 0.0;

  /// The maximum speed the train can travel.
  final double maxSpeed = 10.0;

  void update({
    required double updateDuration,
    required TrackPosition positionState,
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
    positionState.updatePosition(updates.position);
  }

  void changeDirection() {
    if (isStopped) {
      direction = direction.inverted;
      return;
    }
    changingDirection = true;
    stopping = true;
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
    final speed = max(_currentSpeed - deltaV, 0.0);
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

class TrackPosition {
  double offset = 0;
  String trackSegment = 'A->B';

  void updatePosition(double distanceTravelled) {
    offset += distanceTravelled;
  }

  @override
  String toString() => '[segment: $trackSegment offset: $offset]';
}
