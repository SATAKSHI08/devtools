// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../flutter/controllers.dart';
import '../../flutter/octicons.dart';
import '../../flutter/screen.dart';
import '../../flutter/split.dart';
import '../../globals.dart';
import '../../ui/flutter/label.dart';
import 'memory_chart.dart';
import 'memory_controller.dart';

class MemoryScreen extends Screen {
  const MemoryScreen();

  @visibleForTesting
  static const pauseButtonKey = Key('Pause Button');
  @visibleForTesting
  static const resumeButtonKey = Key('Resume Button');
  @visibleForTesting
  static const dropdownSourceMenuButtonKey = Key('Dropdown Source Menu Button');
  @visibleForTesting
  static const memorySourcesMenuItem = Key('Memory Sources Menu Item');
  @visibleForTesting
  static const memorySourcesKey = Key('Memory Sources');
  @visibleForTesting
  static const exportButtonKey = Key('Export Button');
  @visibleForTesting
  static const snapshotButtonKey = Key('Snapshot Button');
  @visibleForTesting
  static const resetButtonKey = Key('Reset Button');
  @visibleForTesting
  static const gcButtonKey = Key('GC Button');

  static const memorySourceMenuItemPrefix = 'Source: ';

  @override
  Widget build(BuildContext context) => const MemoryBody();

  @override
  Widget buildTab(BuildContext context) {
    return const Tab(
      text: 'Memory',
      icon: Icon(Octicons.package),
    );
  }
}

class MemoryBody extends StatefulWidget {
  const MemoryBody();

  @override
  MemoryBodyState createState() => MemoryBodyState();
}

class MemoryBodyState extends State<MemoryBody> {
  MemoryChart _memoryChart;

  MemoryController controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Controllers.of(context).memory;
    if (newController == controller) return;
    controller = newController;

    _updateListeningState();
  }

  @override
  Widget build(BuildContext context) {
    _memoryChart = MemoryChart();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _leftsideButtons(),
            _rightsideButtons(),
          ],
        ),
        Expanded(
          child: Split(
            axis: Axis.vertical,
            firstChild: _memoryChart,
            secondChild: const Text('Memory Panel TBD capacity'),
            initialFirstFraction: 0.25,
          ),
        ),
      ],
    );
  }

  Widget _memorySourceDropdown() {
    final files = controller.memoryLog.offlineFiles();

    // First item is 'Live Feed', then followed by memory log filenames.
    files.insert(0, MemoryController.liveFeed);

    final allMemorySources = files.map<DropdownMenuItem<String>>((
      String value,
    ) {
      return DropdownMenuItem<String>(
        key: MemoryScreen.memorySourcesMenuItem,
        value: value,
        child: Text(
          '${MemoryScreen.memorySourceMenuItemPrefix}$value',
          key: MemoryScreen.memorySourcesKey,
        ),
      );
    }).toList();

    return DropdownButton<String>(
      key: MemoryScreen.dropdownSourceMenuButtonKey,
      value: controller.memorySource,
      iconSize: 20,
      style: TextStyle(fontWeight: FontWeight.w100),
      onChanged: (String newValue) {
        setState(() {
          controller.memorySource = newValue;
        });
      },
      items: allMemorySources,
    );
  }

  void _updateListeningState() async {
    await serviceManager.serviceAvailable.future;

    if (controller != null && controller.hasStarted) return;

    if (controller != null) await controller.startTimeline();

    // TODO(terry): Need to set the initial state of buttons.
/*
      pauseButton.disabled = false;
      resumeButton.disabled = true;

      vmMemorySnapshotButton.disabled = false;
      resetAccumulatorsButton.disabled = false;
      gcNowButton.disabled = false;

      memoryChart.disabled = false;
*/
  }

  Widget _leftsideButtons() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        OutlineButton(
          key: MemoryScreen.pauseButtonKey,
          onPressed: controller.paused ? null : _pauseLiveTimeline,
          child: const MaterialIconLabel(
            Icons.pause,
            'Pause',
            minIncludeTextWidth: 900,
          ),
        ),
        OutlineButton(
          key: MemoryScreen.resumeButtonKey,
          onPressed: controller.paused ? _resumeLiveTimeline : null,
          child: const MaterialIconLabel(
            Icons.play_arrow,
            'Resume',
            minIncludeTextWidth: 900,
          ),
        ),
      ],
    );
  }

  Widget _rightsideButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _memorySourceDropdown(),
        const SizedBox(width: 16.0),
        OutlineButton(
          key: MemoryScreen.snapshotButtonKey,
          onPressed: _snapshot,
          child: MaterialIconLabel(
            Icons.camera,
            'Snapshot',
            minIncludeTextWidth: 1100,
          ),
        ),
        OutlineButton(
          key: MemoryScreen.resetButtonKey,
          onPressed: _reset,
          child: MaterialIconLabel(
            Icons.settings_backup_restore,
            'Reset',
            minIncludeTextWidth: 1100,
          ),
        ),
        OutlineButton(
          key: MemoryScreen.gcButtonKey,
          onPressed: _gc,
          child: MaterialIconLabel(
            Icons.delete_sweep,
            'GC',
            minIncludeTextWidth: 1100,
          ),
        ),
        const SizedBox(width: 16.0),
        OutlineButton(
          key: MemoryScreen.exportButtonKey,
          onPressed:
              controller.offline ? null : controller.memoryLog.exportMemory,
          child: MaterialIconLabel(
            Icons.file_download,
            'Export',
            minIncludeTextWidth: 1100,
          ),
        ),
      ],
    );
  }

  // Callbacks for button actions:

  void _pauseLiveTimeline() {
    // TODO(terry): Implement real pause when connected to live feed.
    controller.pauseLiveFeed();
    setState(() {});
  }

  void _resumeLiveTimeline() {
    // TODO(terry): Implement real resume when connected to live feed.
    controller.resumeLiveFeed();
    setState(() {});
  }

  void _snapshot() {
    // TODO(terry): Implementation needed.
  }

  void _reset() {
    // TODO(terry): TBD real implementation needed.
  }

  void _gc() {
    // TODO(terry): Implementation needed.
  }
}
