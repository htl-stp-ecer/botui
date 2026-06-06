import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/calib_board/application/calib_board_providers.dart';
import 'package:stpvelox/features/calib_board/presentation/widgets/value_chip.dart';

/// Integrierter Track des optischen Flow-Sensors.  Wir summieren die
/// dx/dy-Counts seit dem letzten Reset und plotten die resultierende
/// 2D-Trajektorie.  Praktisch um sofort zu sehen "geht der Sensor
/// linear / driftet er / springt SQUAL aus?".
///
/// Reset-Action in der AppBar.
class CalibPaaTrackScreen extends HookConsumerWidget {
  const CalibPaaTrackScreen({super.key});

  static const _maxPoints = 500;
  static const _sampleInterval = Duration(milliseconds: 16);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dxAsync = ref.watch(calibPaaDxProvider);
    final dyAsync = ref.watch(calibPaaDyProvider);

    final lastDx = useState<int?>(null);
    final lastDy = useState<int?>(null);
    dxAsync.whenData((v) => lastDx.value = v.value);
    dyAsync.whenData((v) => lastDy.value = v.value);

    final px = useState<int>(0);
    final py = useState<int>(0);
    final path = useState<List<(double, double)>>([(0, 0)]);

    useEffect(() {
      final t = Timer.periodic(_sampleInterval, (_) {
        final dx = lastDx.value;
        final dy = lastDy.value;
        if (dx == null || dy == null) return;
        px.value += dx;
        py.value += dy;
        final nx = px.value.toDouble();
        final ny = py.value.toDouble();
        final next = List<(double, double)>.from(path.value)..add((nx, ny));
        if (next.length > _maxPoints) {
          next.removeRange(0, next.length - _maxPoints);
        }
        path.value = next;
      });
      return t.cancel;
    }, const []);

    // cm-Position aus der Bridge (skaliert mit FW-Kalibrierung)
    final posXcm = ref.watch(calibPaaPosXProvider).value;
    final posYcm = ref.watch(calibPaaPosYProvider).value;
    final calValid = ref.watch(calibPaaCalValidProvider).value ?? false;

    void reset() {
      px.value = 0;
      py.value = 0;
      path.value = [(0, 0)];
      // Bridge-Position auch nullen damit die cm-Anzeige nicht
      // weiter läuft.
      ref.read(calibCommandPublisherProvider).sendResetPosition();
    }

    return Scaffold(
      appBar: createTopBar(
        context,
        'Track',
        actions: [
          IconButton(
            tooltip: 'Reset',
            icon: const Icon(Icons.restart_alt),
            onPressed: reset,
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
                    value: posXcm == null ? '—' : posXcm.toStringAsFixed(2),
                    sub: calValid ? 'cm (calibrated)' : 'cm (defaults)',
                  ),
                  ValueChip(
                    label: 'Y',
                    value: posYcm == null ? '—' : posYcm.toStringAsFixed(2),
                    sub: calValid ? 'cm (calibrated)' : 'cm (defaults)',
                  ),
                  ValueChip(
                    label: 'raw',
                    value: '${px.value} / ${py.value}',
                    sub: 'counts',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(child: _PathPlot(path: path.value)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PathPlot extends StatelessWidget {
  final List<(double, double)> path;
  const _PathPlot({required this.path});

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) {
      return const Center(
        child: Text('no samples yet…',
            style: TextStyle(color: Colors.white60)),
      );
    }

    // Autoscale: padding um die Bounding-Box, mindestens ±50 damit's bei
    // Stillstand nicht auf einen Pixel zoomt.
    double minX = 0, maxX = 0, minY = 0, maxY = 0;
    for (final p in path) {
      if (p.$1 < minX) minX = p.$1;
      if (p.$1 > maxX) maxX = p.$1;
      if (p.$2 < minY) minY = p.$2;
      if (p.$2 > maxY) maxY = p.$2;
    }
    final padX = ((maxX - minX) * 0.1).clamp(50, double.infinity);
    final padY = ((maxY - minY) * 0.1).clamp(50, double.infinity);
    minX -= padX; maxX += padX; minY -= padY; maxY += padY;

    final spots = path.map((p) => FlSpot(p.$1, p.$2)).toList();

    return RepaintBoundary(
      child: LineChart(
        duration: Duration.zero,
        LineChartData(
          clipData: const FlClipData.all(),
          minX: minX, maxX: maxX, minY: minY, maxY: maxY,
          gridData: const FlGridData(show: true),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.white24),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: const Color(0xFF26C6DA),
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}
