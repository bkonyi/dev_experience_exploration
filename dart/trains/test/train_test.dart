// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:isolate';

import 'package:test/test.dart';
import 'package:trains/src/trains/track.dart';

import 'package:trains/src/trains/train.dart';
import 'package:trains/src/trains/train_conductor.dart';

import 'package:trains/tracks.dart';

void expectTrainStopped(Train train) {
  expect(train.position.offset, 0);
  expect(train.isStopped, true);
  expect(train.physics.currentStoppingDistance, 0.0);
  expect(
    train.physics.currentStoppingDistance,
    lessThan(train.physics.maxStoppingDistance),
  );
}

void tick(Train train) {
  train.updatePosition(testDuration: const Duration(seconds: 1));
}

void main() {
  group('Train', () {
    late Train train;

    setUp(() {
      final track = Track.fromGraph(verticies: buildSimpleTrack());
      conductorInstance = TrainConductor(
        name: 'Test Train',
        track: track,
        startDirection: TrainDirection.forward,
        startPosition: track.verticies.first,
        sendPort: ReceivePort().sendPort,
      );
      train = conductorInstance.train;
    });

    test('accelerates to max velocity then decelerates to a stop', () {
      final accelerationRate = train.physics.accelerationRate;
      final decelerationRate = train.physics.decelerationRate.abs();
      final maxSpeed = train.physics.maxSpeed;

      // Train starts stopped
      expectTrainStopped(train);
      train.start();

      // Accelerate the train
      final ticksUntilMaxVelocity = (maxSpeed / accelerationRate).ceil();
      for (int ticks = 1; ticks < ticksUntilMaxVelocity; ++ticks) {
        tick(train);
        expect(train.physics.currentVelocity <= maxSpeed, true);
        expect(train.physics.currentVelocity, accelerationRate * ticks);
        expect(
          train.physics.currentStoppingDistance,
          lessThan(train.physics.maxStoppingDistance),
        );
      }

      // The train should be at maximum velocity
      tick(train);
      expect(train.physics.currentVelocity, maxSpeed);
      expect(
        train.physics.currentStoppingDistance,
        train.physics.maxStoppingDistance,
      );

      // Tell the train to stop
      train.stop();
      final ticksUntilStop =
          (train.physics.currentVelocity / decelerationRate).ceil();
      for (int ticks = 1; ticks < ticksUntilStop; ++ticks) {
        tick(train);
        expect(train.physics.currentVelocity > 0, true);
        expect(
            train.physics.currentVelocity, maxSpeed - ticks * decelerationRate);
        expect(
          train.physics.currentStoppingDistance,
          lessThan(train.physics.maxStoppingDistance),
        );
      }

      // The train should reach a stop
      tick(train);
      expect(train.isStopped, true);
      expect(
        train.physics.currentStoppingDistance,
        0,
      );
    });

    test(
        'accelerates to max velocity, slows to a stop, and then changes direction',
        () {
      final accelerationRate = train.physics.accelerationRate;
      final decelerationRate = train.physics.decelerationRate.abs();
      final maxVelocity = train.physics.maxSpeed;

      // Train starts stopped
      expectTrainStopped(train);
      train.start();

      // Accelerate the train
      final ticksUntilMaxVelocity = (maxVelocity / accelerationRate).ceil();
      for (int ticks = 1; ticks < ticksUntilMaxVelocity; ++ticks) {
        tick(train);
        expect(train.physics.currentVelocity <= maxVelocity, true);
        expect(train.physics.currentVelocity, accelerationRate * ticks);
        expect(
          train.physics.currentStoppingDistance,
          lessThan(train.physics.maxStoppingDistance),
        );
      }

      // The train should be at maximum velocity
      tick(train);
      expect(train.physics.currentVelocity, maxVelocity);
      expect(
        train.physics.currentStoppingDistance,
        train.physics.maxStoppingDistance,
      );

      // Tell the train to stop
      train.accelerate(direction: train.physics.direction.inverted);
      final ticksUntilStop =
          (train.physics.currentVelocity / decelerationRate).ceil();
      for (int ticks = 1; ticks < ticksUntilStop; ++ticks) {
        tick(train);
        expect(train.physics.currentVelocity > 0, true);
        expect(train.physics.currentVelocity,
            maxVelocity - ticks * decelerationRate);
        expect(
          train.physics.currentStoppingDistance,
          lessThan(train.physics.maxStoppingDistance),
        );
      }

      // The train should reach a stop
      tick(train);
      expect(train.isStopped, true);
      expect(train.physics.currentStoppingDistance, 0);

      // The train should reverse direction after stopping
      for (int ticks = 1; ticks < ticksUntilMaxVelocity; ++ticks) {
        tick(train);
        expect(train.physics.currentVelocity >= -maxVelocity, true);
        expect(train.physics.currentVelocity, -accelerationRate * ticks);
        expect(
          train.physics.currentStoppingDistance,
          lessThan(train.physics.maxStoppingDistance),
        );
      }

      // The train should be at maximum negative velocity
      tick(train);
      expect(train.physics.currentVelocity, -maxVelocity);
      expect(
        train.physics.currentStoppingDistance,
        train.physics.maxStoppingDistance,
      );
    });
  });
}
