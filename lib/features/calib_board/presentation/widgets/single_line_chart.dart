import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Eine einzelne History-Linie über Sample-Index.  Für Skalar-Werte
/// (Temperatur, SQUAL, Shutter).
class SingleLineChart extends StatelessWidget {
  final List<double> data;
  final double minY;
  final double maxY;
  final Color color;
  final String unitLabel;

  const SingleLineChart({
    super.key,
    required this.data,
    required this.minY,
    required this.maxY,
    required this.unitLabel,
    this.color = const Color(0xFF42A5F5),
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(
        child: Text('waiting for samples…',
            style: TextStyle(color: Colors.white60)),
      );
    }

    final spots = List<FlSpot>.generate(
        data.length, (i) => FlSpot(i.toDouble(), data[i]));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(unitLabel,
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 6),
        Expanded(
          child: RepaintBoundary(
            child: LineChart(
              duration: Duration.zero,
              LineChartData(
                clipData: const FlClipData.all(),
                minY: minY,
                maxY: maxY,
                minX: 0,
                maxX: (data.length - 1).toDouble().clamp(1, double.infinity),
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.white24),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: color,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
