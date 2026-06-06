import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/utils/colors/colors.dart';
import 'package:stpvelox/core/widgets/responsive_grid.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/calib_board/application/calib_board_providers.dart';
import 'package:stpvelox/features/calib_board/presentation/widgets/calib_status_tile.dart';
import 'package:stpvelox/features/sensors/domain/entities/sensor_category.dart';

/// PAA5100-Submenü.  Fünf Sub-Tiles: vier reine Anzeigen, eine
/// "Calibration" als eigener Grideintrag wie vom User gewünscht.
class CalibPaaScreen extends ConsumerWidget {
  const CalibPaaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(calibBoardStatusProvider);
    final state = status.paa;

    return Scaffold(
      appBar: createTopBar(context, 'PAA5100 — Optical Flow'),
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: ResponsiveGrid(
          children: [
            CalibStatusTile(
              label: 'Delta',
              icon: Icons.swap_horiz,
              color: AppColors.getTileColor(SensorCategory.analog.index),
              state: state,
              onPressed: () => context.push(AppRoutes.calibPaaDelta),
            ),
            CalibStatusTile(
              label: 'SQUAL',
              icon: Icons.signal_cellular_alt,
              color: AppColors.getTileColor(SensorCategory.digital.index),
              state: state,
              onPressed: () => context.push(AppRoutes.calibPaaSqual),
            ),
            CalibStatusTile(
              label: 'Shutter',
              icon: Icons.camera,
              color: AppColors.getTileColor(SensorCategory.servo.index),
              state: state,
              onPressed: () => context.push(AppRoutes.calibPaaShutter),
            ),
            CalibStatusTile(
              label: 'Track',
              icon: Icons.timeline,
              color: AppColors.getTileColor(SensorCategory.motor.index),
              state: state,
              onPressed: () => context.push(AppRoutes.calibPaaTrack),
            ),
            CalibStatusTile(
              label: 'Calibration',
              icon: Icons.tune,
              color: AppColors.getTileColor(SensorCategory.system.index),
              state: state,
              onPressed: () => context.push(AppRoutes.calibPaaCalibration),
            ),
          ],
        ),
      ),
    );
  }
}
