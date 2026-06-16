import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/calib_board/application/calib_board_providers.dart';
import 'package:stpvelox/features/calib_board/presentation/widgets/triaxial_chart.dart';
import 'package:stpvelox/features/calib_board/presentation/widgets/value_chip.dart';

/// ICM-Gyroscope Detail.  Eine Wertezeile (X/Y/Z) + Full-Screen 3-Achs
/// Chart in dps.  Die echte Bias-Kalibrierung läuft im Firmware und hat
/// einen eigenen Screen ("Calibration") — hier nur die rohe Live-Rate.
class CalibIcmGyroScreen extends HookConsumerWidget {
  const CalibIcmGyroScreen({super.key});

  static const _maxPoints = 250;
  static const _sampleInterval = Duration(milliseconds: 16);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gyroAsync = ref.watch(calibIcmGyroProvider);
    final last = useState<(double, double, double)?>(null);
    gyroAsync.whenData((v) => last.value = (v.x, v.y, v.z));

    final x = useState<List<double>>([]);
    final y = useState<List<double>>([]);
    final z = useState<List<double>>([]);

    useEffect(() {
      final t = Timer.periodic(_sampleInterval, (_) {
        final v = last.value;
        if (v == null) return;
        x.value = _push(x.value, v.$1);
        y.value = _push(y.value, v.$2);
        z.value = _push(z.value, v.$3);
      });
      return t.cancel;
    }, const []);

    return Scaffold(
      appBar: createTopBar(context, 'Gyroscope'),
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Row(
                children: [
                  ValueChip(
                    label: 'X',
                    value: _fmt(last.value?.$1),
                    sub: 'dps',
                    accent: const Color(0xFFEF5350),
                  ),
                  ValueChip(
                    label: 'Y',
                    value: _fmt(last.value?.$2),
                    sub: 'dps',
                    accent: const Color(0xFF66BB6A),
                  ),
                  ValueChip(
                    label: 'Z',
                    value: _fmt(last.value?.$3),
                    sub: 'dps',
                    accent: const Color(0xFF42A5F5),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TriaxialChart(
                  x: x.value, y: y.value, z: z.value,
                  minY: -500, maxY: 500,
                  unitLabel: 'gyro [dps]',
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

  static String _fmt(double? v) =>
      v == null ? '—' : v.toStringAsFixed(2);
}
