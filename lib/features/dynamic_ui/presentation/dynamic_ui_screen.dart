import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:stpvelox/core/transport/domain/providers.dart';
import 'package:stpvelox/features/screen_renderer/application/screen_renderer_provider.dart';
import 'package:raccoon_transport/raccoon_transport.dart';

import 'widget_decoder.dart';

final _log = Logger('DynamicUIScreen');

/// Dynamic UI screen that renders widgets from JSON definitions.
///
/// Watches the [ScreenRenderProvider] directly so that only a single instance
/// ever exists. When new data arrives the widget simply re-renders in place
/// instead of being pushed/popped on the navigation stack.
///
/// ### Setup-timer protocol
///
/// If the JSON contains a `setup_timer` map, a countdown is shown in the
/// AppBar. The library can push a new `screen_render` at any time to
/// update the timer state; the UI ticks the counter locally between pushes
/// so no per-second LCM messages are needed.
///
/// ```json
/// {
///   "title": "Setup Mission",
///   "setup_timer": { "seconds": 120, "paused": false },
///   "body": { … }
/// }
/// ```
///
/// | field     | type | meaning                                         |
/// |-----------|------|-------------------------------------------------|
/// | `seconds` | int  | Remaining seconds to display / resume from      |
/// | `paused`  | bool | `true` freezes the local countdown              |
class DynamicUIScreen extends HookConsumerWidget {
  const DynamicUIScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenData = ref.watch(screenRenderProviderProvider);

    if (screenData == null) {
      // Provider cleared while we're still mounted — show nothing.
      return const SizedBox.shrink();
    }

    final buildTimestamp = DateTime.now().toIso8601String();
    final title = screenData['title'] as String? ?? 'Screen';
    final body = screenData['body'] as Map<String, dynamic>?;

    _log.info('[BUILD @ $buildTimestamp] DynamicUIScreen building with title="$title"');
    _log.fine('[BUILD] screenData keys: ${screenData.keys.toList()}');
    _log.fine('[BUILD] body widget type: ${body?['widget'] ?? 'null'}');

    // ── Setup timer ────────────────────────────────────────────────────────
    // Remaining seconds shown in the AppBar. Null = no timer.
    final remaining = useState<int?>(null);
    // Last seconds value that came in via JSON — used to detect explicit
    // resets so a body-only push doesn't jump the locally-ticking counter.
    final lastJsonSeconds = useRef<int?>(null);

    useEffect(() {
      final timerCfg = screenData['setup_timer'] as Map<String, dynamic>?;
      if (timerCfg == null) {
        remaining.value = null;
        lastJsonSeconds.value = null;
        return null;
      }

      final seconds = timerCfg['seconds'] as int? ?? 0;
      final paused = timerCfg['paused'] as bool? ?? false;

      // Only overwrite the live counter when the library explicitly changed
      // the seconds value. A push that keeps seconds identical (e.g. a body
      // update) leaves the locally-ticking value untouched.
      if (seconds != lastJsonSeconds.value) {
        lastJsonSeconds.value = seconds;
        remaining.value = seconds <= 0 ? 0 : seconds;
      }

      if (paused || (remaining.value ?? 0) <= 0) {
        // Nothing to tick — library wants a frozen display.
        return null;
      }

      // Tick locally every second to reduce LCM traffic.
      // Continues past zero into negative (overtime).
      final timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final cur = remaining.value;
        if (cur == null) return;
        remaining.value = cur - 1;
      });

