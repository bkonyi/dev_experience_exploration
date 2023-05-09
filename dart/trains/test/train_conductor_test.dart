// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:developer';

import 'package:test/test.dart';

import 'package:trains/src/train_conductor.dart';

void expectTrainStopped(TrainConductor train) {
  expect(train.position.offset, 0);
  expect(train.isStopped, true);
}

void tick(TrainConductor train) {
  train.updatePosition(testDuration: const Duration(seconds: 1));
}

void main() {
  group('TrainConductor', () {
    late TrainConductor train;

    setUp(() {
      train = TrainConductor(name: 'Test Train')..initialize();
    });

    test('accelerates to max velocity then decelerates to a stop', () {
      final accelerationRate = train.physics.accelerationRate;
      final decelerationRate = train.physics.decelerationRate;
      final maxVelocity = train.physics.maxSpeed;

      // Train starts stopped
      expectTrainStopped(train);

      // Accelerate the train
      final ticksUntilMaxVelocity = (maxVelocity / accelerationRate).ceil();
      for (int ticks = 1; ticks < ticksUntilMaxVelocity; ++ticks) {
        tick(train);
        expect(train.physics.currentVelocity <= maxVelocity, true);
        expect(train.physics.currentVelocity, accelerationRate * ticks);
      }

      // The train should be at maximum velocity
      tick(train);
      expect(train.physics.currentVelocity, maxVelocity);

      // Tell the train to stop
      train.stop();
      final ticksUntilStop =
          (train.physics.currentVelocity / decelerationRate).ceil();
      for (int ticks = 1; ticks < ticksUntilStop; ++ticks) {
        tick(train);
        expect(train.physics.currentVelocity > 0, true);
        expect(train.physics.currentVelocity,
            maxVelocity - ticks * decelerationRate);
      }

      // The train should reach a stop
      tick(train);
      expect(train.isStopped, true);
    });

    test(
        'accelerates to max velocity, slows to a stop, and then changes direction',
        () {
      final accelerationRate = train.physics.accelerationRate;
      final decelerationRate = train.physics.decelerationRate;
      final maxVelocity = train.physics.maxSpeed;

      // Train starts stopped
      expectTrainStopped(train);

      // Accelerate the train
      final ticksUntilMaxVelocity = (maxVelocity / accelerationRate).ceil();
      for (int ticks = 1; ticks < ticksUntilMaxVelocity; ++ticks) {
        tick(train);
        expect(train.physics.currentVelocity <= maxVelocity, true);
        expect(train.physics.currentVelocity, accelerationRate * ticks);
      }

      // The train should be at maximum velocity
      tick(train);
      expect(train.physics.currentVelocity, maxVelocity);

      // Tell the train to stop
      train.accelerate(direction: train.physics.direction.inverted);
      final ticksUntilStop =
          (train.physics.currentVelocity / decelerationRate).ceil();
      for (int ticks = 1; ticks < ticksUntilStop; ++ticks) {
        tick(train);
        expect(train.physics.currentVelocity > 0, true);
        expect(train.physics.currentVelocity,
            maxVelocity - ticks * decelerationRate);
      }

      debugger();
      // The train should reach a stop
      tick(train);
      expect(train.isStopped, true);

      // The train should reverse direction after stopping
      for (int ticks = 1; ticks < ticksUntilMaxVelocity; ++ticks) {
        tick(train);
        expect(train.physics.currentVelocity >= -maxVelocity, true);
        expect(train.physics.currentVelocity, -accelerationRate * ticks);
      }

      // The train should be at maximum negative velocity
      tick(train);
      expect(train.physics.currentVelocity, -maxVelocity);
    });
  });
}
