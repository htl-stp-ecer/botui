import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Mehrachsen-Liniendiagramm mit fixiertem Y-Bereich.  Bewusst dünner
/// als das general-purpose SensorGraphWidget: kein Moving-Average, keine
/// Statistik, einfach die Linien gegen die Sample-Nummer auf X.
///
/// [z] ist optional — wird es weggelassen, rendert der Chart nur zwei
/// Linien (z. B. PAA dx/dy).  Die Legenden-Labels sind frei setzbar,
/// damit Roll/Pitch/Yaw nicht fälschlich als "X/Y/Z" beschriftet werden.
class TriaxialChart extends StatelessWidget {
  final List<double> x;
  final List<double> y;
  final List<double>? z;
  final double minY;
  final double maxY;
  final String unitLabel;
  final String labelX;
  final String labelY;
  final String labelZ;

  const TriaxialChart({
    super.key,
    required this.x,
    required this.y,
    this.z,
    required this.minY,
    required this.maxY,
    required this.unitLabel,
    this.labelX = 'X',
    this.labelY = 'Y',
    this.labelZ = 'Z',
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

    final hasZ = z != null && z!.isNotEmpty;

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
            _legend(labelX, _colX),
            const SizedBox(width: 12),
            _legend(labelY, _colY),
            if (hasZ) ...[
              const SizedBox(width: 12),
              _legend(labelZ, _colZ),
            ],
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
                  if (hasZ) barFor(z!, _colZ),
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
