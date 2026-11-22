import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';
import 'package:stpvelox/application/theme/color_theme_provider.dart';
import 'package:stpvelox/core/theme/app_theme.dart';
import 'package:stpvelox/core/service/sensors/bus_servo_sensor.dart';
import 'package:stpvelox/core/service/sensors/servo_sensor.dart';
import 'package:stpvelox/core/transport/domain/providers.dart';
import 'package:raccoon_transport/raccoon_transport.dart';

/// Move speeds offered for position moves, deg/s. `null` = the servo's maximum
/// (plain position_cmd); anything else runs as a servo-native smooth_cmd.
const List<double?> _moveSpeeds = [null, 180, 90, 30];

const double _maxSpinSpeed = 360; // deg/s

/// Feetech STS bus servo (e.g. STS3215) on a port in servo mode 3: full-turn
/// position with live feedback, speed-limited moves, continuous rotation and
/// health readout.
class BusServoPanel extends HookConsumerWidget {
  final int port;

  const BusServoPanel({super.key, required this.port});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(colorThemeProvider);
    final transport = ref.watch(transportServiceProvider);
    final servo = ref.watch(busServoSensorProvider(port));

    final targetAngle = useState<double>(servo.angle ?? 180.0);
    final isDragging = useState<bool>(false);
    final lastManualMove = useRef<DateTime?>(null);
    final lastSent = useRef<DateTime?>(null);
    final moveSpeed = useState<double?>(null);
    final spinSpeed = useState<double>(0);
    final spinning = useState<bool>(false);

    // Follow the measured angle unless the user is (or just was) steering.
    useEffect(() {
      final angle = servo.angle;
      if (angle == null || isDragging.value) return null;
      final last = lastManualMove.value;
      final cooldownExpired = last == null ||
          DateTime.now().difference(last) > const Duration(milliseconds: 1500);
      if (cooldownExpired &&
          (spinning.value || servo.done != BusServoDone.running)) {
        targetAngle.value = angle;
      }
      return null;
    }, [servo.position]);

    int now() => DateTime.now().microsecondsSinceEpoch;

    void moveTo(double degrees) {
      final speed = moveSpeed.value;
      if (speed == null) {
        transport.publish(channels.hardware.servo.cmd.position(port),
            ScalarFT(timestamp: now(), value: degrees));
      } else {
        // Easing 0: the servo holds the speed with a short ramp.
        transport.publish(channels.hardware.servo.cmd.smooth(port),
            Vector3fT(timestamp: now(), x: degrees, y: speed, z: 0));
      }
      lastSent.value = DateTime.now();
      spinning.value = false;
      spinSpeed.value = 0;
    }

    void spin(double degPerSec) {
      transport.publish(channels.hardware.servo.cmd.velocity(port),
          ScalarFT(timestamp: now(), value: degPerSec));
      spinning.value = degPerSec != 0;
    }

    void stopAndHold() {
      final angle = servo.angle ?? targetAngle.value;
      targetAngle.value = angle;
      moveTo(angle);
    }

    void relax() {
      // Re-entering bus mode drops the servo to relaxed (torque off); the
      // port stays a bus port and keeps reporting its position.
      transport.publish(channels.hardware.servo.cmd.mode(port),
          ScalarI8T(timestamp: now(), dir: ServoMode.bus.value));
      spinning.value = false;
      spinSpeed.value = 0;
    }

    void onRingChange(double value) {
      isDragging.value = true;
      lastManualMove.value = DateTime.now();
      targetAngle.value = value;
      // Every command restarts the servo's move; ~20 Hz is plenty while dragging.
      final last = lastSent.value;
      if (last == null ||
          DateTime.now().difference(last) > const Duration(milliseconds: 50)) {
        moveTo(value);
      }
    }

    void onRingChangeEnd(double value) {
      isDragging.value = false;
      lastManualMove.value = DateTime.now();
      moveTo(value);
    }

