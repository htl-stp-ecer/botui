import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/core/transport/domain/providers.dart';
import 'package:stpvelox/core/utils/colors/colors.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:raccoon_transport/raccoon_transport.dart';
import 'package:stpvelox/features/camera/application/cam_provider.dart';
import 'package:stpvelox/features/camera/presentation/widgets/cam_calibration_panel.dart';

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
  void initState() {
    super.initState();
    Future.microtask(() {
      final transport = ref.read(transportServiceProvider);
      publishStreamCtl(transport, enabled: true);
    });
  }

  @override
  void dispose() {
    // Request stream stop
    try {
      final transport = ref.read(transportServiceProvider);
      publishStreamCtl(transport, enabled: false);
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frame = ref.watch(camFrameStreamProvider);
    final detections = ref.watch(camDetectionStreamProvider);
    final transport = ref.watch(transportServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: createTopBar(
        context,
        'Camera',
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.white),
            iconSize: 32,
            onPressed: () => _showCalibrationPanel(context),
          ),
        ],
      ),
      body: SafeArea(
        child: frame != null
            ? _buildFrameView(frame, detections)
            : _buildLoadingView(transport.isInitialized, detections),
      ),
    );
  }

  void _showCalibrationPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => CamCalibrationPanel(
          scrollController: scrollController,
        ),
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

  Widget _buildLoadingView(
      bool transportInitialized, CamDetectionData? detections) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.programs),
          const SizedBox(height: 16),
          Text(
            'Waiting for camera frames...',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Channel: ${Channels.camFrame}',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            'Transport Status: ${transportInitialized ? "Initialized" : "Initializing..."}',
            style: TextStyle(
              color: transportInitialized ? Colors.green[300] : Colors.orange[300],
              fontSize: 12,
            ),
          ),
          if (detections != null) ...[
            const SizedBox(height: 8),
            Text(
              'Detections: ${detections.data.num_detections}',
              style: TextStyle(color: Colors.blue[300], fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Frames received: $_frameCount',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              ref.invalidate(camFrameStreamProvider);
              final transport = ref.read(transportServiceProvider);
              publishStreamCtl(transport, enabled: true);
            },
            icon: Icon(Icons.refresh),
            label: Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrameView(
      CamFrameData frame, CamDetectionData? detections) {
    _updateFps();

    // Use detections from frame itself, or from separate detection stream
    final detectionCount = frame.data.num_detections;
    final detectionList = frame.data.detections;

    return Column(
      children: [
        // Info bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.black54,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Frame: ${frame.data.frame_width}x${frame.data.frame_height}',
                style: TextStyle(color: Colors.white, fontSize: 14),
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
        // Frame display
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

class _CamFrameWidget extends StatelessWidget {
  final CamFrameData frame;
  final CamDetectionData? detections;

  const _CamFrameWidget({required this.frame, this.detections});

  @override
  Widget build(BuildContext context) {
    if (frame.data.frame_size == 0 || frame.data.frame_data.isEmpty) {
      return Center(
        child: Text(
          'No frame data',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    // Decode JPEG image
    final imageData = Uint8List.fromList(frame.data.frame_data);

    // Merge detections: prefer frame-embedded, fallback to separate stream
    final allDetections = frame.data.detections.isNotEmpty
        ? frame.data.detections
        : (detections?.data.detections ?? []);

    return Stack(
      children: [
        // Display image
        Image.memory(
          imageData,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, color: Colors.white38, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    'Failed to decode image',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            );
          },
        ),
        // Overlay bounding boxes
        Positioned.fill(
          child: CustomPaint(
            painter: _CamBoundingBoxPainter(detections: allDetections),
          ),
        ),
      ],
    );
  }
}

class _CamBoundingBoxPainter extends CustomPainter {
  final List<CamBlobT> detections;

  _CamBoundingBoxPainter({required this.detections});

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
    if (detections.isEmpty) return;

    final width = size.width;
    final height = size.height;

    for (int i = 0; i < detections.length; i++) {
      final det = detections[i];
      final color = _colorMap[det.label.toLowerCase()] ??
          _fallbackColors[i % _fallbackColors.length];

      // Convert normalized center coordinates to pixel corners
      final x1 = (det.x - det.width / 2) * width;
      final y1 = (det.y - det.height / 2) * height;
      final x2 = (det.x + det.width / 2) * width;
      final y2 = (det.y + det.height / 2) * height;

      final rect = Rect.fromLTRB(x1, y1, x2, y2);

      // Draw bounding box
      final boxPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRect(rect, boxPaint);

      // Draw label background
      final label =
          '${det.label}: ${det.confidence.toStringAsFixed(2)} (${det.area})';
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();

      final labelRect = Rect.fromLTWH(
        x1,
        y1 - textPainter.height - 4,
        textPainter.width + 8,
        textPainter.height + 4,
      );

      final labelBgPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawRect(labelRect, labelBgPaint);

      // Draw label text
      textPainter.paint(canvas, Offset(x1 + 4, y1 - textPainter.height - 2));
    }
  }

  @override
  bool shouldRepaint(covariant _CamBoundingBoxPainter oldDelegate) {
    return oldDelegate.detections != detections;
  }
}
