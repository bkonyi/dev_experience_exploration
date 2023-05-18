// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:isolate';

import 'package:test/test.dart';
import 'package:trains/src/trains/track.dart';
import 'package:trains/src/trains/train.dart';
import 'package:trains/src/trains/train_conductor.dart';

import 'package:trains/tracks.dart';

void main() {
  group('Pathfinding', () {
    test('simple graph', () {
      final track = Track.fromGraph(verticies: buildSimpleTrack());
      track.dumpGraphDetails();

      final start = track.verticies.first;
      final finish = track.verticies.last;

      final zeroLengthPath = track.findPath(
        start: start,
        finish: start,
      );
      expect(zeroLengthPath.length, 1);
      expect(zeroLengthPath.first.name, start.name);

      final shortestPath = track.findPath(
        start: start,
        finish: finish,
      );
      expect(shortestPath.map((e) => e.name), ['A', 'D']);

      // No backward movement will only consistently work on cyclical graphs.
      final shortestPathWithNoBackwardMovment = track.findPath(
        start: start,
        finish: finish,
        allowBackwardMovement: false,
      );
      expect(
        shortestPathWithNoBackwardMovment.map((e) => e.name),
        ['A', 'C', 'D'],
      );
    });

    test('CS452 graph', () {
      final track = Track.fromGraph(verticies: buildCS452Track());
      final start = track.verticies.first;
      final finish = track.verticies.last;
      track.dumpGraphDetails();
      final shortestPath = track.findPath(
        start: start,
        finish: finish,
      );
      expect(
        shortestPath.map((e) => e.name),
        ['A', 'H', 'O', 'J', 'K', 'T', 'Y', 'Z', 'AE'],
      );

      final port = ReceivePort();
      final navigator = TrainConductor(
        name: 'Train',
        track: track,
        startDirection: TrainDirection.forward,
        startPosition: start,
        sendPort: port.sendPort,
      );

      final events = navigator.createEventsFromPath(
        initialDirection: TrainDirection.forward,
        path: shortestPath,
      );
      print(events);
    });
  });
}
