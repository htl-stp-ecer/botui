import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/calib_board/application/calib_board_providers.dart';
import 'package:stpvelox/features/calib_board/presentation/widgets/triaxial_chart.dart';
import 'package:stpvelox/features/calib_board/presentation/widgets/value_chip.dart';

/// ICM-Accelerometer Detail.  Full-Screen 3-Achs Chart in g, dazu eine
/// kompakte Wertezeile (X/Y/Z + Magnitude).  Fix-Range ±2 g — Botball-
/// Robot sieht praktisch nie mehr, und ±16 g würde Bewegung im Plot
/// untergehen lassen.
class CalibIcmAccelScreen extends HookConsumerWidget {
  const CalibIcmAccelScreen({super.key});

  static const _maxPoints = 250;
  static const _sampleInterval = Duration(milliseconds: 16);  // ~60 Hz UI

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accelAsync = ref.watch(calibIcmAccelProvider);
    final last = useState<(double, double, double)?>(null);
    accelAsync.whenData((v) => last.value = (v.x, v.y, v.z));

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

    final mag = last.value == null
        ? null
        : _sqrt(last.value!.$1 * last.value!.$1 +
                last.value!.$2 * last.value!.$2 +
                last.value!.$3 * last.value!.$3);

    return Scaffold(
      appBar: createTopBar(context, 'Accelerometer'),
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
                    sub: 'g',
                    accent: const Color(0xFFEF5350),
                  ),
                  ValueChip(
                    label: 'Y',
                    value: _fmt(last.value?.$2),
                    sub: 'g',
                    accent: const Color(0xFF66BB6A),
                  ),
                  ValueChip(
                    label: 'Z',
                    value: _fmt(last.value?.$3),
                    sub: 'g',
                    accent: const Color(0xFF42A5F5),
                  ),
                  ValueChip(
                    label: '‖a‖',
                    value: mag == null ? '—' : mag.toStringAsFixed(3),
                    sub: 'g',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TriaxialChart(
                  x: x.value, y: y.value, z: z.value,
                  minY: -2, maxY: 2,
                  unitLabel: 'accel [g]',
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
      v == null ? '—' : v.toStringAsFixed(3);
}

// Newton sqrt — siehe Erklärung in calib_icm_temp_screen.dart.  Wir
// vermeiden dart:math weil flutterpi-Builds sonst auf manchen ARM-Targets
// eine größere Binary backen als nötig.
double _sqrt(double x) {
  if (x <= 0) return 0;
  double r = x;
  for (var i = 0; i < 6; i++) {
    r = 0.5 * (r + x / r);
  }
  return r;
}
