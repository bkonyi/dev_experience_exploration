// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';

class NamedSlider extends StatefulWidget {
  const NamedSlider({
    super.key,
    required this.name,
    required this.enabled,
    required this.initialValue,
    required this.range,
    required this.onChangedEnd,
  });

  final bool enabled;
  final int initialValue;
  final ({int start, int end}) range;
  final String name;
  final void Function(int)? onChangedEnd;

  @override
  State<NamedSlider> createState() => _NamedSliderState();
}

class _NamedSliderState extends State<NamedSlider> {
  int value = 0;

  @override
  void initState() {
    super.initState();
    value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Text('${widget.name} ($value)'),
          ),
          Slider(
            min: widget.range.start.toDouble(),
            max: widget.range.end.toDouble(),
            value: value.toDouble(),
            onChanged: widget.enabled
                ? (newValue) => setState(
                      () => value = newValue.round(),
                    )
                : null,
            onChangeEnd: (double value) =>
                widget.onChangedEnd?.call(value.toInt()),
          ),
        ],
      ),
    );
  }
}
