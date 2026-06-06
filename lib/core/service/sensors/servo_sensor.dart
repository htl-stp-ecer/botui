import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stpvelox/core/transport/domain/providers.dart';
import 'package:stpvelox/core/transport/models/transport_decoded.dart';
import 'package:stpvelox/core/logging/has_logging.dart';
import 'package:raccoon_transport/messages/types/scalar_i8_t.g.dart';
import 'package:raccoon_transport/raccoon_transport.dart';

part 'servo_sensor.g.dart';

enum ServoMode {
  fullyDisabled(0),
  disabled(1),
  enabled(2);

  const ServoMode(this.value);

  final int value;

  static ServoMode fromValue(int value) {
    return ServoMode.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ServoMode.disabled,
    );
  }
}

ServoMode? useServoMode(WidgetRef ref, int port) {
  return ref.watch(servoModeSensorProvider(port));
}

@riverpod
class ServoModeSensor extends _$ServoModeSensor with HasLogger {
  StreamSubscription<TransportDecoded<ScalarI8T>>? _subscription;
  ServoMode? _currentValue;

  @override
  ServoMode? build(int port) {
    if (port < 0 || port >= 4) return null;

    ref.onDispose(_dispose);
    _startSubscription(port);
    return _currentValue;
  }

  void _startSubscription(int port) {
    final transport = ref.read(transportServiceProvider);
    _subscription = transport
        .subscribeAs<ScalarI8T>(Channels.servoMode(port), ScalarI8T.decode,
            options: const SubscribeOptions(requestRetained: true))
        .listen(
      (decoded) {
        _currentValue = ServoMode.fromValue(decoded.value.dir);
        state = _currentValue;
      },
      onError: (error) {
        log.severe('Error in servo $port mode subscription: $error');
      },
    );
  }

  void _dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
