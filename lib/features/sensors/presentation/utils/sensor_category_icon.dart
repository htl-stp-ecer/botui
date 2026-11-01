import 'package:flutter/material.dart';
import 'package:stpvelox/features/sensors/domain/entities/sensor_category.dart';

/// The icon of a sensor category, used for the category's tile in the menus
/// and for the tiles inside the category screen.
IconData sensorCategoryIcon(SensorCategory category) => switch (category) {
      SensorCategory.analog => Icons.show_chart,
      SensorCategory.digital => Icons.toggle_on,
      SensorCategory.motor => Icons.settings,
      SensorCategory.servo => Icons.precision_manufacturing,
      SensorCategory.system => Icons.monitor_heart,
      SensorCategory.camera => Icons.videocam,
      SensorCategory.gyro => Icons.rotate_right,
      SensorCategory.accel => Icons.speed,
      SensorCategory.mag => Icons.explore,
      SensorCategory.orientation => Icons.threed_rotation,
      SensorCategory.heading => Icons.navigation,
    };
