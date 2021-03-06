// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as dart_ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import 'package:mp_chart/mp/chart/line_chart.dart';
import 'package:mp_chart/mp/controller/line_chart_controller.dart';
import 'package:mp_chart/mp/core/adapter_android_mp.dart';
import 'package:mp_chart/mp/core/data/line_data.dart';
import 'package:mp_chart/mp/core/data_set/line_data_set.dart';
import 'package:mp_chart/mp/core/description.dart';
import 'package:mp_chart/mp/core/entry/entry.dart';
import 'package:mp_chart/mp/core/enums/axis_dependency.dart';
// TODO(terry): Enable legend when textsize is correct.
// import 'package:mp_chart/mp/core/enums/legend_vertical_alignment.dart';
// import 'package:mp_chart/mp/core/enums/legend_form.dart';
// import 'package:mp_chart/mp/core/enums/legend_horizontal_alignment.dart';
// import 'package:mp_chart/mp/core/enums/legend_orientation.dart';
import 'package:mp_chart/mp/core/enums/x_axis_position.dart';
import 'package:mp_chart/mp/core/enums/y_axis_label_position.dart';
import 'package:mp_chart/mp/core/highlight/highlight.dart';
import 'package:mp_chart/mp/core/image_loader.dart';
import 'package:mp_chart/mp/core/marker/line_chart_marker.dart';
import 'package:mp_chart/mp/core/poolable/point.dart';
import 'package:mp_chart/mp/core/utils/color_utils.dart';
import 'package:mp_chart/mp/core/utils/painter_utils.dart';
import 'package:mp_chart/mp/core/value_formatter/default_value_formatter.dart';
import 'package:mp_chart/mp/core/value_formatter/large_value_formatter.dart';
import 'package:mp_chart/mp/core/value_formatter/value_formatter.dart';

import '../../flutter/auto_dispose_mixin.dart';
import '../../flutter/controllers.dart';
import '../../flutter/theme.dart';
import '../../ui/theme.dart';
import 'memory_controller.dart';
import 'memory_protocol.dart';

class MemoryChart extends StatefulWidget {
  @override
  MemoryChartState createState() => MemoryChartState();
}

class MemoryChartState extends State<MemoryChart> with AutoDisposeMixin {
  LineChartController chartController;

  MemoryController controller;

  MemoryTimeline get memoryTimeline => controller.memoryTimeline;

  final legendTypeFace =
      TypeFace(fontFamily: 'OpenSans', fontWeight: FontWeight.w100);

  @override
  void initState() {
    _initController();

    _preloadResources();

    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    controller = Controllers.of(context).memory;

    controller.memoryTimeline.image = _img;

    _setupChart();

    cancel();

    // Update the chart when the memorySource changes.
    addAutoDisposeListener(controller.memorySourceNotifier, () {
      setState(() {
        controller.updatedMemorySource();

        // Plot all offline or online data (based on memorySource).  If
        // not offline then all new heap samples will be plotted as it
        // appears via the sampleAddedNotifier.
        _processAndUpdate(true);
      });
    });

    // Plot each heap sample as it is received.
    addAutoDisposeListener(
      memoryTimeline.sampleAddedNotifier,
      _processAndUpdate,
    );
  }

  dart_ui.Image _img;

  void _preloadResources() async {
    _img ??= await ImageLoader.loadImage('assets/img/star.png');
  }

  @override
  Widget build(BuildContext context) {
    if (memoryTimeline.liveData.isNotEmpty) {
      return Center(
        child: LineChart(chartController),
      );
    }

    return const Center(
      child: Text('No data'),
    );
  }

