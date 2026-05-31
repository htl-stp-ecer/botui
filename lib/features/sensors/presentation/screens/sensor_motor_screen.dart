import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:stpvelox/core/transport/domain/providers.dart';
import 'package:stpvelox/core/service/sensors/back_emf_sensor.dart';
import 'package:stpvelox/core/service/sensors/motor_done_sensor.dart';
import 'package:stpvelox/core/service/sensors/motor_position_sensor.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/sensors/domain/entities/sensor.dart';
import 'package:stpvelox/features/sensors/presentation/services/sensor_data_processor.dart';
import 'package:stpvelox/features/sensors/presentation/widgets/motor_graph_view.dart';
import 'package:stpvelox/features/sensors/presentation/widgets/motor_mode_sidebar.dart';
import 'package:stpvelox/features/sensors/presentation/widgets/motor_position_view.dart';
import 'package:stpvelox/features/sensors/presentation/widgets/motor_radial_slider.dart';
import 'package:raccoon_transport/messages/types/scalar_i32_t.g.dart';
import 'package:raccoon_transport/messages/types/vector3f_t.g.dart';
import 'package:raccoon_transport/raccoon_transport.dart';

class SensorMotorScreen extends HookConsumerWidget {
  final int port;
  final Sensor sensor;

  const SensorMotorScreen({
    super.key,
    required this.port,
    required this.sensor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transport = ref.watch(transportServiceProvider);
    final backEmf = ref.watch(backEmfSensorProvider(port));
    final motorPosition = ref.watch(motorPositionSensorProvider(port));
    final motorDone = useMotorDone(ref, port);

    final mode = useState(MotorMode.power);

    // Power state
    final powerValue = useState<double>(0.0);
    final sliderMounted = useState(false);

    // Velocity state
    final velValue = useState<double>(0.0);
    final targetVelocity = useState<int?>(null);

    // Position state
    final posInput = useState('');
    final posIsNegative = useState(false);
    final posVelocity = useState(1000);
    final isRelative = useState(false);

    // Graph state
    final graphMode = useState(MotorGraphMode.bemf);
    const maxPoints = 250;
    final processor = useMemoized(
        () => SensorDataProcessor(maxPoints: maxPoints, movingAvgWindow: 10));
    final bemfData = useState<List<double>>([]);
    final bemfMovingAvg = useState<List<double>>([]);
    final positionData = useState<List<double>>([]);
    final targetVelData = useState<List<double>>([]);
    final sampleCount = useState(0);
    final lastBemf = useState<double>(0);
    final lastPosition = useState<double>(0);

    // --- Effects ---

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        sliderMounted.value = true;
      });
      return null;
    }, []);

    void appendSample(double bemf, double pos) {
      bemfData.value = processor.appendToRawData(bemfData.value, bemf);
      bemfMovingAvg.value =
          processor.appendToMovingAverage(bemfMovingAvg.value, bemfData.value);

      final pList = List<double>.from(positionData.value)..add(pos);
      if (pList.length > maxPoints) pList.removeAt(0);
      positionData.value = pList;

      final tv = targetVelocity.value;
      final tList = List<double>.from(targetVelData.value)
        ..add(tv?.toDouble() ?? double.nan);
      if (tList.length > maxPoints) tList.removeAt(0);
      targetVelData.value = tList;

      sampleCount.value = sampleCount.value + 1;
    }

    // Store latest BEMF and position values when they change
    useEffect(() {
      if (backEmf != null) {
        lastBemf.value = backEmf.toDouble();
      }
      return null;
    }, [backEmf]);

    useEffect(() {
      if (motorPosition != null) {
        lastPosition.value = motorPosition.toDouble();
      }
      return null;
    }, [motorPosition]);

    // Timer drives the graph at 10Hz, using the latest known values
    useEffect(() {
      final timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        appendSample(lastBemf.value, lastPosition.value);
      });
      return timer.cancel;
    }, const []);

    // --- Commands ---

    const reliable = PublishOptions(reliable: true);

    // Throttle continuous commands to ~30Hz to avoid flooding the bus
    final lastPowerSend = useRef<DateTime>(DateTime(0));
    final lastVelSend = useRef<DateTime>(DateTime(0));
    const throttleInterval = Duration(milliseconds: 33); // ~30Hz

    // Power and velocity are continuous control loops — plain delivery
    // matches the stm32_data_reader's non-reliable subscription.
    void sendPower(int p) {
      final now = DateTime.now();
      if (now.difference(lastPowerSend.value) < throttleInterval) return;
      lastPowerSend.value = now;
      transport.publish(
          Channels.motorPowerCommand(port),
          ScalarI32T(
              timestamp: now.microsecondsSinceEpoch, value: p));
    }

    void sendVelocity(int v) {
      final now = DateTime.now();
      if (now.difference(lastVelSend.value) < throttleInterval) return;
      lastVelSend.value = now;
      targetVelocity.value = v;
      transport.publish(
          Channels.motorVelocityCommand(port),
          ScalarI32T(
              timestamp: now.microsecondsSinceEpoch, value: v));
    }

    void sendPositionCmd(int velocity, int goal) => transport.publish(
        Channels.motorPositionCommand(port),
        Vector3fT(
            timestamp: DateTime.now().microsecondsSinceEpoch,
            x: velocity.toDouble(),
            y: goal.toDouble(),
            z: 0),
        options: reliable);

    void sendRelativeCmd(int velocity, int delta) => transport.publish(
        Channels.motorRelativeCommand(port),
        Vector3fT(
            timestamp: DateTime.now().microsecondsSinceEpoch,
            x: velocity.toDouble(),
            y: delta.toDouble(),
            z: 0),
        options: reliable);

    void resetPosition() => transport.publish(
        Channels.motorPositionResetCommand(port),
        ScalarI32T(
            timestamp: DateTime.now().microsecondsSinceEpoch, value: 1),
        options: reliable);

    void resetUiState() {
      powerValue.value = 0;
      velValue.value = 0;
      targetVelocity.value = null;
    }

    // Passive brake: shorts motor windings (MotorControlMode::PassiveBrake)
    void brakeMotor() {
      resetUiState();
      transport.publish(
          Channels.motorModeCommand(port),
          ScalarI32T(
              timestamp: DateTime.now().microsecondsSinceEpoch, value: 1),
          options: reliable);
    }

    // Active brake: PID holds velocity at 0 (uses current)
    void stopMotor() {
      resetUiState();
      sendVelocity(0);
    }

    // Off: no current, motor spins freely (MotorControlMode::Off)
    void coastMotor() {
      resetUiState();
      transport.publish(
          Channels.motorModeCommand(port),
          ScalarI32T(
              timestamp: DateTime.now().microsecondsSinceEpoch, value: 0),
          options: reliable);
    }

    // --- Keypad ---

    int calcPosInputValue() {
      final raw = int.tryParse(posInput.value) ?? 0;
      return posIsNegative.value ? -raw : raw;
    }

    void onKeyPress(String key) {
      if (key == 'back') {
        if (posInput.value.isNotEmpty) {
          posInput.value =
              posInput.value.substring(0, posInput.value.length - 1);
        }
      } else if (key == '.') {
        // ignore decimal for integer input
      } else {
        if (posInput.value.length < 7) posInput.value += key;
      }
    }

    void submitPosition() {
      final pos = calcPosInputValue();
      if (posInput.value.isEmpty) return;
      if (isRelative.value) {
        sendRelativeCmd(posVelocity.value, pos);
      } else {
        sendPositionCmd(posVelocity.value, pos);
      }
    }

    // --- Layout ---

    return Scaffold(
      appBar: createTopBar(context, sensor.name),
      body: Column(
        children: [
          // Main area: sidebar + content
          Expanded(
            child: Row(
              children: [
                MotorModeSidebar(
                  selected: mode.value,
                  onSelect: (m) => mode.value = m,
                ),
                Container(width: 1, color: Colors.grey[800]),
                Expanded(
                  child: switch (mode.value) {
                    MotorMode.power => MotorRadialSlider(
                        mounted: sliderMounted.value,
                        value: powerValue.value,
                        min: -100,
                        max: 100,
                        label: 'Power',
                        valueStr: powerValue.value.toInt().toString(),
                        onChange: (v) {
                          powerValue.value = v;
                          sendPower(v.toInt());
                        },
                        onChangeEnd: (_) {},
                      ),
                    MotorMode.velocity => MotorRadialSlider(
                        mounted: sliderMounted.value,
                        value: velValue.value,
                        min: -1500,
                        max: 1500,
                        label: 'Velocity',
                        valueStr: velValue.value.toInt().toString(),
                        onChange: (v) {
                          velValue.value = v;
                          sendVelocity(v.toInt());
                        },
                        onChangeEnd: (_) {},
                      ),
                    MotorMode.position => MotorPositionView(
                        posDisplay:
                            '${posIsNegative.value && posInput.value.isNotEmpty ? "-" : ""}${posInput.value.isEmpty ? "0" : posInput.value}',
                        velocity: posVelocity.value,
                        isRelative: isRelative.value,
                        motorPosition: motorPosition,
                        motorDone: motorDone,
                        onKeyPress: onKeyPress,
                        onToggleSign: () =>
                            posIsNegative.value = !posIsNegative.value,
                        onClear: () {
                          posInput.value = '';
                          posIsNegative.value = false;
                        },
                        onVelocityUp: () => posVelocity.value =
                            (posVelocity.value + 100).clamp(0, 5000),
                        onVelocityDown: () => posVelocity.value =
                            (posVelocity.value - 100).clamp(0, 5000),
                        onToggleRelative: (v) => isRelative.value = v,
                        onSubmit: submitPosition,
                      ),
                    MotorMode.graph => MotorGraphView(
                        bemfData: bemfData.value,
                        movingAvg: bemfMovingAvg.value,
                        positionData: positionData.value,
                        targetVelocity: targetVelData.value,
                        maxPoints: maxPoints,
                        totalSamples: sampleCount.value,
                        mode: graphMode.value,
                        onModeChanged: (m) => graphMode.value = m,
                      ),
                  },
                ),
              ],
            ),
          ),
          // Bottom bar
          Container(
            color: Colors.grey[900],
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Stats row (hidden in graph mode)
                if (mode.value != MotorMode.graph)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _BottomStat('BEMF', '${backEmf ?? "--"}'),
                        _BottomStat('POS', '${motorPosition ?? "--"}'),
                        _DoneChip(motorDone),
                      ],
                    ),
                  ),
                // Action buttons
                Row(
                  children: [
                    // BRAKE: passive brake (shorts windings)
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: brakeMotor,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[700],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            elevation: 4,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.stop_circle, size: 24),
                              SizedBox(width: 6),
                              Text('BRAKE',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // STOP: active brake (PID holds vel=0)
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: stopMotor,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[800],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('HOLD',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // OFF: coast (no current)
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: coastMotor,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[800],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('OFF',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Reset position counter
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: resetPosition,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.restart_alt, size: 20),
                            Text('POS',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bottom bar helper widgets ───────────────────────────────

class _BottomStat extends StatelessWidget {
  final String label, value;
  const _BottomStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ',
            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        Text(value,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: Colors.white)),
      ],
    );
  }
}

class _DoneChip extends StatelessWidget {
  final bool? done;
  const _DoneChip(this.done);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done == true ? Colors.green[700] : Colors.grey[800],
        border: Border.all(color: Colors.grey[600]!, width: 1.5),
      ),
      child: Center(
        child: done == null
            ? Text('?',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]))
            : done!
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : const Icon(Icons.close, size: 16, color: Colors.grey),
      ),
    );
  }
}
