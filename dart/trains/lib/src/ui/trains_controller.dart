// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:trains/src/trains/train_conductor.dart';

import '../trains/track.dart';
import '../../tracks.dart';
import '../trains/train.dart';

class TrainsController {
  late final track = Track.fromGraph(
    verticies: buildCS452Track(),
  );

  late final path = track.findPath(
    start: track.verticies.first,
    finish: track.verticies.last,
  );

  late final conductors = <TrainConductor>[
    TrainConductor(
      name: 'First',
      track: track,
      startDirection: TrainDirection.forward,
      startPosition: track.verticies.first,
    )
      ..createEventsFromPath(
        initialDirection: TrainDirection.forward,
        path: path,
      )
      ..execute(),
  ];
}
