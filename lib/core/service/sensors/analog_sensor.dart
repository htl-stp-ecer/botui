import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stpvelox/core/transport/domain/providers.dart';
import 'package:stpvelox/core/transport/models/transport_decoded.dart';
import 'package:stpvelox/core/logging/has_logging.dart';
import 'package:stpvelox/core/service/sensors/sensor_reading_strategy.dart';
import 'package:raccoon_transport/messages/types/scalar_i32_t.g.dart';
import 'package:raccoon_transport/raccoon_transport.dart';

part 'analog_sensor.g.dart';

int? useAnalogValue(WidgetRef ref, int port) {
  return ref.watch(analogSensorProvider(port));
}

@riverpod
class AnalogSensor extends _$AnalogSensor with HasLogger {
  StreamSubscription<TransportDecoded<ScalarI32T>>? _subscription;
  int? _currentValue;

  @override
  int? build(int port) {
    if (port < 0 || port >= 6) return null;

    ref.onDispose(_dispose);
    _startSubscription(port);
    return _currentValue;
  }

  void _startSubscription(int port) {
    final transport = ref.read(transportServiceProvider);
    _subscription = transport
        .subscribeAs<ScalarI32T>(Channels.analog(port), ScalarI32T.decode)
        .listen(
      (decoded) {
        _currentValue = decoded.value.value;
        state = _currentValue;
      },
      onError: (error) {
        log.severe('Error in analog $port subscription: $error');
      },
    );
  }

  void _dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}

/// Strategy for reading analog sensor values
class AnalogSensorReadingStrategy extends SensorReadingStrategy {
  @override
  double? readValue(WidgetRef ref, int? port) {
    return useAnalogValue(ref, port ?? 0)?.toDouble();
  }
}
