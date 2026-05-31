import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stpvelox/core/transport/domain/providers.dart';
import 'package:stpvelox/core/transport/models/transport_decoded.dart';
import 'package:stpvelox/core/logging/has_logging.dart';
import 'package:raccoon_transport/messages/types/scalar_i32_t.g.dart';
import 'package:raccoon_transport/raccoon_transport.dart';

part 'motor_position_sensor.g.dart';

int? useMotorPosition(WidgetRef ref, int port) {
  return ref.watch(motorPositionSensorProvider(port));
}

@riverpod
class MotorPositionSensor extends _$MotorPositionSensor with HasLogger {
  StreamSubscription<TransportDecoded<ScalarI32T>>? _subscription;
  int? _currentValue;

  @override
  int? build(int port) {
    if (port < 0 || port >= 4) return null;

    ref.onDispose(_dispose);
    _startSubscription(port);
    return _currentValue;
  }

  void _startSubscription(int port) {
    final transport = ref.read(transportServiceProvider);
    _subscription = transport
        .subscribeAs<ScalarI32T>(
            Channels.motorPosition(port), ScalarI32T.decode,
            options: const SubscribeOptions(requestRetained: true))
        .listen(
      (decoded) {
        _currentValue = decoded.value.value;
        state = _currentValue;
      },
      onError: (error) {
        log.severe("Error in motor $port position subscription: $error");
      },
    );
  }

  void _dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
