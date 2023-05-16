// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:collection/collection.dart';

typedef _PQTrackNode = ({TrackNode node, int weight});

class Track {
  Track.fromGraph({required this.verticies})
      : _nameToNode = {
          for (final vertex in verticies) vertex.name: vertex,
        };

  factory Track.empty() => Track.fromGraph(verticies: []);

  /// The set of verticies that make up the [Track].
  final List<TrackNode> verticies;

  late final Set<TrackEdge> edges = {
    for (final node in verticies) ...{
      if (node.straight != null) node.straight!,
      if (node.curve != null) node.curve!,
      if (node.reverseStraight != null) node.reverseStraight!,
      if (node.reverseCurve != null) node.reverseCurve!,
    }
  };

  UnmodifiableMapView<String, TrackNode> get nameToNode =>
      UnmodifiableMapView(_nameToNode);
  final Map<String, TrackNode> _nameToNode;

  /// Finds the shortest path between [start] and [finish] using Dijkstra's
  /// algorithm.
  ///
  /// If [allowBackwardMovement] is true, paths that require a train to reverse
  /// will be considered.
  List<TrackNode> findPath({
    required TrackNode start,
    required TrackNode finish,
    bool allowBackwardMovement = true,
  }) {
    final path = <TrackNode>[];

    final priorityQueue = PriorityQueue<_PQTrackNode>(
      // b.compareTo(a) will cause this queue to behave like a min heap.
      (a, b) => b.weight.compareTo(a.weight),
    );

    final distances = <TrackNode, int>{};
    final predecessors = <TrackNode, TrackNode>{};

    // Distance to the start node is always 0.
    distances[start] = 0;

    // Initialize distances to infinity.
    const intMax = 0x7fffffffffffffff;
    for (final vertex in verticies) {
      if (vertex != start) {
        distances[vertex] = intMax;
      }
    }

    // Add the start node to the queue with weight 0. Additional nodes will be
    // initialized and added to the queue as we reach them.
    priorityQueue.add((node: start, weight: 0));

    while (priorityQueue.isNotEmpty) {
      final (node: current, weight: _) = priorityQueue.removeFirst();
      final straight = current.straight;
      final curve = current.curve;
      final reverseStraight = current.reverseStraight;
      final reverseCurve = current.reverseCurve;

      final neighbours = <TrackEdge>[
        if (straight != null) straight,
        if (curve != null) curve,
        if (allowBackwardMovement) ...[
          if (reverseStraight != null) reverseStraight,
          if (reverseCurve != null) reverseCurve,
        ],
      ];

      for (final neighbour in neighbours) {
        final distance = distances[current]! + neighbour.length;
        if (distance < distances[neighbour.destination]!) {
          distances[neighbour.destination] = distance;
          predecessors[neighbour.destination] = current;
          priorityQueue.add((node: neighbour.destination, weight: distance));
        }
      }
    }

    TrackNode currentNode = finish;
    // Find the path from finish to start.
    while (true) {
      path.add(currentNode);
      if (currentNode == start) {
        break;
      }
      currentNode = predecessors[currentNode]!;
    }

    // Path is finish -> start, so reverse it before returning.
    return path.reversed.toList();
  }

  void dumpGraphDetails() {
    for (final vertex in verticies) {
      print(vertex.toDetailedString());
    }
  }
}

enum BranchDirection { straight, curve }

class TrackNode {
  TrackNode({
    required this.name,
  });

  BranchDirection switchState = BranchDirection.straight;

  final String name;

  int get edgeCount => _forwardEdges.length + _backwardEdges.length;

  TrackEdge? get straight {
    if (_forwardEdges.isEmpty) {
      return null;
    }
    return _forwardEdges[BranchDirection.straight.index];
  }

  TrackEdge? get curve {
    if (_forwardEdges.length < 2) {
      return null;
    }
    return _forwardEdges[BranchDirection.curve.index];
  }

  TrackEdge? get reverseStraight {
    if (_backwardEdges.isEmpty) {
      return null;
    }
    return _backwardEdges[BranchDirection.straight.index];
  }

  TrackEdge? get reverseCurve {
    if (_backwardEdges.length < 2) {
      return null;
    }
    return _backwardEdges[BranchDirection.curve.index];
  }

  final _forwardEdges = <TrackEdge>[];
  final _backwardEdges = <TrackEdge>[];

  bool _edgesAdded = false;

  void addEdgeTo({
    required (TrackNode, int) straight,
  }) {
    if (_edgesAdded) {
      throw StateError('Edges already initialized!');
    }
    _addEdgeToImpl(straight);
    _edgesAdded = true;
  }

  void addEdgesTo({
    required (TrackNode, int) straight,
    required (TrackNode, int) curve,
  }) {
    if (_edgesAdded) {
      throw StateError('Edges already initialized!');
    }
    _addEdgeToImpl(straight);
    _addEdgeToImpl(curve);
    _edgesAdded = true;
  }

  void _addEdgeToImpl((TrackNode, int) other) {
    TrackNode otherNode;
    int length;
    (otherNode, length) = other;
    final toEdge = TrackEdge(
      length: length,
      source: this,
      destination: otherNode,
    );
    final fromEdge = TrackEdge(
      length: length,
      source: otherNode,
      destination: this,
    );
    toEdge.reverse = fromEdge;
    fromEdge.reverse = toEdge;
    _forwardEdges.add(toEdge);

    otherNode._backwardEdges.add(fromEdge);

    if (otherNode._backwardEdges.length > 2) {
      throw StateError('Target node has more than two backwards edges!');
    }
  }

  @override
  String toString() => name;

  /// Lists the details of the current node, including:
  ///   - The node name
  ///   - The list of outgoing edges
  ///   - The list of incoming edges
  String toDetailedString() {
    final buffer = StringBuffer();
    buffer.write('[$name] forward: [');
    if (_forwardEdges.isEmpty) {
      buffer.write('<none>');
    } else {
      buffer.write('(straight, ${straight!.destination}, ${straight!.length})');
      if (curve != null) {
        buffer.write(', (curve, ${curve!.destination}, ${curve!.length})');
      }
    }
    buffer.write('] backward: [');
    if (_backwardEdges.isEmpty) {
      buffer.write('<none>');
    } else {
      buffer.write(
          '(straight, ${reverseStraight!.destination}, ${reverseStraight!.length})');
      if (reverseCurve != null) {
        buffer.write(
            ', (curve, ${reverseCurve!.destination}, ${reverseCurve!.length})');
      }
    }
    buffer.write(']');
    return buffer.toString();
  }
}

class TrackEdge {
  TrackEdge({
    required this.length,
    required this.source,
    required this.destination,
  });
  final TrackNode source;
  final TrackNode destination;
  late final TrackEdge reverse;
  final int length;

  @override
  String toString() => '[${source.name}->${destination.name}]';
}