  void _initController() {
    final desc = Description()..enabled = false;

    chartController = LineChartController(
      axisLeftSettingFunction: (axisLeft, controller) {
        axisLeft
          ..position = YAxisLabelPosition.OUTSIDE_CHART
          ..setValueFormatter(LargeValueFormatter())
          ..drawGridLines = (true)
          ..granularityEnabled = (true)
          ..setStartAtZero(
              true) // Set to baseline min and auto track max axis range.
          ..textColor = defaultForeground;
      },
      axisRightSettingFunction: (axisRight, controller) {
        axisRight.enabled = false;
      },
      xAxisSettingFunction: (xAxis, controller) {
        xAxis
          ..position = XAxisPosition.BOTTOM
          ..textSize = 10
          ..drawAxisLine = false
          ..drawGridLines = true
          ..textColor = defaultForeground
          ..centerAxisLabels = true
          ..setGranularity(1)
          ..setValueFormatter(XAxisFormatter());
      },
      legendSettingFunction: (legend, controller) {
        legend.enabled = false;
        // TODO(terry): Need to support legend with a smaller text size.
        // legend
        //   ..shape = LegendForm.LINE
        //   ..verticalAlignment = LegendVerticalAlignment.TOP
        //   ..enabled = true
        //   ..orientation = LegendOrientation.HORIZONTAL
        //   ..typeface = legendTypeFace
        //   ..xOffset = 20
        //   ..drawInside = false
        //   ..horizontalAlignment = LegendHorizontalAlignment.CENTER
        //   ..textSize = 6.0;
      },
      highLightPerTapEnabled: true,
      backgroundColor: chartBackgroundColor,
      drawGridBackground: false,
      dragXEnabled: true,
      dragYEnabled: true,
      scaleXEnabled: true,
      scaleYEnabled: true,
      pinchZoomEnabled: false,
      description: desc,
      marker: SelectedDataPoint(
          onSelected: onPointSelected, getAllValues: getValues),
    );

    // Compute padding around chart.
    chartController.setViewPortOffsets(50, 10, 10, 30);
  }

  void onPointSelected(int index) {
    controller.selectedSample = index;
  }

  HeapSample getValues(int timestamp) {
    final data = controller.memoryTimeline.data;
    for (var index = 0; index < data.length; index++) {
      if (data[index].timestamp == timestamp) {
        return data[index];
      }
    }

    return null;
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Trace #1 Heap Used.
  LineDataSet usedHeapSet;

  // Trace #2 Heap Capacity.
  LineDataSet capacityHeapSet;

  // Trace #3 External Memory used.
  LineDataSet externalMemorySet;

  /// General utility function handles loading all heap samples (online or offline) and
  /// or the latest
  /// heap sample.
  void _processAndUpdate([bool reloadAllData = false]) {
    setState(() {
      controller.processData(reloadAllData);
      _updateChart();
    });
  }

  /// Display any newly received heap sample(s) in the chart.
  void _updateChart() {
    setState(() {
      // Signal data has changed.
      usedHeapSet.notifyDataSetChanged();
      capacityHeapSet.notifyDataSetChanged();
      externalMemorySet.notifyDataSetChanged();

      chartController.data = LineData.fromList(
          []..add(usedHeapSet)..add(externalMemorySet)..add(capacityHeapSet));
    });
  }

  void _setupChart() {
    final chartData = memoryTimeline.chartData;

    // Create heap used dataset.
    usedHeapSet = LineDataSet(chartData.used, 'Used');
    usedHeapSet
      ..setAxisDependency(AxisDependency.LEFT)
      ..setColor1(ColorUtils.getHoloBlue())
      ..setValueTextColor(ColorUtils.getHoloBlue())
      ..setLineWidth(.7)
      ..setDrawCircles(false)
      ..setDrawValues(false)
      ..setFillAlpha(65)
      ..setFillColor(ColorUtils.getHoloBlue())
      ..setDrawCircleHole(false)
      // Fill in area under set.
      ..setDrawFilled(true)
      ..setFillColor(ColorUtils.getHoloBlue())
      ..setFillAlpha(80);

    // Create heap capacity dataset.
    capacityHeapSet = LineDataSet(chartData.capacity, 'Capacity')
      ..setAxisDependency(AxisDependency.LEFT)
      ..setColor1(ColorUtils.GRAY)
      ..setValueTextColor(ColorUtils.GRAY)
      ..setLineWidth(.5)
      ..enableDashedLine(5, 5, 0)
      ..setDrawCircles(false)
      ..setDrawValues(false)
      ..setFillAlpha(65)
      ..setFillColor(ColorUtils.GRAY)
      ..setDrawCircleHole(false);

    // Create external memory dataset.
    const externalColorLine =
        Color.fromARGB(0xff, 0x42, 0xa5, 0xf5); // Color.blue[400]
    const externalColor =
        Color.fromARGB(0xff, 0x90, 0xca, 0xf9); // Color.blue[200]
    externalMemorySet = LineDataSet(chartData.externalHeap, 'External');
    externalMemorySet
      ..setAxisDependency(AxisDependency.LEFT)
      ..setColor1(externalColorLine)
      ..setLineWidth(.7)
      ..setDrawCircles(false)
      ..setDrawValues(false)
      ..setHighLightColor(const Color.fromARGB(255, 244, 117, 117))
      ..setDrawCircleHole(false)
      // Fill in area under set.
      ..setDrawFilled(true)
      ..setFillColor(externalColor)
      ..setFillAlpha(190);

    // Create a data object with all the data sets.
    chartController.data = LineData.fromList(
      []
        ..add(
          usedHeapSet,
        )
        ..add(
          externalMemorySet,
        )
        ..add(
          capacityHeapSet,
        ),
    );

    chartController.data
      ..setValueTextColor(ColorUtils.getHoloBlue())
      ..setValueTextSize(9);
  }
}

class XAxisFormatter extends ValueFormatter {
  final intl.DateFormat mFormat = intl.DateFormat('hh:mm:ss.mmm');

