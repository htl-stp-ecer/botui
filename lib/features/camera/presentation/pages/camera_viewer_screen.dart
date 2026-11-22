import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/core/utils/colors/colors.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:raccoon_transport/raccoon_transport.dart';
import 'package:stpvelox/features/camera/application/cam_provider.dart';
import 'package:stpvelox/features/camera/presentation/widgets/cam_frame_view.dart';

class CameraViewerScreen extends ConsumerStatefulWidget {
  const CameraViewerScreen({super.key});

  @override
  ConsumerState<CameraViewerScreen> createState() => _CameraViewerScreenState();
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
            'Channel: ${channels.camera.state.frame}',
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

  Widget _buildFrameView(CamFrameData frame, CamDetectionData? detections) {
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
              child: CamFrameView(
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