    final connected = servo.connected;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Center(
              child: _PositionRing(
                target: targetAngle.value,
                servo: servo,
                enabled: connected,
                onChange: onRingChange,
                onChangeEnd: onRingChangeEnd,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatusCard(port: port, servo: servo),
                const SizedBox(height: 10),
                _SectionLabel('Move speed'),
                Row(
                  children: [
                    for (final speed in _moveSpeeds)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: _ToggleButton(
                            label:
                                speed == null ? 'MAX' : '${speed.toInt()}°/s',
                            active: moveSpeed.value == speed,
                            onTap: () => moveSpeed.value = speed,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                _SectionLabel('Spin  ${spinSpeed.value.round()}°/s'),
                Row(
                  children: [
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor:
                              theme.tileColor(TileColor.blue, null),
                          inactiveTrackColor: Colors.grey.shade800,
                          thumbColor: theme.tileColor(TileColor.blue, null),
                          activeTickMarkColor: Colors.transparent,
                          inactiveTickMarkColor: Colors.transparent,
                          overlayColor: theme
                              .tileColor(TileColor.blue, null)
                              .withValues(alpha: 0.2),
                        ),
                        child: Slider(
                          min: -_maxSpinSpeed,
                          max: _maxSpinSpeed,
                          divisions: 24,
                          value: spinSpeed.value,
                          onChanged:
                              connected ? (v) => spinSpeed.value = v : null,
                          onChangeEnd: connected ? spin : null,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 110,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: connected ? stopAndHold : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.tileColor(TileColor.blueGrey, null),
                          foregroundColor: theme.textColor,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('HOLD',
                            style: TextStyle(
                                fontSize: 19, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  height: 64,
                  child: ElevatedButton.icon(
                    onPressed: connected ? relax : null,
                    icon: const Icon(Icons.pan_tool_alt, size: 28),
                    label: const Text('Relax (torque off)',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.danger,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PositionRing extends ConsumerWidget {
  final double target;
  final BusServoState servo;
  final bool enabled;
  final ValueChanged<double> onChange;
  final ValueChanged<double> onChangeEnd;

  const _PositionRing({
    required this.target,
    required this.servo,
    required this.enabled,
    required this.onChange,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(colorThemeProvider);
    final turns = servo.turns;
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest.shortestSide.clamp(200.0, 360.0);
      return IgnorePointer(
        ignoring: !enabled,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: SleekCircularSlider(
            min: 0,
            max: 360,
            initialValue: target.clamp(0, 360),
            onChange: onChange,
            onChangeEnd: onChangeEnd,
            appearance: CircularSliderAppearance(
              startAngle: 270,
              angleRange: 360,
              size: size,
              animationEnabled: false,
              customWidths: CustomSliderWidths(
                  trackWidth: 46, progressBarWidth: 46, handlerSize: 24),
              customColors: CustomSliderColors(
                trackColor: Colors.grey.shade800,
                progressBarColor: theme.tileColor(TileColor.blue, null),
                dotColor: Colors.white,
                shadowColor: Colors.grey,
                shadowMaxOpacity: 0.0,
              ),
            ),
            innerWidget: (value) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${value.toStringAsFixed(1)}°',
                    style: const TextStyle(
                        fontSize: 34, fontWeight: FontWeight.bold)),
                const Text('Target',
                    style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 10),
                Text(
                  'ACT ${servo.angle?.toStringAsFixed(1) ?? "--"}°',
                  style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[300],
                      fontWeight: FontWeight.w600),
                ),
                if (turns != null && turns != 0)
                  Text('turn ${turns > 0 ? "+" : ""}$turns',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                const SizedBox(height: 8),
                _DoneChip(done: servo.done),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _DoneChip extends ConsumerWidget {
  final BusServoDone? done;

  const _DoneChip({required this.done});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(colorThemeProvider);
    final (icon, label, color) = switch (done) {
      BusServoDone.reached => (Icons.check_circle, 'In position', theme.tileColor(TileColor.green, null)),
      BusServoDone.stalled => (Icons.warning_amber, 'Blocked', theme.tileColor(TileColor.orange, null)),
      BusServoDone.running => (Icons.sync, 'Moving', theme.tileColor(TileColor.blue, null)),
      null => (Icons.help_outline, '--', Colors.grey),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 14, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _StatusCard extends ConsumerWidget {
  final int port;
  final BusServoState servo;

  const _StatusCard({required this.port, required this.servo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(colorThemeProvider);
    if (!servo.connected) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.grey[900], borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                servo.status == null
                    ? 'Waiting for the bus servo on port $port...'
                    : 'No bus servo answers on port $port. Check cable and battery.',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }

    final load = servo.load ?? 0;
    final errors = servo.errors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.grey[900], borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Metric(
                  label: 'Voltage',
                  value: '${servo.voltage?.toStringAsFixed(1) ?? "--"} V',
                  warn: (servo.voltage ?? 99) < 5.0),
              _Metric(
                  label: 'Temp',
                  value: '${servo.temperature?.toStringAsFixed(0) ?? "--"} °C',
                  warn: (servo.temperature ?? 0) >= 60),
              _Metric(
                  label: 'Speed',
                  value: '${servo.speed?.toStringAsFixed(0) ?? "--"} °/s'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                  width: 48,
                  child: Text('Load',
                      style: TextStyle(fontSize: 13, color: Colors.grey[400]))),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (load.abs() / 100).clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: Colors.grey[800],
                    color: load.abs() > 80
                        ? theme.danger
                        : theme.tileColor(TileColor.green, null),
                  ),
                ),
              ),
              SizedBox(
                width: 60,
                child: Text('${load.toStringAsFixed(0)} %',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),
          if (errors.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final e in errors)
                  Chip(
                    label: Text(e, style: const TextStyle(fontSize: 12)),
                    backgroundColor: theme.danger,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends ConsumerWidget {
  final String label;
  final String value;
  final bool warn;

  const _Metric({required this.label, required this.value, this.warn = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(colorThemeProvider);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[400])),
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: warn ? theme.tileColor(TileColor.orange, null) : null)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(text,
          style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
              fontWeight: FontWeight.w600)),
    );
  }
}

class _ToggleButton extends ConsumerWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ToggleButton(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(colorThemeProvider);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? theme.tileColor(TileColor.blue, null)
              : Colors.grey[850],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: active ? theme.textColor : Colors.grey[400],
          ),
        ),
      ),
    );
  }
}
