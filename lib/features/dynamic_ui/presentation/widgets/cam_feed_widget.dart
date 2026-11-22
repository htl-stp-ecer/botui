import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/features/camera/application/cam_provider.dart';
import 'package:stpvelox/features/camera/application/camera_preview_controller.dart';
import 'package:stpvelox/features/camera/presentation/widgets/cam_frame_view.dart';

/// Inline camera picture for the dynamic UI screens of a program.
///
/// The frames come as JPEGs without anything drawn on them. [CamFrameView] decodes each frame once
/// (without keeping it in the image cache) and draws the detections over it; the widget adds the frame
/// rate. While it is on screen it holds a lease on the camera and has the frame stream on.
class CamFeedWidget extends ConsumerStatefulWidget {
  final String id;
  final bool showFps;
  final bool showDetections;
  final void Function(double x, double y)? onTap;

  /// Size in pixels. With one of them the other follows the shape of the picture; with neither the
  /// picture fills the width its place in the layout gives it.
  final double? width;
  final double? height;

  /// How the picture fills a box of [width] and [height]: [BoxFit.contain] shows all of it with bars
  /// where the shapes differ, [BoxFit.cover] fills the box and cuts off what does not fit.
  final BoxFit fit;

  const CamFeedWidget({
    super.key,
    this.id = 'cam_feed',
    this.showFps = false,
    this.showDetections = true,
    this.onTap,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  @override
  ConsumerState<CamFeedWidget> createState() => _CamFeedWidgetState();
}

class _CamFeedWidgetState extends ConsumerState<CamFeedWidget> {
  late final CameraPreviewController _preview;
  Offset? _tapNorm;
  int _lastFrameTimestamp = 0;
  double _fps = 0;

  @override
  void initState() {
    super.initState();
    // The camera service opens the camera and publishes frames only while somebody holds a
    // lease and has the stream on: the widget does that while it is on screen, so a program
    // only puts CamFeed into its screen. Kept here: `ref` must not be used in dispose.
    _preview = ref.read(cameraPreviewControllerProvider);
    CamMessageGate.openNow();  // the last pictures of an earlier session are still in the transport
    unawaited(_preview.start());
  }

  @override
  void dispose() {
    unawaited(_preview.stop());
    super.dispose();
  }

  /// The frame rate from the times of the frames: smoothed, 0 until two frames have arrived.
  void _trackFps(CamFrameData frame) {
    final timestamp = frame.data.timestamp;
    if (timestamp == _lastFrameTimestamp) return;
    final seconds = (timestamp - _lastFrameTimestamp) / 1e6;
    if (_lastFrameTimestamp != 0 && seconds > 0 && seconds < 2.0) {
      final now = 1.0 / seconds;
      _fps = _fps == 0 ? now : _fps * 0.8 + now * 0.2;
    } else {
      _fps = 0;
    }
    _lastFrameTimestamp = timestamp;
  }

  Widget _sized(Widget child, double aspect) {
    final width = widget.width;
    final height = widget.height;
    if (width != null && height != null) {
      return SizedBox(width: width, height: height, child: child);
    }
    final shaped = AspectRatio(aspectRatio: aspect, child: child);
    if (width != null) return SizedBox(width: width, child: shaped);
    if (height != null) return SizedBox(height: height, child: shaped);
    return shaped;
  }

  @override
  Widget build(BuildContext context) {
    final frame = ref.watch(camFrameStreamProvider);
    final detections =
        widget.showDetections ? ref.watch(camDetectionStreamProvider) : null;

    if (frame == null || frame.data.frame_size == 0) {
      return _sized(
        Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white38),
                SizedBox(height: 8),
                Text(
                  'Waiting for camera...',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        4 / 3,
      );
    }

    _trackFps(frame);
    final w = frame.data.frame_width;
    final h = frame.data.frame_height;
    final aspect = (w > 0 && h > 0) ? w / h : 4 / 3;
    final frameSize = Size(w.toDouble(), h.toDouble());

    return _sized(
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final box = Size(constraints.maxWidth, constraints.maxHeight);
            final picture = CamBoundingBoxPainter.pictureRect(
                frameSize, box, widget.fit, Alignment.center);
            return GestureDetector(
              onTapDown: widget.onTap != null
                  ? (details) {
                      // As fractions of the picture, not of the box; a tap on a bar is no tap.
                      final norm = Offset(
                        (details.localPosition.dx - picture.left) /
                            picture.width,
                        (details.localPosition.dy - picture.top) /
                            picture.height,
                      );
                      if (norm.dx < 0 || norm.dx > 1 || norm.dy < 0 || norm.dy > 1) {
                        return;
                      }
                      setState(() => _tapNorm = norm);
                      widget.onTap!(norm.dx, norm.dy);
                    }
                  : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: Colors.black,
                    child: CamFrameView(
                      frame: frame,
                      detections: detections,
                      fit: widget.fit,
                      showDetections: widget.showDetections,
                    ),
                  ),
                  if (widget.showFps && _fps > 0)
                    Positioned(
                      top: 6,
                      left: 8,
                      child: Text(
                        '${_fps.toStringAsFixed(1)} fps',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                        ),
                      ),
                    ),
                  if (_tapNorm != null)
                    CustomPaint(
                      painter: _TapMarkerPainter(
                        normX: _tapNorm!.dx,
                        normY: _tapNorm!.dy,
                        picture: picture,
                      ),
                    ),
                  if (_tapNorm != null && widget.onTap != null)
                    Positioned(
                      bottom: 4,
                      left: 0,
                      right: 0,
                      child: Text(
                        'Tap to move sample region',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                          shadows: const [
                            Shadow(blurRadius: 4, color: Colors.black),
                          ],
                        ),
                      ),
                    ),
                  if (_tapNorm == null && widget.onTap != null)
                    const Center(
                      child: Text(
                        'Tap on the drum',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(blurRadius: 6, color: Colors.black),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
      aspect,
    );
  }
}

class _TapMarkerPainter extends CustomPainter {
  /// The tap as fractions of the picture.
  final double normX;
  final double normY;

  /// Where the picture is in the box (bars beside it, or a cut-off part).
  final Rect picture;

  _TapMarkerPainter({
    required this.normX,
    required this.normY,
    required this.picture,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = picture.left + normX * picture.width;
    final cy = picture.top + normY * picture.height;
    final radius = size.shortestSide * 0.12;

    final paint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(Offset(cx, cy), radius, paint);

    final halfLen = radius * 1.4;
    canvas.drawLine(Offset(cx - halfLen, cy), Offset(cx + halfLen, cy), paint);
    canvas.drawLine(Offset(cx, cy - halfLen), Offset(cx, cy + halfLen), paint);
  }

  @override
  bool shouldRepaint(covariant _TapMarkerPainter old) =>
      old.normX != normX || old.normY != normY || old.picture != picture;
}
