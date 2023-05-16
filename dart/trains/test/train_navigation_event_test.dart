// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:trains/src/trains/track.dart';
import 'package:trains/src/trains/train.dart';
import 'package:trains/src/trains/train_conductor.dart';

import 'package:trains/tracks.dart';

double getDistance(List<TrackNode> path) {
  TrackEdge getEdge(TrackNode origin, TrackNode destination) {
    if (origin.straight?.destination == destination) {
      return origin.straight!;
    }
    if (origin.curve?.destination == destination) {
      return origin.curve!;
    }
    if (origin.reverseStraight?.destination == destination) {
      return origin.reverseStraight!;
    }
    if (origin.reverseCurve?.destination == destination) {
      return origin.reverseCurve!;
    }
    throw StateError('Could not find edge between $origin and $destination');
  }

  double distance = 0;
  for (int i = 0; i < path.length - 1; ++i) {
    distance += getEdge(path[i], path[i + 1]).length;
  }
  return distance;
}

void main() {
  group('Train navigation events', () {
    test('are in correct sequence', () async {
      final track = Track.fromGraph(verticies: buildCS452Track());
      final start = track.verticies.first; // A
      final finish = track.verticies.last; // AE
      final shortestPath = track.findPath(
        start: start,
        finish: finish,
      );
      expect(
        shortestPath.map((e) => e.name),
        ['A', 'H', 'O', 'J', 'K', 'T', 'Y', 'Z', 'AE'],
      );

      final navigator = TrainConductor(
        name: 'Test',
        track: track,
        startDirection: TrainDirection.forward,
        startPosition: track.verticies.first,
      );
      final train = navigator.train;

      final events = navigator.createEventsFromPath(
        initialDirection: TrainDirection.forward,
        path: shortestPath,
      );

      final nodeA = track.nameToNode['A']!;
      final nodeH = track.nameToNode['H']!;
      final nodeJ = track.nameToNode['J']!;
      final nodeK = track.nameToNode['K']!;
      final nodeT = track.nameToNode['T']!;
      final nodeO = track.nameToNode['O']!;
      final nodeY = track.nameToNode['Y']!;
      final nodeZ = track.nameToNode['Z']!;
      final nodeAE = track.nameToNode['AE']!;

      expect(events, [
        TrainDirectionEvent(train: train, direction: TrainDirection.backward),
        TrainStartEvent(train: train),
        SwitchDirectionEvent(
          train: train,
          node: nodeA,
          direction: BranchDirection.straight,
        ),
        SwitchDirectionEvent(
          train: train,
          node: nodeH,
          direction: BranchDirection.straight,
        ),
        TrainStopEvent(
          train: train,
          origin: nodeA,
          destination: nodeO,
          distance: getDistance(shortestPath.sublist(0, 3)),
        ),
        TrainDirectionEvent(train: train, direction: TrainDirection.forward),
        SwitchDirectionEvent(
          train: train,
          node: nodeO,
          direction: BranchDirection.curve,
        ),
        TrainStartEvent(train: train),
        SwitchDirectionEvent(
          train: train,
          node: nodeJ,
          direction: BranchDirection.straight,
        ),
        SwitchDirectionEvent(
          train: train,
          node: nodeK,
          direction: BranchDirection.straight,
        ),
        SwitchDirectionEvent(
          train: train,
          node: nodeT,
          direction: BranchDirection.straight,
        ),
        TrainStopEvent(
          train: train,
          origin: nodeO,
          destination: nodeY,
          distance: getDistance(shortestPath.sublist(2, 7)),
        ),
        TrainDirectionEvent(train: train, direction: TrainDirection.backward),
        SwitchDirectionEvent(
          train: train,
          node: nodeY,
          direction: BranchDirection.curve,
        ),
        TrainStartEvent(train: train),
        TrainStopEvent(
          train: train,
          origin: nodeY,
          destination: nodeZ,
          distance: getDistance(shortestPath.sublist(7, 9)),
        ),
        TrainDirectionEvent(train: train, direction: TrainDirection.forward),
        SwitchDirectionEvent(
          train: train,
          node: nodeZ,
          direction: BranchDirection.straight,
        ),
        TrainStartEvent(train: train),
        TrainStopEvent(
          train: train,
          origin: nodeZ,
          destination: nodeAE,
          distance: getDistance(shortestPath.sublist(8)),
        ),
      ]);

      await navigator.execute();
      expect(train.position.node, track.verticies.last);
    }, timeout: Timeout.none);

    test('triggers stop at destination after max acceleration', () async {
      // TODO: can this test be written to execute the same behavior without
      // explicitly using a timer?
      final track = Track.fromGraph(verticies: buildStraightLine());
      final conductor = TrainConductor(
        name: 'Test',
        track: track,
        startDirection: TrainDirection.forward,
        startPosition: track.verticies.first,
      );

      final start = track.verticies.first; // A
      final finish = track.verticies[2]; // C
      final path = track.findPath(start: start, finish: finish);
      expect(path.length, 3);

      final events = conductor.createEventsFromPath(
        initialDirection: TrainDirection.forward,
        path: path,
      );
      expect(events.length, 4);
      await conductor.execute();
      expect(conductor.train.position.currentEdge, finish.straight);
      expect(conductor.train.position.offset, 0.0);
    });
  });
}
