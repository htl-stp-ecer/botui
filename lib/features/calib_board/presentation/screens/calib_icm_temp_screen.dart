import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/calib_board/application/calib_board_providers.dart';
import 'package:stpvelox/features/calib_board/presentation/widgets/single_line_chart.dart';

/// ICM-Temperatur über der Zeit.  Großer Live-Wert oben, History unten.
/// Range 20–60 °C deckt Roomtemp bis "Robot im Spiel" ab.  Genau die
/// Quelle die später für Gyro-Bias-Drift-Kompensation gebraucht wird.
class CalibIcmTempScreen extends HookConsumerWidget {
  const CalibIcmTempScreen({super.key});

  static const _maxPoints = 600;            // 60 s @ 10 Hz Sampling
  static const _sampleInterval = Duration(milliseconds: 100);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tempAsync = ref.watch(calibIcmTempProvider);
    final last = useState<double?>(null);
    tempAsync.whenData((v) => last.value = v.value);

    final history = useState<List<double>>([]);
    useEffect(() {
      final t = Timer.periodic(_sampleInterval, (_) {
        final v = last.value;
        if (v == null) return;
        history.value = _push(history.value, v);
      });
      return t.cancel;
    }, const []);

    return Scaffold(
      appBar: createTopBar(context, 'Temperature'),
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BigValue(label: 'ICM die', value: last.value, unit: '°C'),
              const SizedBox(height: 12),
              Expanded(
                child: SingleLineChart(
                  data: history.value,
                  minY: 20,
                  maxY: 60,
                  unitLabel: 'temperature [°C], 60 s history',
                  color: const Color(0xFFFFB74D),
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

class _BigValue extends StatelessWidget {
  final String label;
  final double? value;
  final String unit;
  const _BigValue({required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
          const Spacer(),
          Text(
            value == null ? '—' : value!.toStringAsFixed(2),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(unit, style: const TextStyle(color: Colors.white70, fontSize: 20)),
        ],
      ),
    );
  }
}
