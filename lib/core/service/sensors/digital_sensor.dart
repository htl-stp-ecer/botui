import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stpvelox/core/transport/domain/providers.dart';
import 'package:stpvelox/core/transport/models/transport_decoded.dart';
import 'package:stpvelox/core/logging/has_logging.dart';
import 'package:stpvelox/core/service/sensors/sensor_reading_strategy.dart';
import 'package:raccoon_transport/messages/types/scalar_i32_t.g.dart';
import 'package:raccoon_transport/raccoon_transport.dart';

part 'digital_sensor.g.dart';

bool? useDigitalValue(WidgetRef ref, int bit) {
  return ref.watch(digitalSensorProvider(bit));
}

@riverpod
class DigitalSensor extends _$DigitalSensor with HasLogger {
  StreamSubscription<TransportDecoded<ScalarI32T>>? _subscription;
  bool? _currentValue;

  @override
  bool? build(int bit) {
    if (bit < 0 || bit >= 11) return null;

    ref.onDispose(_dispose);
    _startSubscription(bit);
    return _currentValue;
  }

  void _startSubscription(int bit) {
    final transport = ref.read(transportServiceProvider);
    _subscription = transport
        .subscribeAs<ScalarI32T>(Channels.digital(bit), ScalarI32T.decode)
        .listen(
      (decoded) {
        _currentValue = decoded.value.value != 0;
        state = _currentValue;
      },
      onError: (error) {
        log.severe('Error in digital $bit subscription: $error');
      },
    );
  }

  void _dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}

/// Strategy for reading digital sensor values
class DigitalSensorReadingStrategy extends SensorReadingStrategy {
  @override
  double? readValue(WidgetRef ref, int? port) {
    return (useDigitalValue(ref, port ?? 0) == true) ? 1.0 : 0.0;
  }
}
