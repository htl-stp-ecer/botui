import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class AnimatedRobotWidget extends HookWidget {
  final bool moving;
  final double size;

  const AnimatedRobotWidget({
    super.key,
    required this.moving,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    final wheelController = useAnimationController(
      duration: const Duration(milliseconds: 500),
    );

    final bounceController = useAnimationController(
      duration: const Duration(milliseconds: 200),
    );

    useEffect(() {
      if (moving) {
        wheelController.repeat();
        bounceController.repeat(reverse: true);
      } else {
        wheelController.stop();
        bounceController.stop();
      }
      return null;
    }, [moving]);

    final bounceAnimation = useAnimation(
      Tween<double>(begin: 0, end: 3).animate(
        CurvedAnimation(parent: bounceController, curve: Curves.easeInOut),
      ),
    );

    return Transform.translate(
      offset: Offset(0, moving ? bounceAnimation : 0),
      child: SizedBox(
        width: size,
        height: size * 0.7,
        child: CustomPaint(
          painter: _RobotPainter(
            wheelRotation: wheelController,
            isMoving: moving,
          ),
        ),
      ),
    );
  }
}

class _RobotPainter extends CustomPainter {
  final Animation<double> wheelRotation;
  final bool isMoving;

  _RobotPainter({
    required this.wheelRotation,
    required this.isMoving,
  }) : super(repaint: wheelRotation);

  @override
  void paint(Canvas canvas, Size size) {
    final bodyPaint = Paint()
      ..color = Colors.blueGrey.shade700
      ..style = PaintingStyle.fill;

    final accentPaint = Paint()
      ..color = Colors.blue.shade400
      ..style = PaintingStyle.fill;

    final wheelPaint = Paint()
      ..color = Colors.grey.shade800
      ..style = PaintingStyle.fill;

    final wheelDetailPaint = Paint()
      ..color = Colors.grey.shade600
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final glowPaint = Paint()
      ..color = isMoving ? Colors.green.withOpacity(0.6) : Colors.blue.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    // Robot body
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.15, size.height * 0.1, size.width * 0.7, size.height * 0.5),
      const Radius.circular(8),
    );

    // Glow effect
    canvas.drawRRect(bodyRect, glowPaint);
    canvas.drawRRect(bodyRect, bodyPaint);

    // Robot "face" / sensor area
    final faceRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.25, size.height * 0.15, size.width * 0.5, size.height * 0.2),
      const Radius.circular(4),
    );
    canvas.drawRRect(faceRect, accentPaint);

    // LED indicators
    final ledPaint = Paint()
      ..color = isMoving ? Colors.green : Colors.blue
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(Offset(size.width * 0.35, size.height * 0.25), 4, ledPaint);
    canvas.drawCircle(Offset(size.width * 0.65, size.height * 0.25), 4, ledPaint);

    // Wheels
    final wheelRadius = size.width * 0.12;
    final wheelY = size.height * 0.7;
    final leftWheelX = size.width * 0.25;
    final rightWheelX = size.width * 0.75;

    // Draw wheels with rotation
    _drawWheel(canvas, Offset(leftWheelX, wheelY), wheelRadius, wheelPaint, wheelDetailPaint);
    _drawWheel(canvas, Offset(rightWheelX, wheelY), wheelRadius, wheelPaint, wheelDetailPaint);
  }

  void _drawWheel(Canvas canvas, Offset center, double radius, Paint fillPaint, Paint detailPaint) {
    canvas.drawCircle(center, radius, fillPaint);

    // Wheel spokes that rotate
    final rotation = wheelRotation.value * 2 * math.pi;
    for (int i = 0; i < 4; i++) {
      final angle = rotation + (i * math.pi / 2);
      final spokeEnd = Offset(
        center.dx + radius * 0.7 * math.cos(angle),
        center.dy + radius * 0.7 * math.sin(angle),
      );
      canvas.drawLine(center, spokeEnd, detailPaint);
    }

    // Center hub
    canvas.drawCircle(center, radius * 0.25, Paint()..color = Colors.grey.shade500);
  }

  @override
  bool shouldRepaint(_RobotPainter oldDelegate) =>
      // While moving, repaint is driven by `super(repaint: wheelRotation)` on
      // every controller tick, so we don't need to force it here. When the
      // robot is idle (e.g. the Distance Calibration screen) returning `true`
      // made this CustomPaint re-rasterize on EVERY frame for no visual
      // change — sustained per-frame repaint on the Pi 3 VC4 GPU. Only repaint
      // when the moving state actually flips.
      oldDelegate.isMoving != isMoving;
}
