import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/core/service/sensors/battery_voltage_sensor.dart';

class BatteryStatus extends HookConsumerWidget {
  const BatteryStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batteryVoltage = useBatteryVoltage(ref) ?? 0.0;

    if (batteryVoltage <= 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 8.0, 0),
      child: Row(
        children: [
          Text(
            '${batteryVoltage.toStringAsFixed(2)}V',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.battery_4_bar_rounded,
            color: Colors.white,
            size: 28,
          ),
        ],
      ),
    );
  }
}
