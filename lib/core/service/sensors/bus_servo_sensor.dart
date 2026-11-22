import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stpvelox/core/transport/domain/providers.dart';
import 'package:stpvelox/core/transport/models/transport_decoded.dart';
import 'package:stpvelox/core/logging/has_logging.dart';
import 'package:raccoon_transport/raccoon_transport.dart';

part 'bus_servo_sensor.g.dart';

/// State of the latest bus servo command, from `raccoon/servo/{port}/done`.
enum BusServoDone {
  running(0),
  reached(1),
  stalled(2);

  const BusServoDone(this.value);

  final int value;

  static BusServoDone fromValue(int value) {
    return BusServoDone.values.firstWhere(
      (e) => e.value == value,
      orElse: () => BusServoDone.running,
    );
  }
}

/// Feetech STS bus servo (e.g. STS3215) on a port in servo mode 3, as
/// reported by the reader on the feedback / health / done channels.
class BusServoState {
  /// Multi-turn position in degrees (keeps counting past 360).
  final double? position;
  final double? speed; // deg/s
  final double? load; // percent of max torque, signed
  final double? voltage; // V
  final double? temperature; // deg C
  /// Servo error bits, or -1 while no servo answers on the port.
  final int? status;
  final BusServoDone? done;

  const BusServoState({
    this.position,
    this.speed,
    this.load,
    this.voltage,
    this.temperature,
    this.status,
    this.done,
  });

  static const int statusVoltage = 0x01;
  static const int statusSensor = 0x02;
  static const int statusOverheat = 0x04;
  static const int statusCurrent = 0x08;
  static const int statusAngle = 0x10;
  static const int statusOverload = 0x20;

  bool get connected => status != null && status! >= 0;

  /// Position within one turn, 0..360.
  double? get angle {
    final p = position;
    if (p == null) return null;
    final a = p % 360.0;
    return a < 0 ? a + 360.0 : a;
  }

  /// Completed turns since the servo connected (negative when turned back).
  int? get turns => position == null ? null : (position! / 360.0).floor();

  List<String> get errors {
    final s = status;
    if (s == null || s <= 0) return const [];
    return [
      if (s & statusVoltage != 0) 'Voltage',
      if (s & statusSensor != 0) 'Sensor',
      if (s & statusOverheat != 0) 'Overheat',
      if (s & statusCurrent != 0) 'Current',
      if (s & statusAngle != 0) 'Angle',
      if (s & statusOverload != 0) 'Overload',
    ];
  }

  BusServoState copyWith({
    double? position,
    double? speed,
    double? load,
    double? voltage,
    double? temperature,
    int? status,
    BusServoDone? done,
  }) {
    return BusServoState(
      position: position ?? this.position,
      speed: speed ?? this.speed,
      load: load ?? this.load,
      voltage: voltage ?? this.voltage,
      temperature: temperature ?? this.temperature,
      status: status ?? this.status,
      done: done ?? this.done,
    );
  }
}

BusServoState useBusServo(WidgetRef ref, int port) {
  return ref.watch(busServoSensorProvider(port));
}

@riverpod
class BusServoSensor extends _$BusServoSensor with HasLogger {
  StreamSubscription<TransportDecoded<Vector3fT>>? _feedbackSub;
  StreamSubscription<TransportDecoded<Vector3fT>>? _healthSub;
  StreamSubscription<TransportDecoded<ScalarI32T>>? _doneSub;

  @override
  BusServoState build(int port) {
    if (port < 0 || port >= 4) return const BusServoState();
    ref.onDispose(_dispose);
    _startSubscriptions(port);
    return const BusServoState();
  }

  void _startSubscriptions(int port) {
    final transport = ref.read(transportServiceProvider);

    _feedbackSub = transport
        .subscribeAs<Vector3fT>(channels.hardware.servo.state.feedback(port), Vector3fT.decode)
        .listen(
      (decoded) {
        final m = decoded.value;
        state = state.copyWith(position: m.x, speed: m.y, load: m.z);
      },
      onError: (e) =>
          log.severe('Error in servo $port feedback subscription: $e'),
    );

    _healthSub = transport
        .subscribeAs<Vector3fT>(channels.hardware.servo.state.health(port), Vector3fT.decode)
        .listen(
      (decoded) {
        final m = decoded.value;
        state =
            state.copyWith(voltage: m.x, temperature: m.y, status: m.z.round());
      },
      onError: (e) =>
          log.severe('Error in servo $port health subscription: $e'),
    );

    _doneSub = transport
        .subscribeAs<ScalarI32T>(channels.hardware.servo.state.done(port), ScalarI32T.decode)
        .listen(
      (decoded) {
        state =
            state.copyWith(done: BusServoDone.fromValue(decoded.value.value));
      },
      onError: (e) => log.severe('Error in servo $port done subscription: $e'),
    );
  }

  void _dispose() {
    _feedbackSub?.cancel();
    _feedbackSub = null;
    _healthSub?.cancel();
    _healthSub = null;
    _doneSub?.cancel();
    _doneSub = null;
  }
}
