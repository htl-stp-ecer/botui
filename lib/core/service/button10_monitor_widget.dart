import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/core/service/button10_monitor.dart';
import 'package:stpvelox/core/service/screenshot_service.dart';

/// Widget that monitors button 10 for long presses globally.
/// Wrap your MaterialApp or main scaffold with this widget.
class Button10MonitorWidget extends ConsumerStatefulWidget {
  final Widget child;

  const Button10MonitorWidget({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<Button10MonitorWidget> createState() =>
      _Button10MonitorWidgetState();
}

class _Button10MonitorWidgetState extends ConsumerState<Button10MonitorWidget> {
  Timer? _checkTimer;

  @override
  void initState() {
    super.initState();
    // Check hold duration every 100ms
    _checkTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) {
        ref.read(button10MonitorProvider.notifier).checkHoldDuration();
      }
    });
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Initialize the monitor provider
    ref.watch(button10MonitorProvider);
    final screenshots = ref.watch(screenshotServiceProvider);
    return RepaintBoundary(key: screenshots.boundaryKey, child: widget.child);
  }
}
