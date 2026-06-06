import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stpvelox/core/transport/domain/providers.dart';
import 'package:stpvelox/core/transport/models/transport_decoded.dart';
import 'package:stpvelox/core/logging/has_logging.dart';
import 'package:stpvelox/core/service/sensors/sensor_reading_strategy.dart';
import 'package:raccoon_transport/messages/types/vector3f_t.g.dart';
import 'package:raccoon_transport/raccoon_transport.dart';

part 'magnetometer_sensor.g.dart';

class Magnetometer {
  final double x, y, z;
  const Magnetometer(this.x, this.y, this.z);
}

Magnetometer? useMagnetometer(WidgetRef ref) {
  return ref.watch(magnetometerSensorProvider);
}

@riverpod
class MagnetometerSensor extends _$MagnetometerSensor with HasLogger {
  StreamSubscription<TransportDecoded<Vector3fT>>? _subscription;
  Magnetometer? _currentValue;

  @override
  Magnetometer? build() {
    ref.onDispose(_dispose);
    _startSubscription();
    return _currentValue;
  }

  void _startSubscription() {
    final transport = ref.read(transportServiceProvider);
    _subscription =
        transport.subscribeAs<Vector3fT>(Channels.magnetometer, Vector3fT.decode).listen(
              (decoded) {
            _currentValue = Magnetometer(decoded.value.x, decoded.value.y, decoded.value.z);
            state = _currentValue;
          },
          onError: (error) {
            log.severe('Error in magnetometer subscription: $error');
          },
        );
  }

  void _dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}

/// Strategy for reading magnetometer X-axis values
class MagXSensorReadingStrategy extends SensorReadingStrategy {
  @override
  double? readValue(WidgetRef ref, int? port) {
    return useMagnetometer(ref)?.x;
  }
}

/// Strategy for reading magnetometer Y-axis values
class MagYSensorReadingStrategy extends SensorReadingStrategy {
  @override
  double? readValue(WidgetRef ref, int? port) {
    return useMagnetometer(ref)?.y;
  }
}

/// Strategy for reading magnetometer Z-axis values
class MagZSensorReadingStrategy extends SensorReadingStrategy {
  @override
  double? readValue(WidgetRef ref, int? port) {
    return useMagnetometer(ref)?.z;
  }
}
