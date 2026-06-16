import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/calib_board/application/calib_board_providers.dart';
import 'package:stpvelox/features/calib_board/presentation/widgets/value_chip.dart';

/// Fusionierte Pose (PAA-cm rotated by Quaternion → integriert in World-
/// Frame).  2D-Plot zeigt den gefahrenen Pfad + Heading-Pfeil an der
/// aktuellen Position.  Reset nullt sowohl die Bridge-interne PAA-
/// Position als auch die Odometrie-Pose.
class CalibOdometryScreen extends HookConsumerWidget {
  const CalibOdometryScreen({super.key});

  static const _maxPoints = 800;
  static const _sampleInterval = Duration(milliseconds: 33);  // 30 Hz UI

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posX = ref.watch(calibOdomPosXProvider).value;
    final posY = ref.watch(calibOdomPosYProvider).value;
    final hdg  = ref.watch(calibOdomHeadingProvider).value;

    final path = useState<List<Offset>>(const [Offset.zero]);

    useEffect(() {
      final t = Timer.periodic(_sampleInterval, (_) {
        if (posX == null || posY == null) return;
        final next = List<Offset>.from(path.value)..add(Offset(posX, posY));
        if (next.length > _maxPoints) {
          next.removeRange(0, next.length - _maxPoints);
        }
        path.value = next;
      });
      return t.cancel;
    }, [posX, posY]);

    void reset() {
      ref.read(calibCommandPublisherProvider).sendOdomReset();
      ref.read(calibCommandPublisherProvider).sendResetPosition();
      path.value = const [Offset.zero];
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pose reset')),
      );
    }

    return Scaffold(
      appBar: createTopBar(
        context,
        'Odometry',
        actions: [
          IconButton(
            tooltip: 'Reset pose',
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
                    value: posX?.toStringAsFixed(2) ?? '—',
                    sub: 'cm world',
                  ),
                  ValueChip(
                    label: 'Y',
                    value: posY?.toStringAsFixed(2) ?? '—',
                    sub: 'cm world',
                  ),
                  ValueChip(
                    label: 'Heading',
                    value: hdg?.toStringAsFixed(1) ?? '—',
                    sub: '° (yaw)',
                  ),
                  ValueChip(
                    label: '‖p‖',
                    value: (posX == null || posY == null)
                        ? '—'
                        : math.sqrt(posX * posX + posY * posY).toStringAsFixed(2),
                    sub: 'cm',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _PosePlot(
                  path: path.value,
                  currentX: posX ?? 0,
                  currentY: posY ?? 0,
                  headingDeg: hdg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PosePlot extends StatelessWidget {
  final List<Offset> path;
  final double currentX;
  final double currentY;
  final double? headingDeg;

  const _PosePlot({
    required this.path,
    required this.currentX,
    required this.currentY,
    required this.headingDeg,
  });

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) {
      return const Center(
        child: Text('waiting for pose…',
            style: TextStyle(color: Colors.white60)),
      );
    }

    // Autoscale mit Padding — mindestens ±20 cm um Zentrum bei Stillstand.
    double minX = currentX, maxX = currentX, minY = currentY, maxY = currentY;
    for (final p in path) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    final padX = math.max((maxX - minX) * 0.15, 20.0);
    final padY = math.max((maxY - minY) * 0.15, 20.0);
    minX -= padX; maxX += padX; minY -= padY; maxY += padY;

    // Quadrate halten (kein verzerrtes Aspect-Ratio).
    final rangeX = maxX - minX;
    final rangeY = maxY - minY;
    if (rangeX > rangeY) {
      final extra = (rangeX - rangeY) / 2;
      minY -= extra; maxY += extra;
    } else {
      final extra = (rangeY - rangeX) / 2;
      minX -= extra; maxX += extra;
    }

    return Stack(
      children: [
        Positioned.fill(
          child: LineChart(
            duration: Duration.zero,
            LineChartData(
              clipData: const FlClipData.all(),
              minX: minX, maxX: maxX, minY: minY, maxY: maxY,
              gridData: const FlGridData(show: true),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (v, _) => Text(
                      v.toStringAsFixed(0),
                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (v, _) => Text(
                      v.toStringAsFixed(0),
                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ),
                ),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.white24),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: path.map((p) => FlSpot(p.dx, p.dy)).toList(),
                  isCurved: false,
                  color: const Color(0xFF26C6DA),
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
        // Heading-Pfeil als Overlay an aktueller Position
        Positioned.fill(
          child: LayoutBuilder(
            builder: (_, c) {
              final px = (currentX - minX) / (maxX - minX) * c.maxWidth;
              final py = (1 - (currentY - minY) / (maxY - minY)) * c.maxHeight;
              return CustomPaint(
                painter: _HeadingMarker(
                  pos: Offset(px, py),
                  headingRad: headingDeg == null
                      ? null
                      : headingDeg! * math.pi / 180,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HeadingMarker extends CustomPainter {
  final Offset pos;
  final double? headingRad;
  _HeadingMarker({required this.pos, required this.headingRad});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFFFB74D)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, 5, p);

    // Ohne gültiges Heading nur die Position markieren, keinen Pfeil.
    final headingRad = this.headingRad;
    if (headingRad == null) return;

    final arrowLen = 22.0;
    final tip = Offset(
      pos.dx + arrowLen * math.cos(headingRad),
      pos.dy - arrowLen * math.sin(headingRad),  // canvas Y nach unten
    );
    canvas.drawLine(pos, tip, p..strokeWidth = 3..style = PaintingStyle.stroke);

    // Pfeilkopf
    final headSize = 7.0;
    final left = Offset(
      tip.dx - headSize * math.cos(headingRad - math.pi / 6),
      tip.dy + headSize * math.sin(headingRad - math.pi / 6),
    );
    final right = Offset(
      tip.dx - headSize * math.cos(headingRad + math.pi / 6),
      tip.dy + headSize * math.sin(headingRad + math.pi / 6),
    );
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(path, p..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_HeadingMarker old) =>
      old.pos != pos || old.headingRad != headingRad;
}
