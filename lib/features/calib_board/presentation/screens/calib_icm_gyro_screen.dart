import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/calib_board/application/calib_board_providers.dart';
import 'package:stpvelox/features/calib_board/presentation/widgets/triaxial_chart.dart';
import 'package:stpvelox/features/calib_board/presentation/widgets/value_chip.dart';

/// ICM-Gyroscope Detail.  3-Achs Chart in dps + Zero-Bias-Action.
///
/// "Zero" merkt sich den Snapshot der aktuellen Roh-Achswerte als
/// Offset und plottet nur die Differenz — gut zum visuellen Sichten,
/// die echte Bias-Subtraktion gehört aber in Firmware bzw. ins
/// downstream Fusionsmodell.
class CalibIcmGyroScreen extends HookConsumerWidget {
  const CalibIcmGyroScreen({super.key});

  static const _maxPoints = 250;
  static const _sampleInterval = Duration(milliseconds: 16);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gyroAsync = ref.watch(calibIcmGyroProvider);
    final last = useState<(double, double, double)?>(null);
    gyroAsync.whenData((v) => last.value = (v.x, v.y, v.z));

    final bias = useState<(double, double, double)>((0, 0, 0));

    final x = useState<List<double>>([]);
    final y = useState<List<double>>([]);
    final z = useState<List<double>>([]);

    useEffect(() {
      final t = Timer.periodic(_sampleInterval, (_) {
        final v = last.value;
        if (v == null) return;
        x.value = _push(x.value, v.$1 - bias.value.$1);
        y.value = _push(y.value, v.$2 - bias.value.$2);
        z.value = _push(z.value, v.$3 - bias.value.$3);
      });
      return t.cancel;
    }, const []);

    void zero() {
      final v = last.value;
      if (v == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No gyro samples yet — wait a moment.')),
        );
        return;
      }
      bias.value = v;
      x.value = [];
      y.value = [];
      z.value = [];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          'Zero set: bias = (${v.$1.toStringAsFixed(2)}, '
          '${v.$2.toStringAsFixed(2)}, '
          '${v.$3.toStringAsFixed(2)}) dps')),
      );
    }

    final (bx, by, bz) = bias.value;
    final displayed = last.value == null
        ? null
        : (last.value!.$1 - bx, last.value!.$2 - by, last.value!.$3 - bz);

    return Scaffold(
      appBar: createTopBar(
        context,
        'Gyroscope',
        actions: [
          IconButton(
            tooltip: 'Zero bias',
            icon: const Icon(Icons.center_focus_strong),
            onPressed: zero,
          ),
        ],
      ),
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
                    value: _fmt(displayed?.$1),
                    sub: 'dps',
                    accent: const Color(0xFFEF5350),
                  ),
                  ValueChip(
                    label: 'Y',
                    value: _fmt(displayed?.$2),
                    sub: 'dps',
                    accent: const Color(0xFF66BB6A),
                  ),
                  ValueChip(
                    label: 'Z',
                    value: _fmt(displayed?.$3),
                    sub: 'dps',
                    accent: const Color(0xFF42A5F5),
                  ),
                  ValueChip(
                    label: 'bias',
                    value: '${bx.toStringAsFixed(1)} / ${by.toStringAsFixed(1)} / ${bz.toStringAsFixed(1)}',
                    sub: 'dps offset',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TriaxialChart(
                  x: x.value, y: y.value, z: z.value,
                  minY: -500, maxY: 500,
                  unitLabel: 'gyro [dps] (bias-subtracted)',
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
