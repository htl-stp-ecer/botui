import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/features/camera/application/cam_provider.dart';

/// Inline camera feed widget for use in dynamic UI screens.
///
/// The LCM-generated `CamFrameT.frame_data` is a `List<int>` of boxed
/// Dart ints. Converting to `Uint8List` is the expensive part — we do
/// it once per fresh frame here (keyed by timestamp), not on every
/// widget rebuild like the original code did. `Image.memory` itself
/// has internal caching by byte identity, so feeding the same
/// `Uint8List` across rebuilds avoids re-decoding the JPEG.
class CamFeedWidget extends ConsumerStatefulWidget {
  final String id;
  final bool showFps;
  final bool showDetections;
  final void Function(double x, double y)? onTap;

  const CamFeedWidget({
    super.key,
    this.id = 'cam_feed',
    this.showFps = false,
    this.showDetections = true,
    this.onTap,
  });

  @override
  ConsumerState<CamFeedWidget> createState() => _CamFeedWidgetState();
}

class _CamFeedWidgetState extends ConsumerState<CamFeedWidget> {
  Offset? _tapNorm;
  Uint8List? _cachedBytes;
  int _cachedTimestamp = 0;

  Uint8List? _bytesFor(CamFrameData frame) {
    if (frame.data.frame_size == 0) return null;
    final ts = frame.data.timestamp;
    if (ts == _cachedTimestamp && _cachedBytes != null) return _cachedBytes;
    final raw = frame.data.frame_data;
    final bytes = raw is Uint8List ? raw : Uint8List.fromList(raw);
    _cachedBytes = bytes;
    _cachedTimestamp = ts;
    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    final frame = ref.watch(camFrameStreamProvider);

    final imageData = frame == null ? null : _bytesFor(frame);
    if (imageData == null) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: Container(
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
      );
    }

    final w = frame!.data.frame_width;
    final h = frame.data.frame_height;
    final aspect = (w > 0 && h > 0) ? w / h : 4 / 3;

    return AspectRatio(
      aspectRatio: aspect,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              onTapDown: widget.onTap != null
                  ? (details) {
                      final norm = Offset(
                        details.localPosition.dx / constraints.maxWidth,
                        details.localPosition.dy / constraints.maxHeight,
                      );
                      setState(() => _tapNorm = norm);
                      widget.onTap!(norm.dx, norm.dy);
                    }
                  : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: Colors.black,
                    child: Image.memory(
                      imageData,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.low,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(Icons.broken_image,
                              color: Colors.white38, size: 48),
                        );
                      },
                    ),
                  ),
                  if (_tapNorm != null)
                    CustomPaint(
                      painter: _TapMarkerPainter(
                        normX: _tapNorm!.dx,
                        normY: _tapNorm!.dy,
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
    );
  }
}

class _TapMarkerPainter extends CustomPainter {
  final double normX;
  final double normY;

  _TapMarkerPainter({required this.normX, required this.normY});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = normX * size.width;
    final cy = normY * size.height;
    final radius = size.shortestSide * 0.12;

    final paint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(Offset(cx, cy), radius, paint);

    final halfLen = radius * 1.4;
    canvas.drawLine(
        Offset(cx - halfLen, cy), Offset(cx + halfLen, cy), paint);
    canvas.drawLine(
        Offset(cx, cy - halfLen), Offset(cx, cy + halfLen), paint);
  }

  @override
  bool shouldRepaint(covariant _TapMarkerPainter old) =>
      old.normX != normX || old.normY != normY;
}
