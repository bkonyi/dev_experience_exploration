// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'board_controller.dart';
import 'slider.dart';

class GameOfLife extends StatefulWidget {
  const GameOfLife({super.key});

  @override
  State<GameOfLife> createState() => _GameOfLifeState();
}

class _GameOfLifeState extends State<GameOfLife> {
  final controller = GameOfLifeController();

  @override
  void initState() {
    super.initState();
    controller.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Controls(
          controller: controller,
        ),
        Expanded(
          child: Center(
            child: ValueListenableBuilder<void>(
              valueListenable: controller.gridReset,
              builder: (context, _, __) {
                return Board(
                  controller: controller,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// The set of controls used to configure and control the game.
class Controls extends StatelessWidget {
  const Controls({super.key, required this.controller});

  final GameOfLifeController controller;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ValueListenableBuilder<bool>(
        valueListenable: controller.isRunningSimulation,
        builder: (context, isRunningSimulation, _) {
          return ListView(
            children: [
              NamedSlider(
                name: 'Grid Size',
                enabled: !isRunningSimulation,
                initialValue: GameOfLifeController.kInitialGridSize,
                range: (start: 25, end: 500),
                onChangedEnd: controller.setGridSize,
              ),
              // TODO: add multi-threading support
              /*NamedSlider(
                  name: 'Isolates',
                  enabled: !isRunningSimulation,
                  initialValue: 1,
                  range: (start: 1, end: 16),
                  onChangedEnd: controller.setIsolateCount,
                ),*/
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: OutlinedButton(
                  onPressed: controller.pauseOrResume,
                  child: Text(
                    isRunningSimulation ? 'Pause' : 'Resume',
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: OutlinedButton(
                  onPressed: !isRunningSimulation ? controller.reset : null,
                  child: const Text('Reset'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: OutlinedButton(
                  onPressed: !isRunningSimulation ? controller.step : null,
                  child: const Text('Step'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The playing area that the game is rendered on.
/// 
/// This widget consists of a zoomable and pannable NxN grid of [CellWidget]s
class Board extends StatelessWidget {
  const Board({super.key, required this.controller});

  final GameOfLifeController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final world = controller.world;
        final cellSize = (min(constraints.maxHeight, constraints.maxWidth) /
            max(world.size.x, world.size.y));
        return InteractiveViewer(
          maxScale: 10,
          child: Container(
            color: Colors.black,
            child: Row(
              children: [
                const Spacer(),
                Center(
                  child: Container(
                    // If we don't explicitly set the background color to white,
                    // black lines leak through gaps between the [CellWidget]s
                    // resulting in significantly worse raster performance.
                    //
                    // TODO: figure out why there's gaps in the first place.
                    color: Colors.white,
                    child: Column(
                      children: [
                        for (int i = 0; i < world.size.y; ++i)
                          Row(
                            children: [
                              for (int j = 0; j < world.size.x; ++j)
                                CellWidget(
                                  coordinates: (x: j, y: i),
                                  controller: controller,
                                  cellSize: cellSize,
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter for rendering a [CellWidget].
class CellPainter extends CustomPainter {
  CellPainter({
    required this.cellIsAlive,
  }) {
    paintSetting.strokeWidth = 1;
  }

  bool cellIsAlive = false;
  final paintSetting = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    paintSetting.color = cellIsAlive ? Colors.green : Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paintSetting,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    var cellPainter = (oldDelegate as CellPainter);
    return cellPainter.cellIsAlive != cellIsAlive;
  }
}

/// Renders an individual cell which can be alive or dead.
/// 
/// When the simulation is paused, users can toggle the state of individual
/// cells by tapping the cell.
class CellWidget extends StatelessWidget {
  CellWidget({
    super.key,
    required this.coordinates,
    required this.controller,
    required this.cellSize,
  }) : isLive = controller.getCellState(coordinates: coordinates);

  final GameOfLifeController controller;
  final ({int x, int y}) coordinates;
  final ValueListenable<bool> isLive;
  final double cellSize;

  @override
  Widget build(BuildContext context) {
    final cell = ValueListenableBuilder<bool>(
      valueListenable: isLive,
      builder: (context, isLive, _) {
        return CustomPaint(
          size: Size(cellSize, cellSize),
          painter: CellPainter(
            cellIsAlive: isLive,
          ),
        );
      },
    );
    return ValueListenableBuilder<bool>(
      valueListenable: controller.isRunningSimulation,
      child: cell,
      builder: (context, isRunningSimulation, child) {
        if (!isRunningSimulation) {
          return GestureDetector(
            child: child!,
            onTap: () {
              controller.toggleCellState(coordinates: coordinates);
            },
          );
        }
        return child!;
      },
    );
  }
}
