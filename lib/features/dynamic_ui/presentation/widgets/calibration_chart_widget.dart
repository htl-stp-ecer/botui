import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Static chart that displays calibration sample points as dots
/// with horizontal threshold lines.
///
/// JSON shape from Python:
/// ```json
/// {
///   "widget": "CalibrationChart",
///   "samples": [120.0, 130.5, ...],
///   "thresholds": [[500, "Black", "grey"], [3200, "White", "amber"]],
///   "height": 200
/// }
/// ```
class CalibrationChartWidget extends StatelessWidget {
  final List<double> samples;
  final List<_Threshold> thresholds;
  final double height;

  CalibrationChartWidget({
    super.key,
    required List<dynamic> rawSamples,
    required List<dynamic> rawThresholds,
    this.height = 200,
  })  : samples = rawSamples.map((e) => (e as num).toDouble()).toList(),
        thresholds = rawThresholds.map((t) {
          final list = t as List;
          return _Threshold(
            value: (list[0] as num).toDouble(),
            label: list.length > 1 ? list[1] as String : '',
            color: list.length > 2 ? list[2] as String : 'white',
          );
        }).toList();

  @override
  Widget build(BuildContext context) {
    if (samples.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('No samples', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _CalibrationChartPainter(
          samples: samples,
          thresholds: thresholds,
        ),
      ),
    );
  }
}

class _Threshold {
  final double value;
  final String label;
  final String color;

  const _Threshold({
    required this.value,
    required this.label,
    required this.color,
  });
}

Color _parseColor(String name) => switch (name.toLowerCase()) {
      'grey' || 'gray' => Colors.grey.shade400,
      'green' => Colors.green.shade400,
      'amber' => Colors.amber.shade400,
      'orange' => Colors.orange.shade400,
      'red' => Colors.red.shade400,
      'blue' => Colors.blue.shade400,
      'white' => Colors.white70,
      _ => Colors.white70,
    };

class _CalibrationChartPainter extends CustomPainter {
  final List<double> samples;
  final List<_Threshold> thresholds;

  _CalibrationChartPainter({
    required this.samples,
    required this.thresholds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;

    // Compute Y range from samples + thresholds
    double minVal = samples.reduce(math.min);
    double maxVal = samples.reduce(math.max);
    for (final t in thresholds) {
      minVal = math.min(minVal, t.value);
      maxVal = math.max(maxVal, t.value);
    }
    final range = maxVal - minVal;
    final padding = range * 0.08 + 10;
    final yMin = minVal - padding;
    final yMax = maxVal + padding;
    final yRange = yMax - yMin;

    if (yRange < 1) return;

    const double labelMargin = 60; // space for threshold labels on right
    final chartWidth = size.width - labelMargin;

    // Background grid
    final gridPaint = Paint()
      ..color = Colors.grey.shade800
      ..strokeWidth = 0.5;
    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), gridPaint);
    }

    // Y-axis labels (min, mid, max)
    _drawYLabel(canvas, size, yMin, yMax, yRange, chartWidth, yMax, 'top');
    _drawYLabel(canvas, size, yMin, yMax, yRange, chartWidth, (yMin + yMax) / 2, 'mid');
    _drawYLabel(canvas, size, yMin, yMax, yRange, chartWidth, yMin, 'bottom');

    // Sample dots
    final dotPaint = Paint()
      ..color = Colors.blue.shade300
      ..style = PaintingStyle.fill;

    for (int i = 0; i < samples.length; i++) {
      final x = chartWidth * i / (samples.length - 1).clamp(1, double.infinity);
      final normalizedY = (samples[i] - yMin) / yRange;
      final y = size.height * (1 - normalizedY);
      canvas.drawCircle(Offset(x, y), 2.5, dotPaint);
    }

    // Threshold lines
    for (final t in thresholds) {
      final normalizedY = (t.value - yMin) / yRange;
      final y = size.height * (1 - normalizedY);
      final color = _parseColor(t.color);

      // Dashed line
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      const dashWidth = 8.0;
      const gapWidth = 4.0;
      double startX = 0;
      while (startX < chartWidth) {
        final endX = math.min(startX + dashWidth, chartWidth);
        canvas.drawLine(Offset(startX, y), Offset(endX, y), linePaint);
        startX += dashWidth + gapWidth;
      }

      // Label
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${t.label} ${t.value.toStringAsFixed(0)}',
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, Offset(chartWidth + 4, y - textPainter.height / 2));
    }
  }

  void _drawYLabel(Canvas canvas, Size size, double yMin, double yMax,
      double yRange, double chartWidth, double value, String pos) {
    final normalizedY = (value - yMin) / yRange;
    final y = size.height * (1 - normalizedY);

    final textPainter = TextPainter(
      text: TextSpan(
        text: value.toStringAsFixed(0),
        style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    double dy = y - textPainter.height / 2;
    if (pos == 'top') dy = math.max(0, dy);
    if (pos == 'bottom') dy = math.min(size.height - textPainter.height, dy);

    textPainter.paint(canvas, Offset(chartWidth + 4, dy));
  }

  @override
  bool shouldRepaint(_CalibrationChartPainter oldDelegate) {
    if (identical(samples, oldDelegate.samples) &&
        identical(thresholds, oldDelegate.thresholds)) {
      return false;
    }
    if (samples.length != oldDelegate.samples.length ||
        thresholds.length != oldDelegate.thresholds.length) {
      return true;
    }
    for (int i = 0; i < samples.length; i++) {
      if (samples[i] != oldDelegate.samples[i]) return true;
    }
    for (int i = 0; i < thresholds.length; i++) {
      final a = thresholds[i];
      final b = oldDelegate.thresholds[i];
      if (a.value != b.value || a.label != b.label || a.color != b.color) {
        return true;
      }
    }
    return false;
  }
}
