// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:trains/src/trains/track.dart';
import 'package:trains/src/trains/train_conductor.dart';

import 'dispatch_events.dart';

class CentralDispatch {
  CentralDispatch({required this.track});

  Future<Dispatcher> spawnTrain({
    required String name,
  }) async {
    if (_dispatchers.value.containsKey(name)) {
      throw StateError("Already created a train with name '$name'");
    }
    final dispatcher = await Dispatcher.create(name, track);
    _dispatchers.value[name] = dispatcher;
    // TODO
    _dispatchers.notifyListeners();
    return dispatcher;
  }

  final Track track;
  ValueListenable<Map<String, Dispatcher>> get dispatchers => _dispatchers;
  final _dispatchers = ValueNotifier<Map<String, Dispatcher>>({});
}

class Dispatcher {
  static Future<Dispatcher> create(String name, Track track) async {
    final port = ReceivePort('Dispatcher for $name');
    final isolate = await Isolate.spawn<TrainConductorInitializationRequest>(
      trainConductorEntry,
      TrainConductorInitializationRequest(
        name: name,
        sendPort: port.sendPort,
        track: track,
      ),
      debugName: 'Train thread: $name',
    );

    final dispatcher = Dispatcher._(
      track: track,
      name: name,
      isolate: isolate,
      receivePort: port,
    );
    await dispatcher._initialization.future;
    return dispatcher;
  }

  Dispatcher._({
    required this.track,
    required this.name,
    required this.isolate,
    required this.receivePort,
  }) {
    receivePort.listen((message) {
      final _ = switch (message) {
        SendPort() => _initialize(message),
        TrainPositionEvent() => _trainPosition.value = message,
        TrainNavigationCompleteEvent() => _handleNavigationComplete(),
        Object() || null => throw StateError('Unrecognized message: $message'),
      };
    });
  }

  bool get initialized => _initialized;
  bool _initialized = false;

  final _initialization = Completer<void>();

  ValueListenable<TrainPositionEvent?> get trainPosition => _trainPosition;
  final _trainPosition = ValueNotifier<TrainPositionEvent?>(null);

  ValueListenable<TrackNode?> get currentDestination => _currentDestination;
  final _currentDestination = ValueNotifier<TrackNode?>(null);

  final Track track;
  final String name;
  final Isolate isolate;
  final ReceivePort receivePort;
  late final SendPort sendPort;

  void navigateTo(TrackNode destination) {
    _currentDestination.value = destination;
    sendPort.send(TrainNavigateToRequest(destination: destination));
  }

  void _initialize(SendPort port) {
    sendPort = port;
    _initialized = true;
    _initialization.complete();
  }

  void _handleNavigationComplete() {
    _currentDestination.value = null;
    // TODO: remove
    Future.delayed(const Duration(seconds: 3))
        .then((_) => navigateTo(track.randomNode));
  }
}
