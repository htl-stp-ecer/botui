import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';
import 'package:stpvelox/core/lcm/domain/providers.dart';
import 'package:stpvelox/core/service/sensors/servo_command_sensor.dart';
import 'package:stpvelox/core/service/sensors/servo_position_sensor.dart';
import 'package:stpvelox/core/service/sensors/servo_sensor.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/sensors/domain/entities/sensor.dart';
import 'package:raccoon_transport/raccoon_transport.dart';

class ServoUtils {
  static const double minAngle = 0.0;
  static const double maxAngle = 180.0;
  static const double dangerMinAngle = -50.0;
  static const double dangerMaxAngle = 360.0;
  static const double servoSpeedDps = 60 / 0.3;

  static double estimateServoMoveTime(double startAngle, double endAngle) {
    final delta = (endAngle - startAngle).abs();
    return delta / servoSpeedDps;
  }
}

class SensorServoScreen extends HookConsumerWidget {
  final int port;
  final Sensor sensor;

  const SensorServoScreen(
      {super.key, required this.port, required this.sensor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lcmService = ref.watch(lcmServiceProvider);
    final servoPosition = ref.watch(servoPositionSensorProvider(port));
    final servoMode = ref.watch(servoModeSensorProvider(port));
    final externalCommand = ref.watch(servoCommandSensorProvider(port));

    final isDragging = useState<bool>(false);
    final dangerMode = useState<bool>(false);
    final localAngle = useState<double>(servoPosition ?? 0.0);
    final mountedSlider = useState<bool>(false);
    final lastManualMove = useRef<DateTime?>(null);
    final currentMin = dangerMode.value ? ServoUtils.dangerMinAngle : ServoUtils.minAngle;
    final currentMax = dangerMode.value ? ServoUtils.dangerMaxAngle : ServoUtils.maxAngle;

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        mountedSlider.value = true;
      });
      return null;
    }, []);

    useEffect(() {
      if (servoPosition == null || isDragging.value) return null;
      final last = lastManualMove.value;
      final cooldownExpired = last == null ||
          DateTime.now().difference(last) > const Duration(milliseconds: 1500);
      if (cooldownExpired) {
        localAngle.value = servoPosition;
      }
      return null;
    }, [servoPosition]);

    useEffect(() {
      if (!isDragging.value && externalCommand != null) {
        localAngle.value = externalCommand.clamp(
          dangerMode.value ? ServoUtils.dangerMinAngle : ServoUtils.minAngle,
          dangerMode.value ? ServoUtils.dangerMaxAngle : ServoUtils.maxAngle,
        );
      }
      return null;
    }, [externalCommand]);

    const reliable = PublishOptions(reliable: true);

    void setServoPosition(double degrees) {
      // Position command automatically enables the servo on the STM32 side
      lcmService.publish(
        Channels.servoPositionCommand(port),
        ScalarFT(timestamp: DateTime.now().microsecondsSinceEpoch, value: degrees),
        options: reliable,
      );
    }

    void disableServo() {
      localAngle.value = 0.0;
      // Disable the servo mode (not just set position to 0).
      // Publish on the COMMAND channel so the reader can't echo our
      // request back to itself via its state-feedback publisher.
      lcmService.publish(
        Channels.servoModeCommand(port),
        ScalarI8T(timestamp: DateTime.now().microsecondsSinceEpoch, dir: ServoMode.fullyDisabled.value),
        options: reliable,
      );
    }

    void onSliderChange(double value) {
      isDragging.value = true;
      lastManualMove.value = DateTime.now();
      localAngle.value = value;
      setServoPosition(value);
    }

    void onSliderChangeEnd(double value) {
      isDragging.value = false;
    }

    return Scaffold(
      appBar: createTopBar(
        context,
        sensor.name,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (mountedSlider.value)
                      Positioned(
                        bottom: dangerMode.value ? -60 : -180,
                        child: SleekCircularSlider(
                          key: ValueKey(dangerMode.value),
                          min: currentMin,
                          max: currentMax,
                          initialValue: localAngle.value.clamp(currentMin, currentMax),
                          onChange: onSliderChange,
                          onChangeEnd: onSliderChangeEnd,
                          appearance: CircularSliderAppearance(
                            startAngle: dangerMode.value ? 150 : 180,
                            angleRange: dangerMode.value ? 240 : 180,
                            customWidths: CustomSliderWidths(
                              trackWidth: 75,
                              progressBarWidth: 75,
                              handlerSize: 30,
                            ),
                            customColors: CustomSliderColors(
                              trackColor: dangerMode.value ? Colors.red.shade100 : Colors.grey.shade300,
                              progressBarColor: dangerMode.value ? Colors.red : Colors.blue,
                              dotColor: Colors.white,
                              shadowColor: Colors.grey,
                              shadowMaxOpacity: 0.0,
                            ),
                            size: dangerMode.value ? 360 : 480,
                            animationEnabled: false,
                          ),
                          innerWidget: (value) {
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${value.toStringAsFixed(1)}°',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: dangerMode.value && (value > 180 || value < 0) ? Colors.red : null,
                                  ),
                                ),
                                Text(
                                  dangerMode.value ? 'DANGER' : 'Angle',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: dangerMode.value ? Colors.red : null,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (externalCommand != null)
                                  Text(
                                    'CMD ${externalCommand.toStringAsFixed(1)}°',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.blue[300],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                Text(
                                  'ACT ${servoPosition?.toStringAsFixed(1) ?? "--"}°',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Mode: ${servoMode?.name ?? "N/A"}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 70,
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: disableServo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                          ),
                        ),
                      ),
                      child: const Text(
                        'Fully Disable',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        dangerMode.value = !dangerMode.value;
                        if (!dangerMode.value) {
                          final clamped = localAngle.value.clamp(ServoUtils.minAngle, ServoUtils.maxAngle);
                          if (clamped != localAngle.value) {
                            localAngle.value = clamped;
                            setServoPosition(clamped);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: dangerMode.value ? Colors.orange : Colors.grey.shade700,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            dangerMode.value ? Icons.warning : Icons.warning_outlined,
                            size: 28,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            dangerMode.value ? 'Danger ON' : 'Danger',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
