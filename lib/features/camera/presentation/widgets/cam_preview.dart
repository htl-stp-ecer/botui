import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/core/utils/colors/colors.dart';
import 'package:stpvelox/features/camera/application/cam_provider.dart';
import 'package:stpvelox/features/camera/application/camera_preview_controller.dart';
import 'package:stpvelox/features/camera/presentation/widgets/cam_frame_view.dart';

/// The picture of the camera, or what is going on instead of it. The
/// [CameraPreviewController] has to be started by whoever shows this.
class CamPreview extends ConsumerStatefulWidget {
  const CamPreview({super.key});

  /// A picture older than this is not shown: the camera stopped delivering
  /// (it restarts, or reopens the device), and a frozen image would look like
  /// a picture. The stream runs at 10 frames per second.
  static const Duration stale = Duration(seconds: 2);

  @override
  ConsumerState<CamPreview> createState() => _CamPreviewState();
}

class _CamPreviewState extends ConsumerState<CamPreview> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Frames that stop arriving do not rebuild anything: look again regularly.
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  bool _isStale(CamFrameData frame) {
    final age = DateTime.now().microsecondsSinceEpoch - frame.data.timestamp;
    return age > CamPreview.stale.inMicroseconds;
  }

  @override
  Widget build(BuildContext context) {
    final frame = ref.watch(camFrameStreamProvider);
    final detections = ref.watch(camDetectionStreamProvider);
    final controller = ref.read(cameraPreviewControllerProvider);

    return Container(
      color: Colors.black,
      child: ValueListenableBuilder<CameraPreviewStatus>(
        valueListenable: controller,
        builder: (context, status, _) {
          if (status.phase == CameraPreviewPhase.failed) {
            return _Message(
              icon: Icons.videocam_off_rounded,
              text: status.message ?? 'The camera could not be started.',
              onRetry: controller.retry,
            );
          }
          if (frame != null && status.phase == CameraPreviewPhase.running) {
            if (_isStale(frame)) {
              return const _Message(busy: true, text: 'Waiting for the camera…');
            }
            return CamFrameView(
              frame: frame,
              detections: detections,
              alignment: Alignment.topCenter,
            );
          }
          return _Message(
            busy: true,
            text: status.phase == CameraPreviewPhase.running
                ? 'Waiting for the first frame…'
                : 'Starting the camera…',
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.text,
    this.icon,
    this.busy = false,
    this.onRetry,
  });

  final String text;
  final IconData? icon;
  final bool busy;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              CircularProgressIndicator(color: AppColors.programs)
            else if (icon != null)
              Icon(icon, color: Colors.white38, size: 48),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}
