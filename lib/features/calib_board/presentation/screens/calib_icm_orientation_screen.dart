import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/calib_board/application/calib_board_providers.dart';

/// 3D-Orientation aus dem Madgwick-Filter im Firmware — als *eine* klare
/// Anzeige: ein künstlicher Horizont (Attitude Indicator) füllt den
/// Schirm, darunter Roll/Pitch/Yaw als Zahlen.  Kein History-Chart, keine
/// Quaternion-Diagnose — wer das braucht liest die Rohwerte woanders.
class CalibIcmOrientationScreen extends ConsumerWidget {
  const CalibIcmOrientationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roll  = ref.watch(calibIcmEulerRollProvider).value;
    final pitch = ref.watch(calibIcmEulerPitchProvider).value;
    final yaw   = ref.watch(calibIcmEulerYawProvider).value;

    return Scaffold(
      appBar: createTopBar(context, 'Orientation'),
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _HorizonPainter(
                            roll: (roll ?? 0) * math.pi / 180.0,
                            pitch: pitch ?? 0,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 14,
                        top: 14,
                        child: _Compass(yaw: yaw ?? 0),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _AngleReadout(
                      label: 'Roll', value: roll, color: const Color(0xFFEF5350)),
                  _AngleReadout(
                      label: 'Pitch', value: pitch, color: const Color(0xFF66BB6A)),
                  _AngleReadout(
                      label: 'Yaw', value: yaw, color: const Color(0xFF42A5F5)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AngleReadout extends StatelessWidget {
  final String label;
  final double? value;
  final Color color;
  const _AngleReadout(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 2),
            Text(
              value == null ? '—' : '${value!.toStringAsFixed(1)}°',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
              ),
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

    final extent = math.max(size.width, size.height) * 2;
    final skyRect = Rect.fromCenter(
      center: Offset(0, -extent / 2 + pitchPx),
      width: extent, height: extent,
    );
    final groundRect = Rect.fromCenter(
      center: Offset(0, extent / 2 + pitchPx),
      width: extent, height: extent,
    );
    canvas.drawRect(skyRect, Paint()..color = const Color(0xFF1E3A5F));
    canvas.drawRect(groundRect, Paint()..color = const Color(0xFF5D4037));

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
      final w = deg.abs() % 20 == 0 ? 40.0 : 20.0;
      canvas.drawLine(Offset(-w / 2, y), Offset(w / 2, y), tickPaint);
    }

    canvas.restore();

    // Festes Aircraft-Symbol in der Mitte
    final aircraft = Paint()
      ..color = const Color(0xFFFFB74D)
      ..strokeWidth = 3;
    canvas.drawLine(Offset(cx - 48, cy), Offset(cx - 14, cy), aircraft);
    canvas.drawLine(Offset(cx + 14, cy), Offset(cx + 48, cy), aircraft);
    canvas.drawCircle(Offset(cx, cy), 4, aircraft);
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
      width: 72, height: 72,
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
    final r = size.width / 2 - 5;
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
          style: TextStyle(color: Colors.white70, fontSize: 11)),
      textDirection: TextDirection.ltr,
    )..layout();
    n.paint(canvas, Offset(c.dx - n.width / 2, 2));
  }

  @override
  bool shouldRepaint(_CompassPainter old) => old.yaw != yaw;
}
