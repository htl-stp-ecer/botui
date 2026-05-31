import 'dart:async';
import 'dart:math' as math;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:raccoon_transport/messages/types/quaternion_t.g.dart';
import 'package:raccoon_transport/raccoon_transport.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stpvelox/core/transport/domain/providers.dart';
import 'package:stpvelox/core/transport/models/transport_decoded.dart';
import 'package:stpvelox/core/logging/has_logging.dart';
import 'package:stpvelox/core/service/sensors/sensor_reading_strategy.dart';

part 'quaternion_sensor.g.dart';

class Quaternion {
  final double w, x, y, z;
  const Quaternion(this.w, this.x, this.y, this.z);

  /// Returns the quaternion as Euler angles (roll, pitch, yaw) in degrees
  ({double roll, double pitch, double yaw}) toEulerAngles() {
    // Roll (x-axis rotation)
    final sinrCosp = 2 * (w * x + y * z);
    final cosrCosp = 1 - 2 * (x * x + y * y);
    final roll = math.atan2(sinrCosp, cosrCosp) * 180 / math.pi;

    // Pitch (y-axis rotation)
    final sinp = 2 * (w * y - z * x);
    double pitch;
    if (sinp.abs() >= 1) {
      pitch = (sinp >= 0 ? 90.0 : -90.0);
    } else {
      pitch = math.asin(sinp) * 180 / math.pi;
    }

    // Yaw (z-axis rotation)
    final sinyCosp = 2 * (w * z + x * y);
    final cosyCosp = 1 - 2 * (y * y + z * z);
    final yaw = math.atan2(sinyCosp, cosyCosp) * 180 / math.pi;

    return (roll: roll, pitch: pitch, yaw: yaw);
  }
}

Quaternion? useQuaternion(WidgetRef ref) {
  return ref.watch(quaternionSensorProvider);
}

@riverpod
class QuaternionSensor extends _$QuaternionSensor with HasLogger {
  StreamSubscription<TransportDecoded<QuaternionT>>? _subscription;
  Quaternion? _currentValue;

  @override
  Quaternion? build() {
    ref.onDispose(_dispose);
    _startSubscription();
    return _currentValue;
  }

  void _startSubscription() {
    final transportService = ref.read(transportServiceProvider);
    _subscription = transportService
        .subscribeAs<QuaternionT>(Channels.orientation, QuaternionT.decode)
        .listen(
      (decoded) {
        log.fine('Received quaternion: w=${decoded.value.w}, x=${decoded.value.x}, y=${decoded.value.y}, z=${decoded.value.z}');
        _currentValue = Quaternion(
          decoded.value.w,
          decoded.value.x,
          decoded.value.y,
          decoded.value.z,
        );
        state = _currentValue;
      },
      onError: (error, stackTrace) {
        log.severe('Error in quaternion subscription: $error', stackTrace);
      },
    );
  }

  void _dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}

/// Strategy for reading quaternion W component
class QuaternionWSensorReadingStrategy extends SensorReadingStrategy {
  @override
  double? readValue(WidgetRef ref, int? port) {
    return useQuaternion(ref)?.w;
  }
}

/// Strategy for reading quaternion X component
class QuaternionXSensorReadingStrategy extends SensorReadingStrategy {
  @override
  double? readValue(WidgetRef ref, int? port) {
    return useQuaternion(ref)?.x;
  }
}

/// Strategy for reading quaternion Y component
class QuaternionYSensorReadingStrategy extends SensorReadingStrategy {
  @override
  double? readValue(WidgetRef ref, int? port) {
    return useQuaternion(ref)?.y;
  }
}

/// Strategy for reading quaternion Z component
class QuaternionZSensorReadingStrategy extends SensorReadingStrategy {
  @override
  double? readValue(WidgetRef ref, int? port) {
    return useQuaternion(ref)?.z;
  }
}
