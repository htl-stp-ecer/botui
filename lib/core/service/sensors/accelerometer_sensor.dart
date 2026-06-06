import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stpvelox/core/transport/domain/providers.dart';
import 'package:stpvelox/core/transport/models/transport_decoded.dart';
import 'package:stpvelox/core/logging/has_logging.dart';
import 'package:stpvelox/core/service/sensors/sensor_reading_strategy.dart';
import 'package:raccoon_transport/messages/types/vector3f_t.g.dart';
import 'package:raccoon_transport/raccoon_transport.dart';

part 'accelerometer_sensor.g.dart';

class Accel {
  final double x, y, z;
  const Accel(this.x, this.y, this.z);
}

Accel? useAccelerometer(WidgetRef ref) {
  return ref.watch(accelerometerSensorProvider);
}

@riverpod
class AccelerometerSensor extends _$AccelerometerSensor with HasLogger {
  StreamSubscription<TransportDecoded<Vector3fT>>? _subscription;
  Accel? _currentValue;

  @override
  Accel? build() {
    ref.onDispose(_dispose);
    _startSubscription();
    return _currentValue;
  }

  void _startSubscription() {
    final transport = ref.read(transportServiceProvider);
    _subscription = transport
        .subscribeAs<Vector3fT>(Channels.accelerometer, Vector3fT.decode)
        .listen(
          (decoded) {
        _currentValue = Accel(decoded.value.x, decoded.value.y, decoded.value.z);
        state = _currentValue;
      },
      onError: (error) {
        log.severe('Error in accelerometer subscription: $error');
      },
    );
  }

  void _dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}

/// Strategy for reading accelerometer X-axis values
class AccelXSensorReadingStrategy extends SensorReadingStrategy {
  @override
  double? readValue(WidgetRef ref, int? port) {
    return useAccelerometer(ref)?.x;
  }
}

/// Strategy for reading accelerometer Y-axis values
class AccelYSensorReadingStrategy extends SensorReadingStrategy {
  @override
  double? readValue(WidgetRef ref, int? port) {
    return useAccelerometer(ref)?.y;
  }
}

/// Strategy for reading accelerometer Z-axis values
class AccelZSensorReadingStrategy extends SensorReadingStrategy {
  @override
  double? readValue(WidgetRef ref, int? port) {
    return useAccelerometer(ref)?.z;
  }
}
