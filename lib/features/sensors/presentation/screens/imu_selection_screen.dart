import 'package:stpvelox/core/router/safe_navigation.dart';
import 'package:flutter/material.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/widgets/responsive_grid.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/core/widgets/imu_accuracy_display.dart';
import 'package:stpvelox/core/widgets/imu_temperature_display.dart';
import 'package:stpvelox/features/sensors/domain/entities/sensor.dart';
import 'package:stpvelox/features/sensors/domain/entities/sensor_category.dart';
import 'package:stpvelox/features/wifi/presentation/widgets/grid_tile.dart';
import 'package:stpvelox/core/theme/app_theme.dart';
import 'package:stpvelox/features/sensors/presentation/utils/sensor_category_icon.dart';
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
          const ImuTemperatureDisplay(),
          const SizedBox(width: 14),
          const ImuAccuracyDisplay(),
          const SizedBox(width: 14),
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
      icon: sensorCategoryIcon(category),
      onPressed: () {
        if (sensors.length == 1) {
          context.pushOnce(AppRoutes.sensorScreen, extra: sensors.first.screen);
          return;
        }
        context.pushOnce(
          AppRoutes.sensorCategory,
          extra: {'category': category, 'sensors': sensors},
        );
      },
      color: TileColor.byIndex(category.index),
    );
  }
}
