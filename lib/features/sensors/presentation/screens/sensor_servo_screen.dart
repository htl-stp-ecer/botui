import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/core/service/sensors/servo_sensor.dart';
import 'package:stpvelox/core/transport/domain/providers.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/sensors/domain/entities/sensor.dart';
import 'package:stpvelox/features/sensors/presentation/widgets/bus_servo_panel.dart';
import 'package:stpvelox/features/sensors/presentation/widgets/pwm_servo_panel.dart';
import 'package:stpvelox/features/sensors/presentation/widgets/servo_type_sidebar.dart';
import 'package:raccoon_transport/raccoon_transport.dart';

class SensorServoScreen extends HookConsumerWidget {
  final int port;
  final Sensor sensor;

  const SensorServoScreen(
      {super.key, required this.port, required this.sensor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transportService = ref.watch(transportServiceProvider);
    final servoMode = ref.watch(servoModeSensorProvider(port));

    // The tab is the user's choice and always switchable. Until they pick one
    // it follows the mode the reader reports. The bus panel itself shows a
    // "waiting for the bus servo" state while no servo answers.
    final picked = useState<ServoType?>(null);
    final type = picked.value ??
        (servoMode == ServoMode.bus ? ServoType.bus : ServoType.pwm);

    void selectType(ServoType selected) {
      picked.value = selected;
      // Bus: the STM32 takes the pin off the PWM timer and starts talking STS
      // (servo starts relaxed). PWM: leave bus mode with PWM still off; the
      // first slider move enables it.
      final mode =
          selected == ServoType.bus ? ServoMode.bus : ServoMode.disabled;
      transportService.publish(
        Channels.servoModeCommand(port),
        ScalarI8T(
            timestamp: DateTime.now().microsecondsSinceEpoch, dir: mode.value),
        options: const PublishOptions(reliable: true),
      );
    }

    return Scaffold(
      appBar: createTopBar(context, sensor.name),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ServoTypeSidebar(selected: type, onSelect: selectType),
          Expanded(
            child: type == ServoType.bus
                ? BusServoPanel(port: port)
                : PwmServoPanel(port: port),
          ),
        ],
      ),
    );
  }
}
