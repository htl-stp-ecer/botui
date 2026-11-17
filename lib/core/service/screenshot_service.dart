import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/core/logging/has_logging.dart';
import 'package:stpvelox/core/utils/local_test.dart';

final screenshotServiceProvider = Provider<ScreenshotService>((ref) {
  final service = ScreenshotService();
  ref.onDispose(service.dispose);
  return service;
});

/// Captures the Flutter-rendered UI to `~/screenshots/` as PNG.
///
/// [boundaryKey] must be attached to the [RepaintBoundary] wrapping the app
/// content (see `Button10MonitorWidget`). [badge] holds the text of the
/// "Saved Screenshot as …" badge while it is visible, otherwise null.
class ScreenshotService with HasLogger {
  final GlobalKey boundaryKey = GlobalKey(debugLabel: 'screenshotBoundary');
  final ValueNotifier<String?> badge = ValueNotifier<String?>(null);

  Timer? _badgeTimer;
  bool _busy = false;

  Future<void> capture() async {
    if (_busy) return;
    _busy = true;
    try {
      final boundary = boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        log.warning('Screenshot skipped: no RepaintBoundary attached');
        return;
      }

      final image = await boundary.toImage(pixelRatio: 1.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) {
        log.warning('Screenshot failed: PNG encoding returned null');
        return;
      }

      final dir = Directory('${_homeDir()}/screenshots');
      await dir.create(recursive: true);
      final name = '${_timestamp(DateTime.now())}.png';
      await File('${dir.path}/$name').writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );

      log.info('Saved screenshot ${dir.path}/$name');
      _showBadge('Saved Screenshot as $name');
    } catch (e, st) {
      log.severe('Screenshot failed', e, st);
      _showBadge('Screenshot failed');
    } finally {
      _busy = false;
    }
  }

  void _showBadge(String text) {
    _badgeTimer?.cancel();
    badge.value = text;
    _badgeTimer = Timer(const Duration(seconds: 3), () => badge.value = null);
  }

  static String _homeDir() {
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) return home;
    return kLocalTest ? Directory.systemTemp.path : '/home/pi';
  }

  static String _timestamp(DateTime t) {
    String p(int v, [int w = 2]) => v.toString().padLeft(w, '0');
    return '${p(t.year, 4)}-${p(t.month)}-${p(t.day)}_'
        '${p(t.hour)}-${p(t.minute)}-${p(t.second)}';
  }

  void dispose() {
    _badgeTimer?.cancel();
    badge.dispose();
  }
}
