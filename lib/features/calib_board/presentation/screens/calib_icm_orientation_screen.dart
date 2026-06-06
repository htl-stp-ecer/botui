import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/calib_board/application/calib_board_providers.dart';
import 'package:stpvelox/features/calib_board/presentation/widgets/value_chip.dart';
import 'package:stpvelox/features/calib_board/presentation/widgets/triaxial_chart.dart';

/// 3D Orientation aus dem Madgwick-Filter im Firmware.  Drei Live-
/// Visualisierungen kombiniert:
///   - Roll/Pitch/Yaw als große Zahlen + Bullauge-Indikator (horizon)
///   - Roll+Pitch History-Chart (gleichzeitig X+Y)
///   - Quaternion-Komponenten als Live-Zeile (Diagnose)
///
/// 800×480 → wir sind kompakt, ein Plot reicht.
class CalibIcmOrientationScreen extends HookConsumerWidget {
  const CalibIcmOrientationScreen({super.key});

  static const _maxPoints = 250;
  static const _sampleInterval = Duration(milliseconds: 20);  // 50 Hz UI

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rollAsync  = ref.watch(calibIcmEulerRollProvider);
    final pitchAsync = ref.watch(calibIcmEulerPitchProvider);
    final yawAsync   = ref.watch(calibIcmEulerYawProvider);
    final qw         = ref.watch(calibIcmQuatWProvider).value ?? 1.0;
    final qx         = ref.watch(calibIcmQuatXProvider).value ?? 0.0;
    final qy         = ref.watch(calibIcmQuatYProvider).value ?? 0.0;
    final qz         = ref.watch(calibIcmQuatZProvider).value ?? 0.0;

    final lastRoll  = useState<double?>(null);
    final lastPitch = useState<double?>(null);
    final lastYaw   = useState<double?>(null);
    rollAsync .whenData((v) => lastRoll .value = v);
    pitchAsync.whenData((v) => lastPitch.value = v);
    yawAsync  .whenData((v) => lastYaw  .value = v);

    final rollHist  = useState<List<double>>([]);
    final pitchHist = useState<List<double>>([]);
    final yawHist   = useState<List<double>>([]);
    useEffect(() {
      final t = Timer.periodic(_sampleInterval, (_) {
        final r = lastRoll.value;
        final p = lastPitch.value;
        final y = lastYaw.value;
        if (r == null || p == null || y == null) return;
        rollHist .value = _push(rollHist .value, r);
        pitchHist.value = _push(pitchHist.value, p);
        yawHist  .value = _push(yawHist  .value, y);
      });
      return t.cancel;
    }, const []);

