// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:trains/src/trains/track.dart';
import 'package:trains/src/trains/train.dart';
import 'package:trains/src/trains/train_conductor.dart';

import 'dispatch_events.dart';

class CentralDispatch {
  CentralDispatch({required this.track}) {
    for (final edge in track.edges) {
      reservations[edge] = ReservationDetails(edge: edge);
    }
  }

  Future<Dispatcher> spawnTrain({
    required String name,
    TrackNode? startPosition,
    TrainDirection startDirection = TrainDirection.forward,
  }) async {
    if (_dispatchers.value.containsKey(name)) {
      throw StateError("Already created a train with name '$name'");
    }
    final dispatcher = await Dispatcher.create(
      this,
      name,
      track,
      startPosition: startPosition,
      startDirection: startDirection,
    );
    _dispatchers.value[name] = dispatcher;
    // TODO
    _dispatchers.notifyListeners();
    return dispatcher;
  }

  void stopTheWorld() {
    for (final dispatcher in dispatchers.value.values) {
      dispatcher.pause();
    }
    debugger();
    for (final dispatcher in dispatchers.value.values) {
      dispatcher.resume();
    }
  }

  final Track track;
  final reservations = <TrackEdge, ReservationDetails>{};

  ValueListenable<Map<String, Dispatcher>> get dispatchers => _dispatchers;
  final _dispatchers = ValueNotifier<Map<String, Dispatcher>>({});
}

class ReservationDetails {
  ReservationDetails({required this.edge});

  final TrackEdge edge;
  ValueListenable<Dispatcher?> get reservedBy => _reservedBy;
  final _reservedBy = ValueNotifier<Dispatcher?>(null);
  final queue = <({Dispatcher dispatcher, Completer<void> completer})>[];

  Future<void> makeReservation(Dispatcher dispatcher) async {
    // TODO(bkonyi): reserve reverse edge
    if (_reservedBy.value != null) {
      final completer = Completer<void>();
      queue.add((dispatcher: dispatcher, completer: completer));
      await completer.future;
    }
    dispatcher._reservations.value.add(edge);
    // TODO
    dispatcher._reservations.notifyListeners();
    _reservedBy.value = dispatcher;
  }

  void releaseReservation(Dispatcher dispatcher) async {
    if (_reservedBy.value != dispatcher) {
      final error =
          "[${dispatcher.name}] attempted to release reservation it doesn't own!";
      print(error);
      throw StateError(error);
    }
    final released = dispatcher._reservations.value.removeAt(0);
    dispatcher._reservations.notifyListeners();
    if (released != edge) {
      final error =
          'Released edge ($released) does not match reservation ($edge)!';
      print(error);
      throw StateError(error);
    }
    if (queue.isEmpty) {
      _reservedBy.value = null;
    } else {
      final (:completer, dispatcher: _) = queue.removeAt(0);
      completer.complete();
    }
  }
}

class Dispatcher {
  static Future<Dispatcher> create(
    CentralDispatch centralDispatch,
    String name,
    Track track, {
    TrackNode? startPosition,
    TrainDirection startDirection = TrainDirection.forward,
  }) async {
    final port = ReceivePort('Dispatcher for $name');
    final isolate = await Isolate.spawn<TrainConductorInitializationRequest>(
      trainConductorEntry,
      TrainConductorInitializationRequest(
        name: name,
        sendPort: port.sendPort,
        track: track,
        startPosition: startPosition,
        startDirection: startDirection,
      ),
      debugName: 'Train thread: $name',
    );

    final dispatcher = Dispatcher._(
      centralDispatch: centralDispatch,
      track: track,
      name: name,
      isolate: isolate,
      receivePort: port,
    );
    await dispatcher._initialization.future;
    return dispatcher;
  }

  Dispatcher._({
    required this.centralDispatch,
    required this.track,
    required this.name,
    required this.isolate,
    required this.receivePort,
  }) {
    receivePort.listen((message) {
      return switch (message) {
        SendPort() => _initialize(message),
        TrainPositionEvent() => _trainPosition.value = message,
        TrainNavigationCompleteEvent() => _handleNavigationComplete(),
        TrackReservationRequest(:TrackEdge edge) => _makeReservation(edge),
        TrackReservationRelease(:TrackEdge edge) => _releaseReservation(edge),
        ExceptionEvent() => centralDispatch.stopTheWorld(),
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

  ValueListenable<List<TrackEdge>> get reservations => _reservations;
  final _reservations = ValueNotifier<List<TrackEdge>>([]);

  final CentralDispatch centralDispatch;
  final Track track;
  final String name;
  final Isolate isolate;
  final ReceivePort receivePort;
  late final SendPort sendPort;
  late final dispatchLogger = Logger('Dispatch $name');

  final _resumeCapability = Capability();

  void pause() {
    isolate.pause(_resumeCapability);
  }

  void resume() {
    isolate.resume(_resumeCapability);
  }

  void navigateTo(TrackNode destination) {
    _currentDestination.value = destination;
    sendPort.send(TrainNavigateToRequest(destination: destination));
  }

  void _initialize(SendPort port) {
    if (_initialized) {
      throw StateError('Already initialized dispatcher $name!');
    }
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

  Future<void> _makeReservation(TrackEdge edge) async {
    final reservations = centralDispatch.reservations[edge]!;
    await reservations.makeReservation(this);
    sendPort.send(TrackReservationConfirmation(edge: edge));
  }

  void _releaseReservation(TrackEdge edge) {
    if (!centralDispatch.reservations.containsKey(edge)) {
      throw StateError(
        "Attempted to release reservation for edge that doesn't exist: $edge",
      );
    }
    final reservations = centralDispatch.reservations[edge]!;
    reservations.releaseReservation(this);
  }
}
