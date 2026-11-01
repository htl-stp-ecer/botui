import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/widgets/responsive_grid.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/calib_board/application/calib_board_providers.dart';
import 'package:stpvelox/features/calib_board/domain/entities/calib_board_status.dart';
import 'package:stpvelox/features/calib_board/presentation/widgets/calib_status_tile.dart';
import 'package:stpvelox/features/sensors/domain/entities/sensor_category.dart';
import 'package:stpvelox/core/theme/app_theme.dart';

/// ICM-Submenü.  Mirrort das IMU-Pattern: ein Sub-Grid pro Sensor mit
/// Sub-Tiles für jede Größe.  Jeder Leaf-Screen kriegt 800×480 für sich
/// und kann den Plot maximal groß zeichnen.
class CalibIcmScreen extends ConsumerWidget {
  const CalibIcmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(calibBoardStatusProvider);
    final available = status.icm == CalibSensorState.ok;
    // ICM-Verfügbarkeit propagiert sich an die Sub-Tiles — solange das
    // Board nicht da ist oder ICM-Init failt, sind alle drei grau.
    final state = available ? CalibSensorState.ok : status.icm;

    return Scaffold(
      appBar: createTopBar(context, 'ICM-42688-P'),
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: ResponsiveGrid(
          children: [
            CalibStatusTile(
              label: 'Accelerometer',
              icon: Icons.speed,
              color: TileColor.byIndex(SensorCategory.accel.index),
              state: state,
              onPressed: () => context.push(AppRoutes.calibIcmAccel),
            ),
            CalibStatusTile(
              label: 'Gyroscope',
              icon: Icons.rotate_right,
              color: TileColor.byIndex(SensorCategory.gyro.index),
              state: state,
              onPressed: () => context.push(AppRoutes.calibIcmGyro),
            ),
            CalibStatusTile(
              label: 'Temperature',
              icon: Icons.thermostat,
              color: TileColor.byIndex(SensorCategory.system.index),
              state: state,
              onPressed: () => context.push(AppRoutes.calibIcmTemp),
            ),
            CalibStatusTile(
              label: 'Orientation',
              icon: Icons.threed_rotation,
              color: TileColor.byIndex(SensorCategory.orientation.index),
              state: state,
              onPressed: () => context.push(AppRoutes.calibIcmOrientation),
            ),
            CalibStatusTile(
              label: 'Calibration',
              icon: Icons.tune,
              color: TileColor.byIndex(SensorCategory.heading.index),
              state: state,
              onPressed: () => context.push(AppRoutes.calibIcmCalibration),
            ),
          ],
        ),
      ),
    );
  }
}
