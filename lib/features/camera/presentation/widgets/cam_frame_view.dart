import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:raccoon_transport/raccoon_transport.dart';
import 'package:stpvelox/features/camera/application/cam_provider.dart';
import 'package:stpvelox/features/camera/presentation/widgets/uncached_memory_image.dart';

/// One camera frame (JPEG) with the detections drawn over it. Shared by the
/// camera viewer and the preview in the camera menu.
class CamFrameView extends StatefulWidget {
  final CamFrameData frame;
  final CamDetectionData? detections;

  /// Where the picture sits if its shape is not the box's.
  final Alignment alignment;

  /// How the picture fills the box: [BoxFit.contain] shows all of it, [BoxFit.cover] fills the box.
  final BoxFit fit;

  /// Draw the detections over the picture.
  final bool showDetections;

  const CamFrameView({
    super.key,
    required this.frame,
    this.detections,
    this.alignment = Alignment.center,
    this.fit = BoxFit.contain,
    this.showDetections = true,
  });

  @override
  State<CamFrameView> createState() => _CamFrameViewState();
}

class _CamFrameViewState extends State<CamFrameView> {
  Uint8List? _cachedBytes;
  int _cachedTimestamp = 0;

  Uint8List? get _imageData {
    final f = widget.frame.data;
    if (f.frame_size == 0 || f.frame_data.isEmpty) return null;
    if (f.timestamp == _cachedTimestamp && _cachedBytes != null) {
      return _cachedBytes;
    }
    final raw = f.frame_data;
    final bytes = raw is Uint8List ? raw : Uint8List.fromList(raw);
    _cachedBytes = bytes;
    _cachedTimestamp = f.timestamp;
    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    final imageData = _imageData;
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    if (imageData == null) {
      return const Center(
        child: Text(
          'No frame data',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    // The detections come on their own channel (frame_id names the frame they
    // belong to). The latest ones are drawn over the latest frame: they can be a
    // frame behind when the processor is slower than the camera.
    final allDetections =
        widget.detections?.data.detections ?? const <CamBlobT>[];

    return Stack(
      children: [
        // Fill the box: given only its own size, a small picture (320x240) stays
        // small and floats in the middle of the box.
        Positioned.fill(
          child: LayoutBuilder(
          builder: (context, constraints) => UncachedMemoryImage(
            bytes: imageData,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            alignment: widget.alignment,
            fit: widget.fit,
            filterQuality: FilterQuality.low,
            cacheWidth: (constraints.maxWidth * devicePixelRatio)
                .round()
                .clamp(1, widget.frame.data.frame_width),
            cacheHeight: (constraints.maxHeight * devicePixelRatio)
                .round()
                .clamp(1, widget.frame.data.frame_height),
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, color: Colors.white38, size: 48),
                    SizedBox(height: 8),
                    Text(
                      'Failed to decode image',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              );
            },
          ),
          ),
        ),
        if (widget.showDetections)
          Positioned.fill(
            child: CustomPaint(
              painter: CamBoundingBoxPainter(
                detections: allDetections,
                frameWidth: widget.frame.data.frame_width,
                frameHeight: widget.frame.data.frame_height,
                fit: widget.fit,
                alignment: widget.alignment,
              ),
            ),
          ),
      ],
    );
  }
}

/// Draws the detections over a picture that is shown with [fit] and [alignment] in a box.
///
/// A detection (raccoon-cam) has its centre `x`, `y` and its size `width`, `height` as fractions of the
/// frame, 0 to 1. They are placed on the picture as it is shown, not on the box: with
/// [BoxFit.contain] there are bars beside it, with [BoxFit.cover] part of it is cut off.
class CamBoundingBoxPainter extends CustomPainter {
  final List<CamBlobT> detections;
  final int frameWidth;
  final int frameHeight;
  final BoxFit fit;
  final Alignment alignment;

  CamBoundingBoxPainter({
    required this.detections,
    required this.frameWidth,
    required this.frameHeight,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
  });

  /// Where the picture of [frame] size is, when it is shown in a box of [box] size.
  static Rect pictureRect(Size frame, Size box, BoxFit fit, Alignment alignment) {
    final fitted = applyBoxFit(fit, frame, box);
    return alignment.inscribe(fitted.destination, Offset.zero & box);
  }

  /// The rectangle of [det] (fractions of the frame) on a picture that is at [picture].
  static Rect boxRect(CamBlobT det, Rect picture) {
    return Rect.fromCenter(
      center: Offset(
        picture.left + det.x * picture.width,
        picture.top + det.y * picture.height,
      ),
      width: det.width * picture.width,
      height: det.height * picture.height,
    );
  }

  static const Map<String, Color> _colorMap = {
    'red': Colors.red,
    'orange': Colors.orange,
    'yellow': Colors.yellow,
    'green': Colors.green,
    'blue': Colors.blue,
    'purple': Colors.purple,
    'pink': Colors.pink,
    'cyan': Colors.cyan,
    'white': Colors.white,
    'black': Colors.grey,
  };

  static final List<Color> _fallbackColors = [
    Colors.green,
    Colors.red,
    Colors.blue,
    Colors.yellow,
    Colors.purple,
    Colors.orange,
    Colors.cyan,
    Colors.pink,
  ];

  /// The colour of a detection from the wire (ARGB, 0: the processor set none), or null.
  static Color? detectionColor(int argb) => argb == 0 ? null : Color(argb & 0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    if (detections.isEmpty || frameWidth <= 0 || frameHeight <= 0) return;

    canvas.clipRect(Offset.zero & size);  // with BoxFit.cover the picture is larger than the box
    final picture = pictureRect(
      Size(frameWidth.toDouble(), frameHeight.toDouble()),
      size,
      fit,
      alignment,
    );

    for (int i = 0; i < detections.length; i++) {
      final det = detections[i];
      // The processor's own colour first, then one by the name of the label, then one by position.
      final color = detectionColor(det.color) ??
          _colorMap[det.label.toLowerCase()] ??
          _fallbackColors[i % _fallbackColors.length];

      final rect = boxRect(det, picture);

      final boxPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRect(rect, boxPaint);

      final label =
          '${det.label}: ${det.confidence.toStringAsFixed(2)} (${det.area.round()})';
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();

      final labelRect = Rect.fromLTWH(
        rect.left,
        rect.top - textPainter.height - 4,
        textPainter.width + 8,
        textPainter.height + 4,
      );

      final labelBgPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawRect(labelRect, labelBgPaint);
      textPainter.paint(
          canvas, Offset(rect.left + 4, rect.top - textPainter.height - 2));
    }
  }

  @override
  bool shouldRepaint(covariant CamBoundingBoxPainter oldDelegate) {
    return oldDelegate.detections != detections ||
        oldDelegate.frameWidth != frameWidth ||
        oldDelegate.frameHeight != frameHeight ||
        oldDelegate.fit != fit ||
        oldDelegate.alignment != alignment;
  }
}
