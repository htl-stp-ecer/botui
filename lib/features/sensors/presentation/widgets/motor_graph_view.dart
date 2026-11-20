import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/application/theme/color_theme_provider.dart';
import 'package:stpvelox/core/theme/app_theme.dart';

enum MotorGraphMode { bemf, position }

/// BEMF / POSITION switch of the graph, made for the top bar (see
/// `createTopBar(center: ...)`): 280 px wide, no border, theme colored.
class MotorGraphModeToggle extends ConsumerWidget {
  final MotorGraphMode mode;
  final ValueChanged<MotorGraphMode> onChanged;

  const MotorGraphModeToggle({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(colorThemeProvider);
    final accent = theme.tileColor(TileColor.blue, null);

    Widget button(MotorGraphMode m, String label, BorderRadius radius) {
      final active = mode == m;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(m),
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? accent : Colors.grey[850],
              borderRadius: radius,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: active ? theme.textColor : Colors.grey[500],
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 280,
      child: Row(
        children: [
          button(MotorGraphMode.bemf, 'BEMF',
              const BorderRadius.horizontal(left: Radius.circular(8))),
          button(MotorGraphMode.position, 'POSITION',
              const BorderRadius.horizontal(right: Radius.circular(8))),
        ],
      ),
    );
  }
}

class MotorGraphView extends ConsumerWidget {
  /// Raw instantaneous BEMF readings (filtered, not accumulated).
  final List<double> bemfData;

  /// Moving average of BEMF data.
  final List<double> movingAvg;

  /// Accumulated motor position over time.
  final List<double> positionData;

  /// Target velocity time-series (shown on BEMF graph).
  final List<double> targetVelocity;

  final int maxPoints;

  /// Total number of samples received (used for X axis scrolling).
  final int totalSamples;

  /// Current graph mode, managed by parent so it persists across tab switches.
  final MotorGraphMode mode;

