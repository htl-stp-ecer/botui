import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/widgets/responsive_grid.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/core/widgets/imu_accuracy_display.dart';
import 'package:stpvelox/core/widgets/imu_temperature_display.dart';
import 'package:stpvelox/features/sensors/domain/entities/sensor.dart';
import 'package:stpvelox/features/sensors/domain/entities/sensor_category.dart';
import 'package:stpvelox/features/wifi/presentation/widgets/grid_tile.dart';
import 'package:stpvelox/core/theme/app_theme.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ImuSelectionScreen extends ConsumerWidget {
  final Map<SensorCategory, List<Sensor>> imuGroups;

  const ImuSelectionScreen({super.key, required this.imuGroups});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: createTopBar(
        context,
        'IMU',
        actions: [
          const ImuAccuracyDisplay(),
          const SizedBox(width: 16),
          const ImuTemperatureDisplay(),
        ],
      ),
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: ResponsiveGrid(
          isScrollable: true,
          children: imuGroups.entries
              .map((entry) =>
                  _buildSubcategoryTile(context, entry.key, entry.value))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildSubcategoryTile(
      BuildContext context, SensorCategory category, List<Sensor> sensors) {
    return ResponsiveGridTile(
      label: category.name,
      icon: _getIconForCategory(category),
      onPressed: () {
        if (sensors.length == 1) {
          context.push(AppRoutes.sensorScreen, extra: sensors.first.screen);
          return;
        }
        context.push(
          AppRoutes.sensorCategory,
          extra: {'category': category, 'sensors': sensors},
        );
      },
      color: TileColor.byIndex(category.index),
    );
  }

  IconData _getIconForCategory(SensorCategory category) {
    return switch (category) {
      SensorCategory.gyro => Icons.rotate_right,
      SensorCategory.accel => Icons.speed,
      SensorCategory.mag => Icons.explore,
      SensorCategory.orientation => Icons.threed_rotation,
      SensorCategory.heading => Icons.navigation,
      _ => Icons.auto_graph,
    };
  }
}
