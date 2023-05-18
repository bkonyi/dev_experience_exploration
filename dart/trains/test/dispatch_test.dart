// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:trains/src/trains/dispatcher.dart';
import 'package:trains/src/trains/track.dart';
import 'package:trains/tracks.dart';

void main() {
  test('initializes correctly', () async {
    final central = CentralDispatch(
        track: Track.fromGraph(
      verticies: buildCS452Track(),
    ));

    expect(central.dispatchers.value.isEmpty, true);

    await central.spawnTrain(name: 'Test train');
    expect(central.dispatchers.value.isNotEmpty, true);
    expect(central.dispatchers.value.values.first.initialized, true);
  });
}
