import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stpvelox/core/transport/domain/providers.dart';
import 'package:stpvelox/core/transport/models/transport_decoded.dart';
import 'package:stpvelox/core/logging/has_logging.dart';
import 'package:raccoon_transport/messages/types/scalar_i8_t.g.dart';
import 'package:raccoon_transport/raccoon_transport.dart';

part 'imu_accuracy_sensor.g.dart';

class ImuAccuracy {
  /// Accuracy values: 0 = unreliable, 1 = low, 2 = medium, 3 = high
  /// null means no data received yet
  final int? gyro;
  final int? accel;
  final int? mag;
  final int? quaternion;

  const ImuAccuracy({
    this.gyro,
    this.accel,
    this.mag,
    this.quaternion,
  });

  ImuAccuracy copyWith({
    int? gyro,
    int? accel,
    int? mag,
    int? quaternion,
  }) {
    return ImuAccuracy(
      gyro: gyro ?? this.gyro,
      accel: accel ?? this.accel,
      mag: mag ?? this.mag,
      quaternion: quaternion ?? this.quaternion,
    );
  }
}

ImuAccuracy useImuAccuracy(WidgetRef ref) {
  return ref.watch(imuAccuracySensorProvider);
}

@Riverpod(keepAlive: true)
class ImuAccuracySensor extends _$ImuAccuracySensor with HasLogger {
  StreamSubscription<TransportDecoded<ScalarI8T>>? _gyroSub;
  StreamSubscription<TransportDecoded<ScalarI8T>>? _accelSub;
  StreamSubscription<TransportDecoded<ScalarI8T>>? _magSub;
  StreamSubscription<TransportDecoded<ScalarI8T>>? _quatSub;

  ImuAccuracy _currentValue = const ImuAccuracy();

  @override
  ImuAccuracy build() {
    ref.onDispose(_dispose);
    _startSubscriptions();
    return _currentValue;
  }

  void _startSubscriptions() {
    final transport = ref.read(transportServiceProvider);
    log.info('Starting IMU accuracy subscriptions');

    _gyroSub = transport
        .subscribeAs<ScalarI8T>(Channels.gyroAccuracy, ScalarI8T.decode,
            options: const SubscribeOptions(requestRetained: true))
        .listen(
      (decoded) {
        if (decoded.value.dir != _currentValue.gyro) {
          log.info('Gyro accuracy changed: ${decoded.value.dir}');
          _currentValue = _currentValue.copyWith(gyro: decoded.value.dir);
          state = _currentValue;
        }
      },
      onError: (error) {
        log.severe('Error in gyro accuracy subscription: $error');
      },
    );

    _accelSub = transport
        .subscribeAs<ScalarI8T>(Channels.accelAccuracy, ScalarI8T.decode,
            options: const SubscribeOptions(requestRetained: true))
        .listen(
      (decoded) {
        if (decoded.value.dir != _currentValue.accel) {
          log.info('Accel accuracy changed: ${decoded.value.dir}');
          _currentValue = _currentValue.copyWith(accel: decoded.value.dir);
          state = _currentValue;
        }
      },
      onError: (error) {
        log.severe('Error in accel accuracy subscription: $error');
      },
    );

    _magSub = transport
        .subscribeAs<ScalarI8T>(Channels.compassAccuracy, ScalarI8T.decode,
            options: const SubscribeOptions(requestRetained: true))
        .listen(
      (decoded) {
        if (decoded.value.dir != _currentValue.mag) {
          log.info('Mag accuracy changed: ${decoded.value.dir}');
          _currentValue = _currentValue.copyWith(mag: decoded.value.dir);
          state = _currentValue;
        }
      },
      onError: (error) {
        log.severe('Error in mag accuracy subscription: $error');
      },
    );

    _quatSub = transport
        .subscribeAs<ScalarI8T>(
            Channels.quaternionAccuracy, ScalarI8T.decode,
            options: const SubscribeOptions(requestRetained: true))
        .listen(
      (decoded) {
        if (decoded.value.dir != _currentValue.quaternion) {
          log.info('Quaternion accuracy changed: ${decoded.value.dir}');
          _currentValue = _currentValue.copyWith(quaternion: decoded.value.dir);
          state = _currentValue;
        }
      },
      onError: (error) {
        log.severe('Error in quaternion accuracy subscription: $error');
      },
    );
  }

  void _dispose() {
    _gyroSub?.cancel();
    _accelSub?.cancel();
    _magSub?.cancel();
    _quatSub?.cancel();
    _gyroSub = null;
    _accelSub = null;
    _magSub = null;
    _quatSub = null;
  }
}
