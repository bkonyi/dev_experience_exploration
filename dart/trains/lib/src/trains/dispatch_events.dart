// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:isolate';

import 'track.dart';
import 'train.dart';

class TrainConductorInitializationRequest {
  const TrainConductorInitializationRequest({
    required this.name,
    required this.track,
    required this.sendPort,
    this.startDirection,
    this.startPosition,
  });

  final String name;
  final Track track;
  final TrainDirection? startDirection;
  final TrackNode? startPosition;
  final SendPort sendPort;
}

class TrainNavigateToRequest {
  const TrainNavigateToRequest({required this.destination});

  final TrackNode destination;
}

class TrainPositionData {
  TrainPositionData.fromTrainPosition(TrainPosition trainPosition)
      : name = trainPosition.train.name,
        offset = trainPosition.offset,
        node = trainPosition.node,
        currentEdge = trainPosition.currentEdge;

  final String name;
  final double offset;
  final TrackNode node;
  final TrackEdge? currentEdge;
}

class ExceptionEvent {
  const ExceptionEvent();
}

class TrainPositionEvent {
  const TrainPositionEvent({
    required this.name,
    required this.direction,
    required this.position,
    required this.velocity,
  });

  final String name;
  final TrainDirection direction;
  final TrainPositionData position;
  final double velocity;
}

class TrainNavigationCompleteEvent {
  const TrainNavigationCompleteEvent();
}

class TrackReservationRequest {
  const TrackReservationRequest({required this.element});

  final TrackElement element;
}

class TrackReservationConfirmation {
  const TrackReservationConfirmation({required this.element});

  final TrackElement element;
}

class TrackReservationRelease {
  const TrackReservationRelease({required this.element});

  final TrackElement element;
}