  const MotorGraphView({
    super.key,
    required this.bemfData,
    required this.movingAvg,
    required this.positionData,
    required this.targetVelocity,
    required this.maxPoints,
    required this.totalSamples,
    required this.mode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(colorThemeProvider);
    // Raw = series 0, Avg = 1, Target = 2 (pattern themes: pattern[i]).
    final c = _CurveColors(
      raw: theme.tileColor(TileColor.blue, 0),
      avg: theme.tileColor(TileColor.orange, 1),
      target: theme.tileColor(TileColor.green, 2),
    );
    return Column(
      children: [
        // Legend (the BEMF / POSITION toggle lives in the top bar)
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 12, 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: _buildLegend(c),
          ),
        ),
        // Chart
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 12, 4),
            child: _buildChart(c),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildLegend(_CurveColors c) {
    if (mode == MotorGraphMode.bemf) {
      return [
        _LegendDot(color: c.raw, label: 'Raw'),
        const SizedBox(width: 8),
        _LegendDot(color: c.avg, label: 'Avg'),
        const SizedBox(width: 8),
        _LegendDot(color: c.target, label: 'Target', dashed: true),
      ];
    } else {
      return [
        _LegendDot(color: c.raw, label: 'Position'),
      ];
    }
  }

  Widget _buildChart(_CurveColors c) {
    final dataToCheck = mode == MotorGraphMode.bemf ? bemfData : positionData;
    if (dataToCheck.isEmpty) {
      return Center(
        child: Text('Waiting for data...',
            style: TextStyle(color: Colors.grey[600], fontSize: 16)),
      );
    }

    final List<LineChartBarData> lines;
    final double minY, maxY;
    final double maxX = totalSamples.toDouble();
    final double minX = (totalSamples - maxPoints).toDouble();

    if (mode == MotorGraphMode.bemf) {
      final allVals = bemfData.toList();
      for (final v in targetVelocity) {
        if (!v.isNaN) allVals.add(v);
      }
      final (lo, hi) = _autoRange(allVals);
      minY = lo;
      maxY = hi;
      lines = _bemfLines(c);
    } else {
      final (lo, hi) = _autoRange(positionData);
      minY = lo;
      maxY = hi;
      lines = _positionLines(c);
    }

    return RepaintBoundary(
      child: LineChart(
        duration: Duration.zero,
        LineChartData(
          clipData: const FlClipData.all(),
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            horizontalInterval: max(1, (maxY - minY) / 4),
            verticalInterval: 50,
            getDrawingHorizontalLine: (_) => FlLine(
                color: Colors.grey.withValues(alpha: 0.2), strokeWidth: 1),
            getDrawingVerticalLine: (_) => FlLine(
                color: Colors.grey.withValues(alpha: 0.1), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: max(1, (maxY - minY) / 4),
                getTitlesWidget: (v, _) => Text(
                  v.toStringAsFixed(0),
                  style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 10,
                      fontFamily: 'monospace'),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 18,
                interval: 50,
                getTitlesWidget: (v, _) {
                  if (v.toInt() % 50 == 0) {
                    return Text(
                      '${(v / 50).toStringAsFixed(0)}s',
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 10),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              left: BorderSide(color: Colors.grey[700]!),
              bottom: BorderSide(color: Colors.grey[700]!),
              right: const BorderSide(color: Colors.transparent),
              top: const BorderSide(color: Colors.transparent),
            ),
          ),
          lineBarsData: lines,
          lineTouchData: const LineTouchData(enabled: false),
        ),
      ),
    );
  }

  List<LineChartBarData> _bemfLines(_CurveColors c) {
    final xStart = totalSamples - bemfData.length;
    final rawSpots = List<FlSpot>.generate(
        bemfData.length, (i) => FlSpot((xStart + i).toDouble(), bemfData[i]));
    final maStart = totalSamples - movingAvg.length;
    final maSpots = List<FlSpot>.generate(movingAvg.length,
        (i) => FlSpot((maStart + i).toDouble(), movingAvg[i]));

    final tStart = totalSamples - targetVelocity.length;
    final targetSpots = <FlSpot>[];
    for (int i = 0; i < targetVelocity.length; i++) {
      if (!targetVelocity[i].isNaN) {
        targetSpots.add(FlSpot((tStart + i).toDouble(), targetVelocity[i]));
      }
    }

    return [
      LineChartBarData(
        spots: rawSpots,
        isCurved: false,
        color: c.raw,
        barWidth: 2,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
            show: true, color: c.raw.withValues(alpha: 0.1)),
      ),
      if (maSpots.isNotEmpty)
        LineChartBarData(
          spots: maSpots,
          isCurved: false,
          color: c.avg,
          barWidth: 2,
          dotData: const FlDotData(show: false),
        ),
      if (targetSpots.isNotEmpty)
        LineChartBarData(
          spots: targetSpots,
          isCurved: false,
          color: c.target,
          barWidth: 2,
          dashArray: [6, 4],
          dotData: const FlDotData(show: false),
        ),
    ];
  }

  List<LineChartBarData> _positionLines(_CurveColors c) {
    final xStart = totalSamples - positionData.length;
    final posSpots = List<FlSpot>.generate(positionData.length,
        (i) => FlSpot((xStart + i).toDouble(), positionData[i]));
    return [
      LineChartBarData(
        spots: posSpots,
        isCurved: false,
        color: c.raw,
        barWidth: 2,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
            show: true, color: c.raw.withValues(alpha: 0.1)),
      ),
    ];
  }

  (double, double) _autoRange(List<double> values) {
    if (values.isEmpty) return (-1, 1);
    final vals = values.where((v) => !v.isNaN).toList();
    if (vals.isEmpty) return (-1, 1);
    final lo = vals.reduce((a, b) => a < b ? a : b);
    final hi = vals.reduce((a, b) => a > b ? a : b);
    double pad = (hi - lo).abs() * 0.1;
    if (pad == 0) pad = (hi == 0 ? 1.0 : hi.abs() * 0.1);
    return (lo - pad, hi + pad);
  }
}

// ─── Small helper widgets ────────────────────────────────────

/// Theme colors of the three curves, resolved once per build.
class _CurveColors {
  final Color raw;
  final Color avg;
  final Color target;
  const _CurveColors(
      {required this.raw, required this.avg, required this.target});
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;
  const _LegendDot(
      {required this.color, required this.label, this.dashed = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: dashed ? Colors.transparent : color,
            border: dashed ? Border.all(color: color, width: 1) : null,
          ),
        ),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey[500])),
      ],
    );
  }
}
