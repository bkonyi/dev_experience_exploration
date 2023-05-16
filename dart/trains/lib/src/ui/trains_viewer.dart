// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:trains/src/ui/trains_controller.dart';

import '../trains/track.dart';
import '../trains/train.dart';

class TrainsAndTrackViewer extends StatefulWidget {
  const TrainsAndTrackViewer({super.key});

  @override
  State<TrainsAndTrackViewer> createState() => _TrainsAndTrackViewerState();
}

class _TrainsAndTrackViewerState extends State<TrainsAndTrackViewer> {
  final controller = TrainsController();

  @override
  Widget build(BuildContext context) {
    controller.conductors;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Trains!'),
      ),
      body: Row(
        children: [
          Flexible(
            child: EdgesTable(
              controller: controller,
            ),
          ),
          const VerticalDivider(
            width: 2,
            thickness: 2,
          ),
          Flexible(
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
                //fixedWidth: 100,
              ),
              DataColumn2(
                label: Text('Length'),
                //fixedWidth: 80,
                numeric: true,
              ),
            ],
            rows: [
              for (final edge in controller.track.edges)
                DataRow(
                  cells: [
                    DataCell(TrackEdgeName(edge: edge)),
                    DataCell(TrackEdgeLength(edge: edge)),
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
          child: DataTable2(
            columns: const [
              DataColumn2(
                label: Text('Name'),
                //fixedWidth: 100,
              ),
              DataColumn2(
                label: Text('Current'),
                //fixedWidth: 80,
              ),
              DataColumn2(
                label: Text('Offset'),
                //fixedWidth: 80,
              ),
              DataColumn2(
                label: Text('Destination'),
              ),
              DataColumn2(
                label: Text('Reservations'),
              ),
            ],
            rows: [
              for (final conductor in controller.conductors)
                DataRow(
                  cells: [
                    DataCell(Text(
                      conductor.train.name,
                    )),
                    DataCell(
                      TrainUpdaterWidget(
                        train: conductor.train,
                        builder: (context, train) {
                          return Text(train.position.node.name);
                        },
                      ),
                    ),
                    DataCell(
                      TrainUpdaterWidget(
                        train: conductor.train,
                        builder: (context, train) {
                          return Text(
                            train.position.offset.toStringAsFixed(1),
                          );
                        },
                      ),
                    ),
                    DataCell(
                      TrainUpdaterWidget(
                        train: conductor.train,
                        builder: (context, train) {
                          return Text(
                            train.position.currentEdge?.destination.name ??
                                'N/A',
                          );
                        },
                      ),
                    ),
                    DataCell(
                      TrainUpdaterWidget(
                        train: conductor.train,
                        builder: (context, train) {
                          return const Text('N/A');
                        },
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class TrainUpdaterWidget extends StatelessWidget {
  const TrainUpdaterWidget(
      {super.key, required this.train, required this.builder});

  final Train train;
  final Widget Function(BuildContext, Train) builder;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: train.position,
      builder: (context, _) => builder(context, train),
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