  @override
  String getFormattedValue1(double value) {
    return mFormat.format(DateTime.fromMillisecondsSinceEpoch(value.toInt()));
  }
}

typedef SelectionCallback = void Function(int timestamp);

typedef AllValuesCallback = HeapSample Function(int timestamp);

/// Selection of a point in the Bar chart displays the data point values
/// UI duration and GPU duration. Also, highlight the selected stacked bar.
/// Uses marker/highlight mechanism which lags because it uses onTapUp maybe
/// onTapDown would be less laggy.
///
/// TODO(terry): Highlighting is not efficient, a faster mechanism to return
/// the Entry being clicked is needed.
///
/// onSelected callback function invoked when bar entry is selected.
class SelectedDataPoint extends LineChartMarker {
  SelectedDataPoint({
    this.textColor,
    this.backColor,
    this.fontSize,
    this.onSelected,
    this.getAllValues,
  }) {
    _timestampFormatter = XAxisFormatter();
    _formatter = DefaultValueFormatter(0);
    textColor ??= ColorUtils.WHITE;
    backColor ??= const Color.fromARGB(127, 0, 0, 0);
    fontSize ??= 10;
  }

  Entry _entry;

  DefaultValueFormatter _formatter;

  XAxisFormatter _timestampFormatter;

  Color textColor;

  Color backColor;

  double fontSize;

  int _lastTimestmap = -1;

  final SelectionCallback onSelected;

  final AllValuesCallback getAllValues;

  @override
  void draw(Canvas canvas, double posX, double posY) {
    const positionAboveBar = 15;
    const paddingAroundText = 5;
    const rectangleCurve = 5.0;

    final timestampAsInt = _entry.x.toInt();

    final values = getAllValues(timestampAsInt);

    assert(values.timestamp == timestampAsInt);

    final num heapCapacity = values.capacity.toDouble();
    final num heapUsed = values.used.toDouble();
    final num external = values.external.toDouble();
    final num rss = values.rss.toDouble();
    final bool isGced = values.isGC;

    final TextPainter painter = PainterUtils.create(
      null,
      'Time       ${_timestampFormatter.getFormattedValue1(timestampAsInt.toDouble())}\n'
      'Capacity ${_formatter.getFormattedValue1(heapCapacity)}\n'
      'Used       ${_formatter.getFormattedValue1(heapUsed)}\n'
      'External  ${_formatter.getFormattedValue1(external)}\n'
      'RSS        ${_formatter.getFormattedValue1(rss)}\n'
      'GC          $isGced',
      textColor,
      fontSize,
    )..textAlign = TextAlign.left;

    final Paint paint = Paint()
      ..color = backColor
      ..strokeWidth = 2
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    final MPPointF offset = getOffsetForDrawingAtPoint(
      posX,
      posY,
    );

    canvas.save();
    // translate to the correct position and draw
    painter.layout();
    final Offset pos = calculatePos(
      posX + offset.x,
      posY + offset.y - positionAboveBar,
      painter.width,
      painter.height,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(
        pos.dx - paddingAroundText,
        pos.dy - paddingAroundText,
        pos.dx + painter.width + paddingAroundText,
        pos.dy + painter.height + paddingAroundText,
        const Radius.circular(rectangleCurve),
      ),
      paint,
    );
    painter.paint(canvas, pos);
    canvas.restore();
  }

  @override
  void refreshContent(Entry e, Highlight highlight) async {
    _entry = e;
    final timestamp = _entry.x.toInt();
    if (onSelected != null && _lastTimestmap != timestamp) {
      _lastTimestmap = timestamp;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => onSelected(timestamp));
    }
  }
}
