import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/features/sensors/presentation/utils/sensor_strategy_factory.dart';
import 'package:stpvelox/features/sensors/domain/entities/sensor_type.dart';

class SensorGraphWidget extends HookConsumerWidget {
  static const Duration sampleInterval = Duration(milliseconds: 50);

  final int port;
  final String sensorType;
  final int maxPoints;
  final WidgetRef ref;

  const SensorGraphWidget({
    super.key,
    required this.port,
    this.sensorType = 'analog',
    this.maxPoints = 50,
    required this.ref,
  });

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final type = sensorType == 'digital' ? SensorType.digital : SensorType.analog;
    final strategy = SensorStrategyFactory.createStrategy(type);
    final reading = strategy.readValue(widgetRef, port) ?? 0.0;

    final history = useState<List<double>>([]);

    // The reader publishes a value only while it changes, so the graph is driven
    // by a timer that appends the latest reading. It keeps scrolling while the
    // value is stable.
    final latest = useRef<double>(reading);
    latest.value = reading;

    useEffect(() {
      final timer = Timer.periodic(sampleInterval, (_) {
        final newHistory = [...history.value, latest.value];
        if (newHistory.length > maxPoints) {
          newHistory.removeAt(0);
        }
        history.value = newHistory;
      });
      return timer.cancel;
    }, const []);

    return SizedBox(
      height: 120,
      child: CustomPaint(
        size: Size.infinite,
        painter: _SensorGraphPainter(history: history.value),
      ),
    );
  }
}

class _SensorGraphPainter extends CustomPainter {
  final List<double> history;

  _SensorGraphPainter({required this.history});

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;

    final minVal = history.reduce(math.min);
    final maxVal = history.reduce(math.max);
    final range = maxVal - minVal;
    final padding = range * 0.1 + 1;
    final effectiveMin = minVal - padding;
    final effectiveMax = maxVal + padding;
    final effectiveRange = effectiveMax - effectiveMin;

    if (effectiveRange < 1) return;

    // Grid
    final gridPaint = Paint()
      ..color = Colors.grey.shade800
      ..strokeWidth = 0.5;

    for (int i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Line
    final linePaint = Paint()
      ..color = Colors.blue.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.blue.shade400.withOpacity(0.3),
          Colors.blue.shade400.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < history.length; i++) {
      final x = size.width * i / (history.length - 1).clamp(1, double.infinity);
      final normalizedY = (history[i] - effectiveMin) / effectiveRange;
      final y = size.height * (1 - normalizedY);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // Current dot
    if (history.isNotEmpty) {
      final lastNormalizedY = (history.last - effectiveMin) / effectiveRange;
      final lastY = size.height * (1 - lastNormalizedY);
      canvas.drawCircle(
        Offset(size.width, lastY),
        4,
        Paint()..color = Colors.blue.shade300,
      );
    }
  }

  @override
  bool shouldRepaint(_SensorGraphPainter oldDelegate) => true;
}
