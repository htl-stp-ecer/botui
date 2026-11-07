import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/core/widgets/imu_accuracy_display.dart';
import 'package:stpvelox/core/widgets/imu_temperature_display.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/sensors/domain/entities/sensor.dart';
import 'package:stpvelox/features/sensors/presentation/widgets/quaternion_visualization.dart';

class QuaternionScreen extends HookConsumerWidget {
  final Sensor sensor;

  const QuaternionScreen({super.key, required this.sensor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: createTopBar(
        context,
        sensor.name,
        actions: [
          const ImuTemperatureDisplay(),
          const SizedBox(width: 14),
          const ImuAccuracyDisplay(type: AccuracyType.quaternion),
          const SizedBox(width: 14),
        ],
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: QuaternionVisualization(),
      ),
    );
  }
}
