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
    return Stack(
      fit: StackFit.passthrough,
      children: [
        // The badge sits outside the boundary so it isn't in the screenshot.
        RepaintBoundary(key: screenshots.boundaryKey, child: widget.child),
        Positioned(
          left: 0,
          right: 0,
          bottom: 12,
          child: IgnorePointer(
            child: ValueListenableBuilder<String?>(
              valueListenable: screenshots.badge,
              builder: (context, text, _) {
                if (text == null) return const SizedBox.shrink();
                return Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xE6212121),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0x66FFFFFF)),
                    ),
                    child: Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        decoration: TextDecoration.none,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
