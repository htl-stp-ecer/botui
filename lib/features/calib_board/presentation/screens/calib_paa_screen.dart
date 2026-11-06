import 'package:stpvelox/core/router/safe_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/widgets/responsive_grid.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/calib_board/application/calib_board_providers.dart';
import 'package:stpvelox/features/calib_board/presentation/widgets/calib_status_tile.dart';
import 'package:stpvelox/features/sensors/domain/entities/sensor_category.dart';
import 'package:stpvelox/core/theme/app_theme.dart';

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
              color: TileColor.byIndex(SensorCategory.analog.index),
              state: state,
              onPressed: () => context.pushOnce(AppRoutes.calibPaaDelta),
            ),
            CalibStatusTile(
              label: 'SQUAL',
              icon: Icons.signal_cellular_alt,
              color: TileColor.byIndex(SensorCategory.digital.index),
              state: state,
              onPressed: () => context.pushOnce(AppRoutes.calibPaaSqual),
            ),
            CalibStatusTile(
              label: 'Shutter',
              icon: Icons.camera,
              color: TileColor.byIndex(SensorCategory.servo.index),
              state: state,
              onPressed: () => context.pushOnce(AppRoutes.calibPaaShutter),
            ),
            CalibStatusTile(
              label: 'Track',
              icon: Icons.timeline,
              color: TileColor.byIndex(SensorCategory.motor.index),
              state: state,
              onPressed: () => context.pushOnce(AppRoutes.calibPaaTrack),
            ),
            CalibStatusTile(
              label: 'Calibration',
              icon: Icons.tune,
              color: TileColor.byIndex(SensorCategory.system.index),
              state: state,
              onPressed: () => context.pushOnce(AppRoutes.calibPaaCalibration),
            ),
            CalibStatusTile(
              label: 'Offset',
              icon: Icons.center_focus_strong,
              color: TileColor.byIndex(SensorCategory.gyro.index),
              state: state,
              onPressed: () => context.pushOnce(AppRoutes.calibPaaOffset),
            ),
          ],
        ),
      ),
    );
  }
}
