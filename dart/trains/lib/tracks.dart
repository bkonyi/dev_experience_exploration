// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:trains/src/trains/track.dart';

List<TrackNode> buildSimpleTrack() {
  // A---B
  // | \ |
  // |  \|
  // D---C
  final a = TrackNode(name: 'A');
  final b = TrackNode(name: 'B');
  final c = TrackNode(name: 'C');
  final d = TrackNode(name: 'D');

  a.addEdgesTo(straight: (b, 100), curve: (c, 50));
  b.addEdgeTo(straight: (c, 50));
  c.addEdgeTo(straight: (d, 50));
  d.addEdgeTo(straight: (a, 50));

  return [a, b, c, d];
}

List<TrackNode> buildStraightLine() {
  // A ---- B ---- C ---- D
  final a = TrackNode(name: 'A');
  final b = TrackNode(name: 'B');
  final c = TrackNode(name: 'C');
  final d = TrackNode(name: 'D');
  a.addEdgeTo(straight: (b, 50));
  b.addEdgeTo(straight: (c, 50));
  c.addEdgeTo(straight: (d, 50));

  return [a, b, c, d];
}

List<TrackNode> buildCS452Track() {
  // The track from the CS452 lab at UWaterloo.
  // See https://github.com/bkonyi/BaDOS/blob/master/include/track/track_maps.h
  final a = TrackNode(name: 'A');
  final b = TrackNode(name: 'B');
  final c = TrackNode(name: 'C');
  final d = TrackNode(name: 'D');
  final e = TrackNode(name: 'E');
  final f = TrackNode(name: 'F');
  final g = TrackNode(name: 'G');
  final h = TrackNode(name: 'H');
  final i = TrackNode(name: 'I');
  final j = TrackNode(name: 'J');
  final k = TrackNode(name: 'K');
  final l = TrackNode(name: 'L');
  final m = TrackNode(name: 'M');
  final n = TrackNode(name: 'N');
  final o = TrackNode(name: 'O');
  final p = TrackNode(name: 'P');
  final q = TrackNode(name: 'Q');
  final r = TrackNode(name: 'R');
  final s = TrackNode(name: 'S');
  final t = TrackNode(name: 'T');
  final u = TrackNode(name: 'U');
  final v = TrackNode(name: 'V');
  final w = TrackNode(name: 'W');
  final x = TrackNode(name: 'X');
  final y = TrackNode(name: 'Y');
  final z = TrackNode(name: 'Z');
  final aa = TrackNode(name: 'AA');
  final ab = TrackNode(name: 'AB');
  final ac = TrackNode(name: 'AC');
  final ad = TrackNode(name: 'AD');
  final ae = TrackNode(name: 'AE');

  const int outerCircleEdgeLength = 20;
  const int innerCircleEdgeLength = 15;

  h.addEdgesTo(straight: (a, 10), curve: (i, 2));
  i.addEdgesTo(straight: (b, 10), curve: (c, 10));
  o.addEdgesTo(straight: (h, 5), curve: (j, outerCircleEdgeLength));
  v.addEdgeTo(straight: (o, 30));
  aa.addEdgesTo(
    straight: (v, outerCircleEdgeLength),
    curve: (w, innerCircleEdgeLength),
  );
  ab.addEdgeTo(straight: (aa, innerCircleEdgeLength));
  ac.addEdgesTo(straight: (ab, outerCircleEdgeLength), curve: (ad, 15));
  y.addEdgeTo(straight: (ac, 5));
  t.addEdgesTo(straight: (y, 10), curve: (u, 5));
  k.addEdgesTo(
    straight: (t, outerCircleEdgeLength),
    curve: (s, innerCircleEdgeLength),
  );
  j.addEdgeTo(straight: (k, innerCircleEdgeLength));
  p.addEdgeTo(straight: (j, innerCircleEdgeLength));
  w.addEdgesTo(
    straight: (p, innerCircleEdgeLength),
    curve: (q, innerCircleEdgeLength),
  );
  x.addEdgeTo(straight: (ab, innerCircleEdgeLength));
  s.addEdgesTo(
    straight: (x, innerCircleEdgeLength),
    curve: (r, innerCircleEdgeLength),
  );
  r.addEdgeTo(straight: (q, 2));
  q.addEdgeTo(straight: (p, innerCircleEdgeLength));
  u.addEdgesTo(straight: (z, 15), curve: (n, 10));
  z.addEdgesTo(straight: (ae, 15), curve: (y, 5));
  n.addEdgesTo(straight: (g, 10), curve: (m, 2));
  m.addEdgesTo(straight: (f, 10), curve: (l, 2));
  l.addEdgesTo(straight: (e, 10), curve: (d, 10));

  return [
    a,
    b,
    c,
    d,
    e,
    f,
    g,
    h,
    i,
    j,
    k,
    l,
    m,
    n,
    o,
    p,
    q,
    r,
    s,
    t,
    u,
    v,
    w,
    x,
    y,
    z,
    aa,
    ab,
    ac,
    ad,
    ae,
  ];
}
