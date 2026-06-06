import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/core/transport/domain/providers.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/service/sensors/servo_sensor.dart';
import 'package:stpvelox/core/service/shutdown_status_service.dart';
import 'package:stpvelox/core/utils/colors/colors.dart';
import 'package:stpvelox/core/widgets/imu_accuracy_display.dart';
import 'package:stpvelox/core/widgets/imu_temperature_display.dart';
import 'package:stpvelox/core/widgets/responsive_grid.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/sensors/domain/entities/sensor.dart';
import 'package:stpvelox/features/sensors/domain/entities/sensor_category.dart';
import 'package:stpvelox/features/wifi/presentation/widgets/grid_tile.dart';
import 'package:raccoon_transport/messages/types/scalar_i32_t.g.dart';
import 'package:raccoon_transport/messages/types/scalar_i8_t.g.dart';
import 'package:raccoon_transport/raccoon_transport.dart';

class SensorCategoryScreen extends ConsumerWidget {
  final SensorCategory category;
  final List<Sensor> sensor;

  const SensorCategoryScreen({
    super.key,
    required this.category,
    required this.sensor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transportService = ref.watch(transportServiceProvider);
    final shutdownStatus = ref.watch(shutdownStatusProvider);
    final isMotorCategory = category.name == 'Motor';
    final isServoCategory = category.name == 'Servo';
    final isDigitalCategory = category.name == 'Digital';
    final isIMUCategory = category.name == 'Gyro' ||
        category.name == 'Accel' ||
        category.name == 'Magneto' ||
        category.name == 'Orientation' ||
        category.name == 'Heading';

    const reliable = PublishOptions(reliable: true);

    Future<void> disableAllServos() async {
      for (int i = 0; i < 4; i++) {
        // servoModeCommand is the dedicated COMMAND channel — using
        // servoMode here would round-trip through the reader's own
        // state publisher (5 ms self-loopback floor).
        transportService.publish(Channels.servoModeCommand(i), ScalarI8T(timestamp: DateTime.now().microsecondsSinceEpoch, dir: ServoMode.fullyDisabled.value), options: reliable);
      }
    }

    Future<void> stopAllMotors() async {
      for (int i = 0; i < 4; i++) {
        // motorPowerCommand uses plain delivery (continuous control loop)
        transportService.publish(Channels.motorPowerCommand(i), ScalarI32T(timestamp: DateTime.now().microsecondsSinceEpoch, value: 0));
      }
    }

    /// Check if shutdown is blocking this category and show dialog if so
    Future<bool> checkShutdownAndNavigate(Sensor sensorItem) async {
      final isShutdownBlocking = (isMotorCategory && shutdownStatus.motorShutdown) ||
          (isServoCategory && shutdownStatus.servoShutdown);

      if (!isShutdownBlocking) {
        return true; // Allow navigation
      }

      // Show shutdown warning dialog
      final result = await showDialog<String>(
        context: context,
        barrierColor: Colors.black87,
        builder: (ctx) => _ShutdownWarningDialog(
          isMotor: isMotorCategory,
          onDisableShutdown: () async {
            await ref.read(shutdownStatusServiceProvider.notifier).setShutdown(false);
          },
        ),
      );

      if (result == 'proceed') {
        return true;
      }
      return false;
    }

    final actions = <Widget>[];
    if (isIMUCategory) {
      // Show only the relevant accuracy for this category
      final accuracyType = switch (category.name) {
        'Gyro' => AccuracyType.gyro,
        'Accel' => AccuracyType.accel,
        'Magneto' => AccuracyType.mag,
        'Orientation' => AccuracyType.quaternion,
        _ => null,
      };
      if (accuracyType != null) {
        actions.add(ImuAccuracyDisplay(type: accuracyType));
        actions.add(const SizedBox(width: 16));
      }
      actions.add(const ImuTemperatureDisplay());
    }

    return Scaffold(
      appBar: createTopBar(context, category.name, actions: actions),
      body: Column(
        children: [
          Expanded(
            child: ResponsiveGrid(
              crossAxisCount: isDigitalCategory ? 5 : null,
              isScrollable: true,
              children: sensor.asMap().entries.map((entry) {
                if (isDigitalCategory) {
                  return _DigitalSensorTile(
                    sensor: entry.value,
                    index: entry.key,
                  );
                }
                return ResponsiveGridTile(
                  label: entry.value.name,
                  icon: Icons.auto_graph,
                  onPressed: () async {
                    if (isMotorCategory || isServoCategory) {
                      final shouldProceed = await checkShutdownAndNavigate(entry.value);
                      if (!shouldProceed) return;
                    }
                    if (context.mounted) {
                      context.push(AppRoutes.sensorScreen, extra: entry.value.screen);
                    }
                  },
                  color: AppColors.getTileColor(category.index),
                );
              }).toList(),
            ),
          ),
          if (isMotorCategory)
            _CategoryActionButton(
              label: 'Stop All Motors',
              onPressed: stopAllMotors,
            ),
          if (isServoCategory)
            _CategoryActionButton(
              label: 'Disable All Servos',
              onPressed: disableAllServos,
            ),
        ],
      ),
    );
  }
}

class _DigitalSensorTile extends StatefulWidget {
  final Sensor sensor;
  final int index;

  const _DigitalSensorTile({required this.sensor, required this.index});

  @override
  State<_DigitalSensorTile> createState() => _DigitalSensorTileState();
}

class _DigitalSensorTileState extends State<_DigitalSensorTile> {
  late Future<int> _future;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // TODO: Use digital sensor hooks
    _future = Future.value(0); // KiprPlugin.getDigital(widget.index);
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) {
        setState(() =>
            _future = Future.value(0)); // KiprPlugin.getDigital(widget.index));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _future,
      builder: (context, snapshot) {
        final isClicked = snapshot.data ?? 0;
        return ResponsiveGridTile(
          label: widget.sensor.name,
          icon: Icons.auto_graph,
          onPressed: () => context.push(AppRoutes.sensorScreen, extra: widget.sensor.screen),
          color: isClicked == 1 ? Colors.red : Colors.green,
        );
      },
    );
  }
}

class _CategoryActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _CategoryActionButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        height: 70,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _ShutdownWarningDialog extends StatelessWidget {
  final bool isMotor;
  final Future<void> Function() onDisableShutdown;

  const _ShutdownWarningDialog({
    required this.isMotor,
    required this.onDisableShutdown,
  });

  @override
  Widget build(BuildContext context) {
    final actorType = isMotor ? 'Motors' : 'Servos';

    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              '$actorType Disabled',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Shutdown flags are enabled. $actorType cannot be controlled until shutdown is disabled.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop('cancel'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[700],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        await onDisableShutdown();
                        if (context.mounted) {
                          Navigator.of(context).pop('proceed');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Disable',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
