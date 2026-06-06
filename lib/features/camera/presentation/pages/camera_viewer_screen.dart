import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/core/utils/colors/colors.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:raccoon_transport/raccoon_transport.dart';
import 'package:stpvelox/features/camera/application/cam_provider.dart';

class CameraViewerScreen extends ConsumerStatefulWidget {
  const CameraViewerScreen({super.key});

  @override
  ConsumerState<CameraViewerScreen> createState() =>
      _CameraViewerScreenState();
}

class _CameraViewerScreenState extends ConsumerState<CameraViewerScreen> {
  int _frameCount = 0;
  DateTime? _startTime;
  double _fps = 0.0;

  @override
  Widget build(BuildContext context) {
    final frame = ref.watch(camFrameStreamProvider);
    final detections = ref.watch(camDetectionStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: createTopBar(context, 'Camera'),
      body: SafeArea(
        child: frame != null
            ? _buildFrameView(frame, detections)
            : _buildLoadingView(detections),
      ),
    );
  }

  void _updateFps() {
    _frameCount++;
    _startTime ??= DateTime.now();
    final elapsed =
        DateTime.now().difference(_startTime!).inMilliseconds / 1000.0;
    if (elapsed > 0) {
      setState(() {
        _fps = _frameCount / elapsed;
      });
    }
  }

  Widget _buildLoadingView(CamDetectionData? detections) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.programs),
          const SizedBox(height: 16),
          const Text(
            'Waiting for camera frames…',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Channel: ${Channels.camFrame}',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          if (detections != null) ...[
            const SizedBox(height: 8),
            Text(
              'Detections: ${detections.data.num_detections}',
              style: TextStyle(color: Colors.blue[300], fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFrameView(
      CamFrameData frame, CamDetectionData? detections) {
    _updateFps();

    final detectionCount = frame.data.num_detections;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.black54,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Frame: ${frame.data.frame_width}x${frame.data.frame_height}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              Text(
                'FPS: ${_fps.toStringAsFixed(1)}',
                style: TextStyle(
                    color: Colors.green[300],
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
              Text(
                'Detections: $detectionCount',
                style: TextStyle(color: Colors.blue[300], fontSize: 14),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: Colors.black,
            child: Center(
              child: _CamFrameWidget(
                frame: frame,
                detections: detections,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CamFrameWidget extends StatefulWidget {
  final CamFrameData frame;
  final CamDetectionData? detections;

  const _CamFrameWidget({required this.frame, this.detections});

  @override
  State<_CamFrameWidget> createState() => _CamFrameWidgetState();
}

class _CamFrameWidgetState extends State<_CamFrameWidget> {
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
    if (imageData == null) {
      return const Center(
        child: Text(
          'No frame data',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    final allDetections = widget.frame.data.detections.isNotEmpty
        ? widget.frame.data.detections
        : (widget.detections?.data.detections ?? const <CamBlobT>[]);

    return Stack(
      children: [
        Image.memory(
          imageData,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          filterQuality: FilterQuality.low,
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
        Positioned.fill(
          child: CustomPaint(
            painter: _CamBoundingBoxPainter(
              detections: allDetections,
              frameWidth: widget.frame.data.frame_width,
              frameHeight: widget.frame.data.frame_height,
            ),
          ),
        ),
      ],
    );
  }
}

class _CamBoundingBoxPainter extends CustomPainter {
  final List<CamBlobT> detections;
  final int frameWidth;
  final int frameHeight;

  _CamBoundingBoxPainter({
    required this.detections,
    required this.frameWidth,
    required this.frameHeight,
  });

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

  @override
  void paint(Canvas canvas, Size size) {
    if (detections.isEmpty || frameWidth <= 0 || frameHeight <= 0) return;

    final sx = size.width / frameWidth;
    final sy = size.height / frameHeight;

    for (int i = 0; i < detections.length; i++) {
      final det = detections[i];
      final color = _colorMap[det.label.toLowerCase()] ??
          _fallbackColors[i % _fallbackColors.length];

      final rect = Rect.fromLTWH(
        det.x * sx,
        det.y * sy,
        det.width * sx,
        det.height * sy,
      );

      final boxPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRect(rect, boxPaint);

      final label =
          '${det.label}: ${det.confidence.toStringAsFixed(2)} (${det.area})';
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
  bool shouldRepaint(covariant _CamBoundingBoxPainter oldDelegate) {
    return oldDelegate.detections != detections ||
        oldDelegate.frameWidth != frameWidth ||
        oldDelegate.frameHeight != frameHeight;
  }
}
