import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/theme/app_theme.dart';
import 'package:stpvelox/core/utils/colors/colors.dart';
import 'package:stpvelox/core/widgets/app_toast.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/core/widgets/two_button_strip.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: createTopBar(context, 'Camera'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TwoButtonStrip(
                title: 'Camera',
                buttons: [
                  StripButton(
                    label: 'Configure backend',
                    icon: Icons.tune_rounded,
                    slot: TileColor.teal,
                    onTap: () => context.push(AppRoutes.cameraBackendConfig),
                  ),
                  StripButton(
                    label: 'Configure processor',
                    icon: Icons.filter_center_focus_rounded,
                    slot: TileColor.purple,
                    // Processors cannot be configured here yet.
                    onTap: () => AppToast.info('Processors can be configured later.'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  child: CamPreview(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
