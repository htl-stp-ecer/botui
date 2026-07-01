import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Static chart that displays calibration sample points with horizontal
/// threshold lines.
///
/// Single dataset (`samples`):
/// ```json
/// {
///   "widget": "CalibrationChart",
///   "samples": [120.0, 130.5, ...],
///   "thresholds": [[500, "Black", "grey"], [3200, "White", "amber"]],
///   "height": 200
/// }
/// ```
///
/// Multiple datasets at once (`series`) — one colored line per sensor, with a
/// legend. Takes precedence over `samples` when both are present:
/// ```json
/// {
///   "widget": "CalibrationChart",
///   "series": [
///     {"label": "Port 0", "color": "blue", "samples": [120.0, ...]},
///     {"label": "Port 1", "color": "green", "samples": [140.0, ...]}
///   ],
///   "height": 320
/// }
/// ```
class CalibrationChartWidget extends StatelessWidget {
  final List<double> samples;
  final List<_Threshold> thresholds;
  final List<_Series> series;
  final double height;

  CalibrationChartWidget({
    super.key,
    required List<dynamic> rawSamples,
    required List<dynamic> rawThresholds,
    List<dynamic> rawSeries = const [],
    this.height = 200,
  })  : samples = rawSamples.map((e) => (e as num).toDouble()).toList(),
        thresholds = rawThresholds.map((t) {
          final list = t as List;
          return _Threshold(
            value: (list[0] as num).toDouble(),
            label: list.length > 1 ? list[1] as String : '',
            color: list.length > 2 ? list[2] as String : 'white',
          );
        }).toList(),
        series = rawSeries.map((s) {
          final map = s as Map;
          return _Series(
            label: map['label'] as String? ?? '',
            color: map['color'] as String? ?? 'white',
            samples: (map['samples'] as List? ?? [])
                .map((e) => (e as num).toDouble())
                .toList(),
            blackThreshold: (map['black_threshold'] as num?)?.toDouble(),
            whiteThreshold: (map['white_threshold'] as num?)?.toDouble(),
          );
        }).toList();

  bool get _hasSeries => series.any((s) => s.samples.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    if (!_hasSeries && samples.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('No samples', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final painter = CustomPaint(
      size: Size.infinite,
      painter: _CalibrationChartPainter(
        samples: samples,
        thresholds: thresholds,
        series: series,
      ),
    );

    // Fill the available height when our parent bounds it (e.g. wrapped in an
    // Expanded inside a Column), so the chart shrinks to fit instead of forcing a
    // fixed 320px that overflows shorter screens and clips the lower threshold
    // line off-screen. Fall back to the requested `height` when unbounded (e.g.
    // inside a scroll view).
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounded = constraints.maxHeight.isFinite;

        if (!_hasSeries) {
          return SizedBox(
            height: bounded ? constraints.maxHeight : height,
            child: painter,
          );
        }

        // Legend mapping each series' color to its label.
        final legend = Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              for (final s in series)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _parseColor(s.color),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(_legendLabel(s),
                        style:
                            const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
            ],
          ),
        );

        return Column(
          mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bounded
                ? Expanded(child: painter)
                : SizedBox(height: height, child: painter),
            legend,
          ],
        );
      },
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

class _Series {
  final String label;
  final String color;
  final List<double> samples;
  final double? blackThreshold;
  final double? whiteThreshold;

  const _Series({
    required this.label,
    required this.color,
    required this.samples,
    this.blackThreshold,
    this.whiteThreshold,
  });
}

/// Legend text for a series, appending its black/white thresholds when present.
String _legendLabel(_Series s) {
  final parts = <String>[s.label];
  if (s.blackThreshold != null) parts.add('B ${s.blackThreshold!.toStringAsFixed(0)}');
  if (s.whiteThreshold != null) parts.add('W ${s.whiteThreshold!.toStringAsFixed(0)}');
  return parts.join('  ·  ');
}

