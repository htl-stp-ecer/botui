import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/core/service/sensors/temperature_sensor.dart';

class ImuTemperatureDisplay extends HookConsumerWidget {
  const ImuTemperatureDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final temperature = useTemperature(ref);
    if (temperature == null) {
      return const SizedBox.shrink();
    }

    final color = temperature < 20
        ? Colors.blue
        : (temperature < 30 ? Colors.green : Colors.red);

    // Same look as the battery next to it: text 20, icon 28 to its right.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${temperature.toStringAsFixed(1)}°C',
          style: const TextStyle(color: Colors.white, fontSize: 20),
        ),
        const SizedBox(width: 4),
        Icon(
          Icons.thermostat,
          color: color,
          size: 28,
        ),
      ],
    );
  }
}
