// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:trains/src/train_conductor.dart';

Future<void> main() async {
  final train = TrainConductor(name: 'Test train');
  train.initialize();
  Timer.periodic(const Duration(seconds: 2), (timer) {
    print('');
    train.updatePosition();
    print(train);
  });
}