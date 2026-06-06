import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Drei-Achsen Liniendiagramm mit fixiertem Y-Bereich.  Bewusst dünner
/// als das general-purpose SensorGraphWidget: kein Moving-Average, keine
/// Statistik, einfach drei Linien gegen die Sample-Nummer auf X.
class TriaxialChart extends StatelessWidget {
  final List<double> x;
  final List<double> y;
  final List<double> z;
  final double minY;
  final double maxY;
  final String unitLabel;

  const TriaxialChart({
    super.key,
    required this.x,
    required this.y,
    required this.z,
    required this.minY,
    required this.maxY,
    required this.unitLabel,
  });

  static const _colX = Color(0xFFEF5350);
  static const _colY = Color(0xFF66BB6A);
  static const _colZ = Color(0xFF42A5F5);

  @override
  Widget build(BuildContext context) {
    if (x.isEmpty) {
      return const Center(
        child: Text('waiting for samples…',
            style: TextStyle(color: Colors.white60)),
      );
    }

    LineChartBarData barFor(List<double> values, Color color) {
      return LineChartBarData(
        spots: List<FlSpot>.generate(
            values.length, (i) => FlSpot(i.toDouble(), values[i])),
        isCurved: false,
        color: color,
        barWidth: 1.5,
        dotData: const FlDotData(show: false),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _legend('X', _colX),
            const SizedBox(width: 12),
            _legend('Y', _colY),
            const SizedBox(width: 12),
            _legend('Z', _colZ),
            const Spacer(),
            Text(unitLabel,
                style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: RepaintBoundary(
            child: LineChart(
              duration: Duration.zero,
              LineChartData(
                clipData: const FlClipData.all(),
                minY: minY,
                maxY: maxY,
                minX: 0,
                maxX: (x.length - 1).toDouble().clamp(1, double.infinity),
                gridData: const FlGridData(show: true,
                    drawVerticalLine: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.white24),
                ),
                lineBarsData: [
                  barFor(x, _colX),
                  barFor(y, _colY),
                  barFor(z, _colZ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _legend(String label, Color color) {
    return Row(
      children: [
        Container(width: 10, height: 10, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}
