import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/calib_board/application/calib_board_providers.dart';
import 'package:stpvelox/features/calib_board/presentation/widgets/single_line_chart.dart';

/// PAA SQUAL = Surface Quality (0..169).  Großer Live-Wert mit Ampel-
/// Färbung (rot/orange/grün) je nach Bereich.  Datasheet:
///   >  60   gut
///   40–60  ok
///   <  40  Tracking zweifelhaft (zu glatt / zu rau / Höhe falsch)
class CalibPaaSqualScreen extends HookConsumerWidget {
  const CalibPaaSqualScreen({super.key});

  static const _maxPoints = 400;        // 40 s @ 10 Hz
  static const _sampleInterval = Duration(milliseconds: 100);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final squalAsync = ref.watch(calibPaaSqualProvider);
    final last = useState<int?>(null);
    squalAsync.whenData((v) => last.value = v.value);

    final history = useState<List<double>>([]);
    useEffect(() {
      final t = Timer.periodic(_sampleInterval, (_) {
        final v = last.value;
        if (v == null) return;
        history.value = _push(history.value, v.toDouble());
      });
      return t.cancel;
    }, const []);

    final color = _color(last.value);

    return Scaffold(
      appBar: createTopBar(context, 'SQUAL (Surface Quality)'),
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _SqualReadout(value: last.value, color: color),
              const SizedBox(height: 12),
              Expanded(
                child: SingleLineChart(
                  data: history.value,
                  minY: 0, maxY: 170,
                  unitLabel: 'SQUAL (0–169), 40 s history',
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _color(int? v) {
    if (v == null) return const Color(0xFF42A5F5);
    if (v < 40) return const Color(0xFFEF5350);    // red
    if (v < 60) return const Color(0xFFFFA726);    // orange
    return const Color(0xFF66BB6A);                // green
  }

  static List<double> _push(List<double> buf, double v) {
    final next = List<double>.from(buf)..add(v);
    if (next.length > _maxPoints) {
      next.removeRange(0, next.length - _maxPoints);
    }
    return next;
  }
}

class _SqualReadout extends StatelessWidget {
  final int? value;
  final Color color;
  const _SqualReadout({required this.value, required this.color});

  String _verdict() {
    if (value == null) return '—';
    if (value! < 40) return 'poor tracking';
    if (value! < 60) return 'acceptable';
    return 'good';
  }

  @override
  Widget build(BuildContext context) {
    final v = value;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        children: [
          const Text('SQUAL',
              style: TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(width: 12),
          Text(
            v?.toString() ?? '—',
            style: TextStyle(
              color: color,
              fontSize: 44,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          Text('/ 169',
              style: TextStyle(color: Colors.white38, fontSize: 18)),
          const Spacer(),
          Text(_verdict(),
              style: TextStyle(color: color, fontSize: 16,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