Color _parseColor(String name) => switch (name.toLowerCase()) {
      'grey' || 'gray' => Colors.grey.shade400,
      'green' => Colors.green.shade400,
      'amber' => Colors.amber.shade400,
      'orange' => Colors.orange.shade400,
      'red' => Colors.red.shade400,
      'blue' => Colors.blue.shade400,
      'purple' => Colors.purple.shade300,
      'cyan' => Colors.cyan.shade400,
      'pink' => Colors.pink.shade300,
      'teal' => Colors.teal.shade400,
      'lime' => Colors.lime.shade400,
      'indigo' => Colors.indigo.shade300,
      'white' => Colors.white70,
      _ => Colors.white70,
    };

class _CalibrationChartPainter extends CustomPainter {
  final List<double> samples;
  final List<_Threshold> thresholds;
  final List<_Series> series;

  _CalibrationChartPainter({
    required this.samples,
    required this.thresholds,
    this.series = const [],
  });

  bool get _hasSeries => series.any((s) => s.samples.isNotEmpty);

  @override
  void paint(Canvas canvas, Size size) {
    // Gather every value across single samples + series + thresholds so the
    // Y range fits all of them.
    final allValues = <double>[
      ...samples,
      for (final s in series) ...s.samples,
      for (final s in series)
        if (s.blackThreshold != null) s.blackThreshold!,
      for (final s in series)
        if (s.whiteThreshold != null) s.whiteThreshold!,
    ];
    if (allValues.isEmpty) return;

    double minVal = allValues.reduce(math.min);
    double maxVal = allValues.reduce(math.max);
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
    _drawYLabel(canvas, size, yMin, yRange, chartWidth, yMax, 'top');
    _drawYLabel(canvas, size, yMin, yRange, chartWidth, (yMin + yMax) / 2, 'mid');
    _drawYLabel(canvas, size, yMin, yRange, chartWidth, yMin, 'bottom');

    if (_hasSeries) {
      for (final s in series) {
        final color = _parseColor(s.color);
        _drawSeries(canvas, size, s.samples, color, yMin, yRange, chartWidth);
        // Per-sensor black/white thresholds, dashed, in the series' own color.
        for (final value in [s.blackThreshold, s.whiteThreshold]) {
          if (value != null) {
            _drawDashedLine(canvas, size, value, color, yMin, yRange, chartWidth);
          }
        }
      }
    } else {
      _drawSeries(
          canvas, size, samples, Colors.blue.shade300, yMin, yRange, chartWidth);
    }

    // Top-level threshold lines (single-dataset mode)
    for (final t in thresholds) {
      final normalizedY = (t.value - yMin) / yRange;
      final y = size.height * (1 - normalizedY);
      final color = _parseColor(t.color);

      _drawDashedLine(canvas, size, t.value, color, yMin, yRange, chartWidth);

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

  void _drawSeries(Canvas canvas, Size size, List<double> values, Color color,
      double yMin, double yRange, double chartWidth) {
    if (values.isEmpty) return;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final denom = (values.length - 1).clamp(1, double.infinity);
    for (int i = 0; i < values.length; i++) {
      final x = chartWidth * i / denom;
      final normalizedY = (values[i] - yMin) / yRange;
      final y = size.height * (1 - normalizedY);
      canvas.drawCircle(Offset(x, y), 2.5, dotPaint);
    }
  }

  void _drawDashedLine(Canvas canvas, Size size, double value, Color color,
      double yMin, double yRange, double chartWidth) {
    final normalizedY = (value - yMin) / yRange;
    final y = size.height * (1 - normalizedY);

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
  }

  void _drawYLabel(Canvas canvas, Size size, double yMin, double yRange,
      double chartWidth, double value, String pos) {
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
    if (samples.length != oldDelegate.samples.length ||
        thresholds.length != oldDelegate.thresholds.length ||
        series.length != oldDelegate.series.length) {
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
    for (int i = 0; i < series.length; i++) {
      final a = series[i];
      final b = oldDelegate.series[i];
      if (a.label != b.label ||
          a.color != b.color ||
          a.blackThreshold != b.blackThreshold ||
          a.whiteThreshold != b.whiteThreshold ||
          a.samples.length != b.samples.length) {
        return true;
      }
      for (int j = 0; j < a.samples.length; j++) {
        if (a.samples[j] != b.samples[j]) return true;
      }
    }
    return false;
  }
}
