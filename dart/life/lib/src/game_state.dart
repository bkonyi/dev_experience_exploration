// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math';

typedef Grid = List<List<Cell>>;

extension on int {
  bool get shouldKillCell => this >= 4 || this <= 1;
  bool get shouldReviveCell => this == 3;
}

class World {
  World.empty()
      : grid = [],
        size = (x: 0, y: 0);

  World.random({required this.size})
      : grid = List<List<Cell>>.generate(
          size.y,
          (_) => List<Cell>.generate(
            size.x,
            (_) => Cell(),
          ),
        );

  World.fromGrid({required Grid grid})
      : grid = [
          for (final row in grid)
            [
              for (final entry in row) Cell(isLive: entry.isLive),
            ],
        ],
        size = (x: grid[0].length, y: grid.length);

  bool get isEmpty => size == (x: 0, y: 0);

  World nextTick() {
    // First, copy the world.
    final nextWorld = World.fromGrid(grid: grid);

    for (int y = 0; y < grid.length; ++y) {
      for (int x = 0; x < grid.length; ++x) {
        final coordinates = (x: x, y: y);
        final currentCell = getCell(coordinates: coordinates);
        final nextCell = nextWorld.getCell(coordinates: coordinates);
        final liveNeighbours = _getLiveNeighbourCount(coordinates);
        if (currentCell.isLive && liveNeighbours.shouldKillCell) {
          nextCell.setDead();
        } else if (!currentCell.isLive && liveNeighbours.shouldReviveCell) {
          nextCell.setLive();
        }
      }
    }

    return nextWorld;
  }

  int _getLiveNeighbourCount(({int x, int y}) coordinates) {
    int liveNeighbours = 0;
    for (int xOffset = -1; xOffset <= 1; ++xOffset) {
      for (int yOffset = -1; yOffset <= 1; ++yOffset) {
        if (xOffset == 0 && yOffset == 0) continue;
        final cell = getCell(
          coordinates: (
            x: coordinates.x + xOffset,
            y: coordinates.y + yOffset,
          ),
        );
        if (cell.isLive) {
          ++liveNeighbours;
        }
      }
    }
    return liveNeighbours;
  }

  Cell getCell({required ({int x, int y}) coordinates}) =>
      grid[coordinates.y % size.y][coordinates.x % size.x];

  @override
  String toString() {
    final buf = StringBuffer();
    for (final row in grid) {
      buf.write('|');
      for (final entry in row) {
        buf.write(entry);
        buf.write('|');
      }
      buf.writeln();
    }
    return buf.toString();
  }

  final Grid grid;
  final ({int x, int y}) size;
}

class Cell {
  Cell({bool? isLive}) : _isLive = isLive ?? Random().nextInt(10) == 0;

  bool get isLive => _isLive;
  bool _isLive;

  void setLive() => _isLive = true;
  void setDead() => _isLive = false;

  void toggle() => _isLive = !_isLive;

  @override
  String toString() => _isLive ? 'X' : ' ';
}
