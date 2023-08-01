// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';

import 'game_state.dart';

class GameOfLifeController {
  static const bool _useIsolateCompute = false;

  static const kInitialGridSize = 150;
  int _gridSize = kInitialGridSize;

  List<List<ValueNotifier<bool>>> _cellState = [];

  World get world => _world;
  World _world = World.empty();

  ValueListenable<bool> get isRunningSimulation => _isRunningSimulation;
  final _isRunningSimulation = ValueNotifier<bool>(false);

  ValueListenable<int> get gridReset => _gridReset;
  final _gridReset = ValueNotifier<int>(0);

  Future<void> initialize() async {
    await _initializeGrid();
  }

  Future<void> _initializeGrid() async {
    final task = TimelineTask();

    task.start('Initializing grid', arguments: {
      'size': _gridSize,
    });
    _cellState = [
      for (int i = 0; i < _gridSize; ++i)
        [for (int j = 0; j < _gridSize; ++j) ValueNotifier<bool>(false)]
    ];

    World buildGrid(int size) {
      final gunWorld = World.fromGrid(
        grid: List.generate(
          size,
          (_) => List.generate(
            size,
            (_) => Cell(
              isLive: false,
            ),
          ),
        ),
      );

      int upperLeftX = 30;
      int upperLeftY = 30;
      const initialCells = [
        (0, 4),
        (0, 5),
        (1, 4),
        (1, 5),
        (10, 4),
        (10, 5),
        (10, 6),
        (11, 3),
        (11, 7),
        (12, 2),
        (12, 8),
        (13, 2),
        (13, 8),
        (14, 5),
        (15, 3),
        (15, 7),
        (16, 4),
        (16, 5),
        (16, 6),
        (17, 5),
        (20, 2),
        (20, 3),
        (20, 4),
        (21, 2),
        (21, 3),
        (21, 4),
        (22, 1),
        (22, 5),
        (24, 0),
        (24, 1),
        (24, 5),
        (24, 6),
        (34, 2),
        (34, 3),
        (35, 2),
        (35, 3),
      ];

      for (final (int x, int y) in initialCells) {
        gunWorld.getCell(coordinates: (
          x: upperLeftX + x,
          y: upperLeftY + y,
        )).setLive();
      }

      return gunWorld;
    }

    _world = _useIsolateCompute
        ? await compute<int, World>(
            buildGrid,
            _gridSize,
          )
        : buildGrid(_gridSize);
    _updateCellStates();
    _gridReset.value++;

    task.finish();
  }

  void scheduleUpdates() {
    Timer(const Duration(milliseconds: 16), () async {
      final task = TimelineTask();
      task.start('Update world');
      await step();
      print('Updated!');
      task.finish();

      if (_isRunningSimulation.value) {
        scheduleUpdates();
      }
    });
  }

  void setGridSize(int size) {
    _gridSize = size;
    reset();
  }

  // TODO: add multi-threading support
  /*
  void setIsolateCount(int count) {
    return;
  }
  */

  void pauseOrResume() {
    _isRunningSimulation.value = !_isRunningSimulation.value;
    if (_isRunningSimulation.value) {
      scheduleUpdates();
    }
  }

  void reset() {
    _initializeGrid();
  }

  Future<void> step() async {
    if (_useIsolateCompute) {
      _world = await compute<World, World>(
        (world) => world.nextTick(),
        _world,
      );
    } else {
      _world = _world.nextTick();
    }
    _updateCellStates();
  }

  ValueListenable<bool> getCellState({
    required ({int x, int y}) coordinates,
  }) {
    return _cellState[coordinates.y][coordinates.x];
  }

  void toggleCellState({
    required ({int x, int y}) coordinates,
  }) {
    final cell = _world.getCell(coordinates: coordinates)..toggle();
    _setCellState(
      coordinates: coordinates,
      isLive: cell.isLive,
    );
  }

  void _updateCellStates() {
    Timeline.timeSync('Updating cell state', () {
      for (int i = 0; i < _world.size.y; ++i) {
        for (int j = 0; j < _world.size.x; ++j) {
          _setCellState(
            coordinates: (x: j, y: i),
            isLive: _world.getCell(coordinates: (x: j, y: i)).isLive,
          );
        }
      }
    });
  }

  void _setCellState(
      {required ({int x, int y}) coordinates, required bool isLive}) {
    final x = coordinates.x;
    final y = coordinates.y;
    if (_cellState[y][x].value != isLive) {
      Timeline.timeSync(
        'Toggling cell state ($x, $y)',
        () => _cellState[y][x].value = isLive,
      );
    }
  }
}
