import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stpvelox/core/transport/domain/providers.dart';
import 'package:stpvelox/core/transport/models/transport_decoded.dart';
import 'package:stpvelox/core/logging/has_logging.dart';
import 'package:stpvelox/core/service/sensors/sensor_reading_strategy.dart';
import 'package:raccoon_transport/messages/types/vector3f_t.g.dart';
import 'package:raccoon_transport/raccoon_transport.dart';

part 'gyro_sensor.g.dart';

class Gyro {
  final double x, y, z;
  const Gyro(this.x, this.y, this.z);
}

Gyro? useGyro(WidgetRef ref) {
  return ref.watch(gyroSensorProvider);
}

@riverpod
class GyroSensor extends _$GyroSensor with HasLogger {
  StreamSubscription<TransportDecoded<Vector3fT>>? _subscription;
  Gyro? _currentValue;

  @override
  Gyro? build() {
    ref.onDispose(_dispose);
    _startSubscription();
    return _currentValue;
  }

  void _startSubscription() {
    final transport = ref.read(transportServiceProvider);
    _subscription = transport
        .subscribeAs<Vector3fT>(Channels.gyro, Vector3fT.decode)
        .listen(
          (decoded) {
        _currentValue = Gyro(decoded.value.x, decoded.value.y, decoded.value.z);
        state = _currentValue;
      },
      onError: (error) {
        log.severe('Error in gyro subscription: $error');
      },
    );
  }

  void _dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}

/// Strategy for reading gyroscope X-axis values
class GyroXSensorReadingStrategy extends SensorReadingStrategy {
  @override
  double? readValue(WidgetRef ref, int? port) {
    return useGyro(ref)?.x;
  }
}

/// Strategy for reading gyroscope Y-axis values
class GyroYSensorReadingStrategy extends SensorReadingStrategy {
  @override
  double? readValue(WidgetRef ref, int? port) {
    return useGyro(ref)?.y;
  }
}

/// Strategy for reading gyroscope Z-axis values
class GyroZSensorReadingStrategy extends SensorReadingStrategy {
  @override
  double? readValue(WidgetRef ref, int? port) {
    return useGyro(ref)?.z;
  }
}
