// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:life/src/game_state.dart';

Future<void> main() async {
  World world = World.random(size: (x: 500, y: 500));
  while (true) {
    await Future.delayed(const Duration(seconds: 1));
    final stopwatch = Stopwatch();
    stopwatch.start();
    world = world.nextTick();
    stopwatch.stop();
    print('Update took ${stopwatch.elapsed.inMilliseconds}');
  }
}