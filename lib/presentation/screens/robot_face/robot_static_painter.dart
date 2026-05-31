import 'package:flutter/material.dart';
import 'package:stpvelox/core/utils/colors/robot_color_scheme.dart';
import 'package:stpvelox/core/utils/robot_personality.dart';
import 'robot_cosmetics_painter.dart';
import 'robot_expressions.dart';

/// Paints the parts of the robot face that do NOT depend on per-frame
/// animation (blink, gaze, expression effects): background + personality
/// cosmetics. Combined with a [RepaintBoundary], this layer is rasterised
/// once per `colorScheme`/`personality` change instead of every animation
/// tick — eliminating the dominant per-frame cost (full-canvas redraw of
/// blurred cosmetics) on Pi 3's VC4 GPU.
class RobotStaticPainter extends CustomPainter {
  final RobotColorScheme colorScheme;
  final RobotPersonality? personality;

  const RobotStaticPainter({
    required this.colorScheme,
    required this.personality,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..color = RobotFaceConstants.screenColor
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);

    if (personality != null) {
      RobotCosmeticsPainter.drawCosmetics(
        canvas,
        size,
        personality!,
        colorScheme.eyeColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RobotStaticPainter oldDelegate) {
    return oldDelegate.colorScheme != colorScheme ||
        oldDelegate.personality != personality;
  }
}
