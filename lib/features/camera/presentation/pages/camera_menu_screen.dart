import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/application/theme/color_theme_provider.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/theme/app_theme.dart';
import 'package:stpvelox/core/utils/colors/colors.dart';
import 'package:stpvelox/core/widgets/app_toast.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/camera/application/cam_provider.dart';
import 'package:stpvelox/features/camera/application/camera_backend_form.dart';
import 'package:stpvelox/features/camera/application/camera_preview_controller.dart';
import 'package:stpvelox/features/camera/presentation/widgets/cam_preview.dart';

/// Sensors & Actors -> Camera: choose and configure what delivers the
/// picture, and watch it while doing so.
class CameraMenuScreen extends ConsumerStatefulWidget {
  const CameraMenuScreen({super.key});

  @override
  ConsumerState<CameraMenuScreen> createState() => _CameraMenuScreenState();
}

class _CameraMenuScreenState extends ConsumerState<CameraMenuScreen> {
  late final CameraPreviewController _preview;

  @override
  void initState() {
    super.initState();
    // Kept here: `ref` must not be used in dispose.
    _preview = ref.read(cameraPreviewControllerProvider);
    unawaited(_preview.start());
  }

  @override
  void dispose() {
    unawaited(_preview.stop());
    super.dispose();
  }

  /// Opens the backend settings. If the choice was changed there, the service
  /// restarts the camera: show "starting" again, not the old backend's picture.
  Future<void> _openBackendConfig() async {
    final form = ref.read(cameraBackendFormProvider.notifier);
    final before = form.changes;
    await context.push(AppRoutes.cameraBackendConfig);
    if (!mounted || form.changes == before) return;
    unawaited(_preview.waitForRestart(clear: _dropPictures));
  }

  void _dropPictures() {
    if (!mounted) return;
    ref.invalidate(camFrameStreamProvider);
    ref.invalidate(camDetectionStreamProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(colorThemeProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: createTopBar(context, 'Camera'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Buttons like the ones on the scanned networks screen: the colors
              // come from the theme (in the colorful theme: teal and purple).
              Row(
                children: [
                  Expanded(
                    child: _MenuButton(
                      label: 'Configure backend',
                      icon: Icons.tune_rounded,
                      color: theme.tileColor(TileColor.teal, 0),
                      foreground: theme.textColor,
                      onPressed: _openBackendConfig,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _MenuButton(
                      label: 'Configure processor',
                      icon: Icons.filter_center_focus_rounded,
                      color: theme.tileColor(TileColor.purple, 1),
                      foreground: theme.textColor,
                      // Processors cannot be configured here yet.
                      onPressed: () =>
                          AppToast.info('Processors can be configured later.'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Takes what is left of the screen; no scrolling.
              const Expanded(child: _PreviewBox()),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.foreground,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 28),
      label: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: color,
        foregroundColor: foreground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),
    );
  }
}

/// The preview, as large as fits in the room that is left, in the shape of the
/// picture. A picture that is too big for it is scaled down, a small one is
/// scaled up: it always fills the room along its limiting side.
class _PreviewBox extends ConsumerWidget {
  const _PreviewBox();

  /// Until the first frame says otherwise (the default stream is 320x240).
  static const double defaultAspect = 4 / 3;

  /// The corners, like the raccoon picture of the program list.
  static const double radius = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frame = ref.watch(camFrameStreamProvider);
    final width = frame?.data.frame_width ?? 0;
    final height = frame?.data.frame_height ?? 0;
    final aspect = width > 0 && height > 0 ? width / height : defaultAspect;

    return LayoutBuilder(
      builder: (context, constraints) {
        var boxWidth = constraints.maxWidth;
        var boxHeight = boxWidth / aspect;
        if (constraints.maxHeight.isFinite && boxHeight > constraints.maxHeight) {
          boxHeight = constraints.maxHeight;
          boxWidth = boxHeight * aspect;
        }
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: boxWidth,
            height: boxHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: const CamPreview(),
            ),
          ),
        );
      },
    );
  }
}
