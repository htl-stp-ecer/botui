import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/utils/colors/colors.dart';
import 'package:stpvelox/core/widgets/responsive_grid.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/calib_board/application/calib_board_providers.dart';
import 'package:stpvelox/features/calib_board/domain/entities/calib_board_status.dart';
import 'package:stpvelox/features/calib_board/presentation/widgets/calib_status_tile.dart';
import 'package:stpvelox/features/sensors/domain/entities/sensor_category.dart';

/// Sub-Sensor-Screen für das Calibration-Board.  Zeigt drei Tiles
/// (Optical Flow / BNO / ICM) — alle drei sind sichtbar, aber per
/// Bridge-Status-Channel als "available"/"not connected"/"waiting"
/// gerendert.  Nur "available" ist klickbar.
class CalibBoardScreen extends ConsumerWidget {
  const CalibBoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(calibBoardStatusProvider);

    return Scaffold(
      appBar: createTopBar(
        context,
        'Calibration Board',
        actions: [_PortBadge(status: status)],
      ),
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: ResponsiveGrid(
          isScrollable: true,
          children: [
            CalibStatusTile(
              label: 'Optical Flow',
              icon: Icons.mouse_outlined,
              color: AppColors.getTileColor(SensorCategory.analog.index),
              state: status.paa,
              detail: status.paaDetail,
              onPressed: () => context.push(AppRoutes.calibPaa),
            ),
            CalibStatusTile(
              label: 'ICM (IMU)',
              icon: Icons.threed_rotation,
              color: AppColors.getTileColor(SensorCategory.gyro.index),
              state: status.icm,
              detail: status.icmDetail,
              onPressed: () => context.push(AppRoutes.calibIcm),
            ),
            CalibStatusTile(
              label: 'Odometry',
              icon: Icons.navigation,
              color: AppColors.getTileColor(SensorCategory.heading.index),
              // Odometrie ist verfügbar wenn ICM läuft (PAA-cm-Werte
              // fließen aus Defaults, auch wenn PAA "absent" ist — der
              // Pose verändert sich dann eben nur per Rotation).
              state: status.icm,
              detail: 'PAA + IMU fusion',
              onPressed: () => context.push(AppRoutes.calibOdometry),
            ),
            CalibStatusTile(
              label: 'BNO (Fusion)',
              icon: Icons.explore,
              color: AppColors.getTileColor(SensorCategory.orientation.index),
              state: status.bno,
              detail: 'hardware not present',
              onPressed: () => context.push(AppRoutes.calibBno),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortBadge extends StatelessWidget {
  const _PortBadge({required this.status});
  final CalibBoardStatus status;

  @override
  Widget build(BuildContext context) {
    final connected = status.boardConnected;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(
            connected ? Icons.usb : Icons.usb_off,
            color: connected ? Colors.greenAccent : Colors.redAccent,
            size: 20,
          ),
          const SizedBox(width: 4),
          Text(
            status.port,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
