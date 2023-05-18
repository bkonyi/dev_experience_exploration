// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../trains/dispatch_events.dart';
import '../trains/dispatcher.dart';
import 'trains_controller.dart';

import '../trains/track.dart';

class TrainsAndTrackViewer extends StatefulWidget {
  const TrainsAndTrackViewer({super.key});

  @override
  State<TrainsAndTrackViewer> createState() => _TrainsAndTrackViewerState();
}

class _TrainsAndTrackViewerState extends State<TrainsAndTrackViewer> {
  final controller = TrainsController();

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 3; ++i) {
      controller.centralDispatch
          .spawnTrain(name: 'Test $i')
          .then((dispatcher) async {
        dispatcher.navigateTo(controller.track.verticies.last);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Trains!'),
      ),
      body: Row(
        children: [
          Flexible(
            flex: 2,
            child: EdgesTable(
              controller: controller,
            ),
          ),
          const VerticalDivider(
            width: 2,
            thickness: 2,
          ),
          Flexible(
            flex: 4,
            child: TrainsTable(
              controller: controller,
            ),
          ),
        ],
      ),
    );
  }
}

class EdgesTable extends StatelessWidget {
  const EdgesTable({
    super.key,
    required this.controller,
  });

  final TrainsController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TableHeader('Track'),
        Expanded(
          child: DataTable2(
            columns: const [
              DataColumn2(
                label: Text('Edge'),
              ),
              DataColumn2(
                label: Text('Length'),
                numeric: true,
              ),
              DataColumn2(
                label: Text('Reserved by'),
              ),
            ],
            rows: [
              for (final edge in controller.track.edges)
                DataRow(
                  cells: [
                    DataCell(TrackEdgeName(edge: edge)),
                    DataCell(TrackEdgeLength(edge: edge)),
                    const DataCell(Text('N/A')),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class TableHeader extends StatelessWidget {
  const TableHeader(
    this.title, {
    super.key,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      color: Colors.blue,
      child: Center(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 25,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class TrainsTable extends StatelessWidget {
  const TrainsTable({
    super.key,
    required this.controller,
  });

  final TrainsController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const TableHeader('Trains'),
        Expanded(
          child: ValueListenableBuilder<Map<String, Dispatcher>>(
            valueListenable: controller.centralDispatch.dispatchers,
            builder: (context, dispatchers, _) {
              return DataTable2(
                columns: const [
                  DataColumn2(
                    label: Text('Name'),
                  ),
                  DataColumn2(
                    label: Text('Velocity'),
                  ),
                  DataColumn2(
                    label: Text('Current'),
                  ),
                  DataColumn2(
                    label: Text('Offset'),
                  ),
                  DataColumn2(
                    label: Text('Destination'),
                  ),
                  DataColumn2(
                    label: Text('Reservations'),
                  ),
                ],
                rows: [
                  for (final conductor in dispatchers.values)
                    DataRow(
                      cells: [
                        DataCell(Text(
                          conductor.name,
                        )),
                        DataCell(
                          TrainUpdaterWidget(
                            position: conductor.trainPosition,
                            builder: (context, position) {
                              // Make sure we don't display -0.0.
                              if (position.velocity == 0) {
                                return '0.0';
                              }
                              return position.velocity.toStringAsFixed(1);
                            },
                          ),
                        ),
                        DataCell(
                          TrainUpdaterWidget(
                            position: conductor.trainPosition,
                            builder: (context, position) {
                              final currentEdge = position.position.currentEdge;
                              if (currentEdge != null) {
                                return currentEdge.toString();
                              }
                              return position.position.node.name;
                            },
                          ),
                        ),
                        DataCell(
                          TrainUpdaterWidget(
                            position: conductor.trainPosition,
                            builder: (context, position) {
                              return position.position.offset
                                  .toStringAsFixed(1);
                            },
                          ),
                        ),
                        DataCell(
                          ValueListenableBuilder<TrackNode?>(
                            valueListenable: conductor.currentDestination,
                            builder: (context, currentDestination, _) {
                              return Text(currentDestination?.name ?? 'N/A');
                            },
                          ),
                        ),
                        DataCell(
                          TrainUpdaterWidget(
                            position: conductor.trainPosition,
                            builder: (context, train) {
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class TrainUpdaterWidget extends StatelessWidget {
  const TrainUpdaterWidget(
      {super.key, required this.position, required this.builder});

  final ValueListenable<TrainPositionEvent?> position;
  final String? Function(BuildContext, TrainPositionEvent) builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TrainPositionEvent?>(
      valueListenable: position,
      builder: (context, position, _) {
        // ignore: constant_identifier_names
        const NAText = Text('N/A');
        if (position == null) {
          return NAText;
        }
        final result = builder(context, position);
        if (result == null) {
          return NAText;
        }
        return Text(result);
      },
    );
  }
}

class TrackEdgeName extends StatelessWidget {
  const TrackEdgeName({
    super.key,
    required this.edge,
  });

  final TrackEdge edge;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(edge.source.name),
        const Text(' -> '),
        Text(edge.destination.name),
      ],
    );
  }
}

class TrackEdgeLength extends StatelessWidget {
  const TrackEdgeLength({
    super.key,
    required this.edge,
  });

  final TrackEdge edge;

  @override
  Widget build(BuildContext context) {
    return Text(edge.length.toString());
  }
}
