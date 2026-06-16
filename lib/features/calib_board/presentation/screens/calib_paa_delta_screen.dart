import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/calib_board/application/calib_board_providers.dart';
import 'package:stpvelox/features/calib_board/presentation/widgets/triaxial_chart.dart';
import 'package:stpvelox/features/calib_board/presentation/widgets/value_chip.dart';

/// PAA dx/dy live Chart.  Zwei Linien — dX rot, dY grün.  Range ±32
/// reicht für typische Bewegung; bei schneller Verschiebung clippt's,
/// kann man später dynamisch machen.
class CalibPaaDeltaScreen extends HookConsumerWidget {
  const CalibPaaDeltaScreen({super.key});

  static const _maxPoints = 250;
  static const _sampleInterval = Duration(milliseconds: 16);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dxAsync = ref.watch(calibPaaDxProvider);
    final dyAsync = ref.watch(calibPaaDyProvider);

    final lastDx = useState<int?>(null);
    final lastDy = useState<int?>(null);
    dxAsync.whenData((v) => lastDx.value = v.value);
    dyAsync.whenData((v) => lastDy.value = v.value);

    final dxHist = useState<List<double>>([]);
    final dyHist = useState<List<double>>([]);

    useEffect(() {
      final t = Timer.periodic(_sampleInterval, (_) {
        final dx = lastDx.value;
        final dy = lastDy.value;
        if (dx == null || dy == null) return;
        dxHist.value = _push(dxHist.value, dx.toDouble());
        dyHist.value = _push(dyHist.value, dy.toDouble());
      });
      return t.cancel;
    }, const []);

    return Scaffold(
      appBar: createTopBar(context, 'Delta (dx/dy)'),
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Row(
                children: [
                  ValueChip(
                    label: 'dx',
                    value: lastDx.value?.toString() ?? '—',
                    sub: 'counts',
                    accent: const Color(0xFFEF5350),
                  ),
                  ValueChip(
                    label: 'dy',
                    value: lastDy.value?.toString() ?? '—',
                    sub: 'counts',
                    accent: const Color(0xFF66BB6A),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TriaxialChart(
                  x: dxHist.value, y: dyHist.value,
                  minY: -32, maxY: 32,
                  unitLabel: 'delta [counts/sample]',
                  labelX: 'dX', labelY: 'dY',
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
