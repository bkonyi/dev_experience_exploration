// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:trains/src/ui/trains_controller.dart';

import 'src/ui/trains_viewer.dart';

void main() {
  /*FlutterError.onError = (FlutterErrorDetails _) {
    trainsController.centralDispatch.stopTheWorld();
  };*/
  final trainsController = TrainsController();
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      runApp(MyApp(
        controller: trainsController,
      ));
    },
    (error, stack) {
      trainsController.centralDispatch.stopTheWorld();
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.controller,
  });

  final TrainsController controller;

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trains!',
      theme: ThemeData(
        colorScheme: const ColorScheme
            .dark(), //ColorScheme.fromSeed(seedColor: Colors.blue),
        //colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        //useMaterial3: true,
      ),
      home: TrainsAndTrackViewer(
        controller: controller,
      ),
    );
  }
}
