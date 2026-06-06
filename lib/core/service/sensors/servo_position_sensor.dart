import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stpvelox/core/transport/domain/providers.dart';
import 'package:stpvelox/core/transport/models/transport_decoded.dart';
import 'package:stpvelox/core/logging/has_logging.dart';
import 'package:raccoon_transport/raccoon_transport.dart';

part 'servo_position_sensor.g.dart';

double? useServoPosition(WidgetRef ref, int port) {
  return ref.watch(servoPositionSensorProvider(port));
}

@riverpod
class ServoPositionSensor extends _$ServoPositionSensor with HasLogger {
  StreamSubscription<TransportDecoded<ScalarFT>>? _subscription;
  double? _currentValue;

  @override
  double? build(int port) {
    if (port < 0 || port >= 4) return null;

    ref.onDispose(_dispose);
    _startSubscription(port);
    return _currentValue;
  }

  void _startSubscription(int port) {
    final transport = ref.read(transportServiceProvider);
    _subscription = transport
        .subscribeAs<ScalarFT>(
            Channels.servoPosition(port), ScalarFT.decode,
            options: const SubscribeOptions(requestRetained: true))
        .listen(
      (decoded) {
        _currentValue = decoded.value.value;
        state = _currentValue;
      },
      onError: (error) {
        log.severe('Error in servo $port position subscription: $error');
      },
    );
  }

  void _dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
