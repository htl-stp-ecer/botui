import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/application/theme/color_theme_provider.dart';
import 'package:stpvelox/core/theme/app_theme.dart';

class DualSensorGraphWidget extends ConsumerWidget {
  final List<double> imuData;
  final List<double> imuMovingAvg;
  final List<double> cpuData;
  final List<double> cpuMovingAvg;
  final double graphMin;
  final double graphMax;
  final int maxPoints;
  final bool autoScale;

  const DualSensorGraphWidget({
    super.key,
    required this.imuData,
    required this.imuMovingAvg,
    required this.cpuData,
    required this.cpuMovingAvg,
    required this.graphMin,
    required this.graphMax,
    required this.maxPoints,
    required this.autoScale,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(colorThemeProvider);
    // IMU is series 0, CPU is series 1 (pattern themes: pattern[0], pattern[1]).
    final imuColor = theme.tileColor(TileColor.cyan, 0);
    final cpuColor = theme.tileColor(TileColor.orange, 1);
    final effectiveMin = autoScale ? _computeMin() : graphMin;
    final effectiveMax = autoScale ? _computeMax() : graphMax;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          minY: effectiveMin,
          maxY: effectiveMax,
          minX: 0,
          maxX: maxPoints.toDouble(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: (effectiveMax - effectiveMin) / 5,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.shade800,
                strokeWidth: 1,
              );
            },
            getDrawingVerticalLine: (value) {
              return FlLine(
                color: Colors.grey.shade800,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(0),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey.shade800),
          ),
          lineBarsData: [
            // IMU raw data line
            _buildLineChartBarData(
              imuData,
              imuColor.withValues(alpha: 0.3),
              1.5,
            ),
            // IMU moving average line
            _buildLineChartBarData(
              imuMovingAvg,
              imuColor,
              2.5,
            ),
            // CPU raw data line
            _buildLineChartBarData(
              cpuData,
              cpuColor.withValues(alpha: 0.3),
              1.5,
            ),
            // CPU moving average line
            _buildLineChartBarData(
              cpuMovingAvg,
              cpuColor,
              2.5,
            ),
          ],
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((spot) {
                  String label;
                  Color color;
                  if (spot.barIndex == 0 || spot.barIndex == 1) {
                    label = 'IMU: ${spot.y.toStringAsFixed(2)}°C';
                    color = imuColor;
                  } else {
                    label = 'CPU: ${spot.y.toStringAsFixed(2)}°C';
                    color = cpuColor;
                  }
                  return LineTooltipItem(
                    label,
                    TextStyle(color: color, fontWeight: FontWeight.bold),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  LineChartBarData _buildLineChartBarData(
    List<double> data,
    Color color,
    double strokeWidth,
  ) {
    return LineChartBarData(
      spots: data
          .asMap()
          .entries
          .map((e) => FlSpot(e.key.toDouble(), e.value))
          .toList(),
      isCurved: true,
      color: color,
      barWidth: strokeWidth,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  double _computeMin() {
    final allValues = [...imuData, ...cpuData];
    if (allValues.isEmpty) return graphMin;
    final min = allValues.reduce((a, b) => a < b ? a : b);
    return (min - 2).floorToDouble();
  }

  double _computeMax() {
    final allValues = [...imuData, ...cpuData];
    if (allValues.isEmpty) return graphMax;
    final max = allValues.reduce((a, b) => a > b ? a : b);
    return (max + 2).ceilToDouble();
  }
}