      return timer.cancel;
    }, [screenData]);

    // ── Input value tracking ───────────────────────────────────────────────
    final values = useState<Map<String, dynamic>>({});

    useEffect(() {
      _log.info('[EFFECT] useEffect triggered for screenData change, title="$title"');
      final newValues = <String, dynamic>{};
      _extractInitialValues(screenData, newValues);
      values.value = newValues;
      _log.fine('[EFFECT] Initial values extracted: ${values.value}');
      return null;
    }, [screenData]);

    // ── LCM event helpers ──────────────────────────────────────────────────
    void sendEvent(String action, {Map<String, dynamic>? extra}) {
      final timestamp = DateTime.now().toIso8601String();
      final transport = ref.read(transportServiceProvider);

      final payload = {
        '_action': action,
        'values': values.value,
        ...?extra,
      };

      final response = ScreenRenderAnswerT(
        timestamp: DateTime.now().microsecondsSinceEpoch,
        screen_name: 'dynamic_ui',
        value: action,
        reason: jsonEncode(payload),
      );

      _log.info('[LCM TX @ $timestamp] screen_answer -> action=$action');
      _log.fine('[LCM TX] extra=$extra');
      _log.fine('[LCM TX] current values=${values.value}');
      _log.fine('[LCM TX] full payload=${jsonEncode(payload)}');
      transport.publish(Channels.screenRenderAnswer, response,
          options: const PublishOptions(reliable: true));
      _log.info('[LCM TX] Message published successfully');
    }

    void onValueChanged(String widgetId, dynamic value) {
      values.value = {...values.value, widgetId: value};
      sendEvent('change', extra: {'widget_id': widgetId, 'value': value});
    }

    void onButtonClicked(String buttonId) {
      sendEvent('click', extra: {'button_id': buttonId});
    }

    void onKeypadInput(String key) {
      sendEvent('keypad', extra: {'key': key});
    }

    final decoder = WidgetDecoder(
      onValueChanged: onValueChanged,
      onButtonClicked: onButtonClicked,
      onKeypadInput: onKeypadInput,
      ref: ref,
    );

    _log.info('[BUILD] Creating widget tree for title="$title"');

    Widget bodyWidget;
    if (body != null) {
      _log.info('[BUILD] Decoding body widget...');
      bodyWidget = decoder.decode(body);
      _log.info('[BUILD] Body widget decoded successfully');
    } else {
      _log.warning('[BUILD] No body content, showing placeholder');
      bodyWidget = const Center(
        child: Text('No content', style: TextStyle(color: Colors.grey)),
      );
    }

    _log.info('[BUILD] Returning Scaffold for title="$title"');

    final timerCfg = screenData['setup_timer'] as Map<String, dynamic>?;
    final timerPaused = timerCfg != null && (timerCfg['paused'] as bool? ?? false);
    final secs = remaining.value;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.grey[900],
          automaticallyImplyLeading: false,
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            if (secs != null)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _SetupTimer(seconds: secs, paused: timerPaused),
              ),
          ],
          toolbarHeight: 80,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: bodyWidget,
        ),
      ),
    );
  }
}

// ── SetupTimer widget ──────────────────────────────────────────────────────────

class _SetupTimer extends StatelessWidget {
  const _SetupTimer({required this.seconds, required this.paused});

  final int seconds;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final bool overtime = seconds < 0;
    final int abs = seconds.abs();
    final int minutes = abs ~/ 60;
    final int secs = abs % 60;
    final String timeStr = '${minutes.toString()}:${secs.toString().padLeft(2, '0')}';
    final String label = overtime ? '-$timeStr' : timeStr;

    final Color color;
    if (paused) {
      color = Colors.blueGrey;
    } else if (overtime) {
      color = Colors.red;
    } else if (seconds <= 10) {
      color = Colors.red;
    } else if (seconds <= 30) {
      color = Colors.orange;
    } else {
      color = Colors.green;
    }

    final IconData icon = paused
        ? Icons.pause_circle_outline
        : overtime
            ? Icons.timer_off_outlined
            : Icons.timer_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: overtime && !paused ? 0.25 : 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: overtime && !paused ? 2.0 : 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

void _extractInitialValues(Map<String, dynamic> data, Map<String, dynamic> values) {
  void extract(dynamic item) {
    if (item is Map<String, dynamic>) {
      final id = item['id'] as String?;
      final value = item['value'];
      if (id != null && value != null) {
        values[id] = value;
      }

      final children = item['children'];
      if (children is List) {
        for (final child in children) {
          extract(child);
        }
      }

      final left = item['left'];
      if (left is List) {
        for (final child in left) {
          extract(child);
        }
      }
      final right = item['right'];
      if (right is List) {
        for (final child in right) {
          extract(child);
        }
      }

      final body = item['body'];
      if (body is Map<String, dynamic>) {
        extract(body);
      }
    }
  }

  extract(data);
}