    return Scaffold(
      appBar: createTopBar(context, 'Orientation'),
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Row(
                children: [
                  ValueChip(
                    label: 'Roll',
                    value: _fmt(lastRoll.value),
                    sub: '°',
                    accent: const Color(0xFFEF5350),
                  ),
                  ValueChip(
                    label: 'Pitch',
                    value: _fmt(lastPitch.value),
                    sub: '°',
                    accent: const Color(0xFF66BB6A),
                  ),
                  ValueChip(
                    label: 'Yaw',
                    value: _fmt(lastYaw.value),
                    sub: '°',
                    accent: const Color(0xFF42A5F5),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 140,
                child: _HorizonIndicator(
                  roll: lastRoll.value ?? 0,
                  pitch: lastPitch.value ?? 0,
                  yaw: lastYaw.value ?? 0,
                ),
              ),
              const SizedBox(height: 6),
              _QuatRow(qw: qw, qx: qx, qy: qy, qz: qz),
              const SizedBox(height: 6),
              Expanded(
                child: TriaxialChart(
                  x: rollHist.value, y: pitchHist.value, z: yawHist.value,
                  minY: -180, maxY: 180,
                  unitLabel: 'roll / pitch / yaw [°]',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static List<double> _push(List<double> buf, double v) {
    final next = List<double>.from(buf)..add(v);
    if (next.length > _maxPoints) {
      next.removeRange(0, next.length - _maxPoints);
    }
    return next;
  }

  static String _fmt(double? v) => v == null ? '—' : v.toStringAsFixed(1);
}

class _QuatRow extends StatelessWidget {
  final double qw, qx, qy, qz;
  const _QuatRow({required this.qw, required this.qx, required this.qy, required this.qz});

  String _f(double v) {
    final s = v.toStringAsFixed(3);
    return v >= 0 ? '+$s' : s;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Text('quat',
              style: TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'w ${_f(qw)}   x ${_f(qx)}   y ${_f(qy)}   z ${_f(qz)}',
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HorizonIndicator extends StatelessWidget {
  final double roll;   // °
  final double pitch;  // °
  final double yaw;    // °

  const _HorizonIndicator({
    required this.roll,
    required this.pitch,
    required this.yaw,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _HorizonPainter(
                  roll: roll * math.pi / 180.0,
                  pitch: pitch,
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: _Compass(yaw: yaw),
            ),
          ],
        ),
      ),
    );
  }
}

class _HorizonPainter extends CustomPainter {
  final double roll;   // rad
  final double pitch;  // °
  _HorizonPainter({required this.roll, required this.pitch});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(-roll);

    // Pitch in Pixel umrechnen — 90° = halbe Höhe.
    final pitchPx = (pitch / 90.0) * (size.height / 2);

    // Himmel oben, Boden unten — auf Pitch verschoben.
    final extent = math.max(size.width, size.height) * 2;
    final skyRect = Rect.fromCenter(
      center: Offset(0, -extent / 2 + pitchPx),
      width: extent, height: extent,
    );
    final groundRect = Rect.fromCenter(
      center: Offset(0, extent / 2 + pitchPx),
      width: extent, height: extent,
    );
    final skyPaint = Paint()..color = const Color(0xFF1E3A5F);
    final groundPaint = Paint()..color = const Color(0xFF5D4037);
    canvas.drawRect(skyRect, skyPaint);
    canvas.drawRect(groundRect, groundPaint);

    // Horizont-Linie
    final horizonPaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 2;
    canvas.drawLine(Offset(-extent / 2, pitchPx),
                     Offset(extent / 2, pitchPx), horizonPaint);

    // Pitch-Skala alle 10°
    final tickPaint = Paint()..color = Colors.white54..strokeWidth = 1;
    for (var deg = -60; deg <= 60; deg += 10) {
      if (deg == 0) continue;
      final y = pitchPx - (deg / 90.0) * (size.height / 2);
      final w = deg.abs() % 20 == 0 ? 30.0 : 16.0;
      canvas.drawLine(Offset(-w / 2, y), Offset(w / 2, y), tickPaint);
    }

    canvas.restore();

    // Festes Center-Cross (Aircraft-Symbol)
    final aircraft = Paint()
      ..color = const Color(0xFFFFB74D)
      ..strokeWidth = 3;
    canvas.drawLine(Offset(cx - 40, cy), Offset(cx - 12, cy), aircraft);
    canvas.drawLine(Offset(cx + 12, cy), Offset(cx + 40, cy), aircraft);
    canvas.drawCircle(Offset(cx, cy), 3, aircraft);
  }

  @override
  bool shouldRepaint(_HorizonPainter old) =>
      old.roll != roll || old.pitch != pitch;
}

class _Compass extends StatelessWidget {
  final double yaw;
  const _Compass({required this.yaw});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60, height: 60,
      decoration: BoxDecoration(
        color: Colors.black54,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: CustomPaint(
        painter: _CompassPainter(yaw: yaw * math.pi / 180),
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  final double yaw;  // rad
  _CompassPainter({required this.yaw});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 4;
    final p = Paint()..color = const Color(0xFFEF5350)..strokeWidth = 2;

    // Pfeil zeigt nach (yaw=0 → Norden = oben)
    final tip = Offset(
      c.dx + r * math.sin(yaw),
      c.dy - r * math.cos(yaw),
    );
    canvas.drawLine(c, tip, p);
    canvas.drawCircle(tip, 3, p);

    final n = TextPainter(
      text: const TextSpan(text: 'N',
          style: TextStyle(color: Colors.white70, fontSize: 10)),
      textDirection: TextDirection.ltr,
    )..layout();
    n.paint(canvas, Offset(c.dx - n.width / 2, 2));
  }

  @override
  bool shouldRepaint(_CompassPainter old) => old.yaw != yaw;
}
