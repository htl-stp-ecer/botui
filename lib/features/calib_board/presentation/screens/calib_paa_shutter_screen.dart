import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/calib_board/application/calib_board_providers.dart';
import 'package:stpvelox/features/calib_board/presentation/widgets/single_line_chart.dart';

/// PAA Shutter — 16-bit Belichtungszeit-Register.  Höher = dunklere
/// Oberfläche / mehr Belichtung nötig.  Spannungsspitzen oder
/// Lichtwechsel sieht man hier direkt.
class CalibPaaShutterScreen extends HookConsumerWidget {
  const CalibPaaShutterScreen({super.key});

  static const _maxPoints = 400;
  static const _sampleInterval = Duration(milliseconds: 100);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shutAsync = ref.watch(calibPaaShutterProvider);
    final last = useState<int?>(null);
    shutAsync.whenData((v) => last.value = v.value);

    final history = useState<List<double>>([]);
    useEffect(() {
      final t = Timer.periodic(_sampleInterval, (_) {
        final v = last.value;
        if (v == null) return;
        history.value = _push(history.value, v.toDouble());
      });
      return t.cancel;
    }, const []);

    return Scaffold(
      appBar: createTopBar(context, 'Shutter'),
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Text('Shutter',
                        style: TextStyle(color: Colors.white54, fontSize: 14)),
                    const Spacer(),
                    Text(
                      last.value?.toString() ?? '—',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleLineChart(
                  data: history.value,
                  minY: 0, maxY: 65535,
                  unitLabel: 'shutter (0–65535), 40 s history',
                  color: const Color(0xFF7E57C2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static List<double> _push(List<double> buf, double v) {
    final next = List<double>.from(buf)..add(v);
    if (next.length > _maxPoints) {
      next.removeRange(0, next.length - _maxPoints);
    }
    return next;
  }
}
