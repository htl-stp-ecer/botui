import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/core/utils/colors/colors.dart';
import 'package:stpvelox/features/camera/application/cam_provider.dart';
import 'package:stpvelox/features/camera/application/camera_preview_controller.dart';
import 'package:stpvelox/features/camera/presentation/widgets/cam_frame_view.dart';

/// The picture of the camera, or what is going on instead of it. The
/// [CameraPreviewController] has to be started by whoever shows this.
class CamPreview extends ConsumerWidget {
  const CamPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            );
          }
          if (frame != null && status.phase == CameraPreviewPhase.running) {
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
  const _Message({required this.text, this.icon, this.busy = false});

  final String text;
  final IconData? icon;
  final bool busy;

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
          ],
        ),
      ),
    );
  }
}
