import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stpvelox/core/transport/domain/providers.dart';
import 'package:stpvelox/core/transport/models/transport_decoded.dart';
import 'package:stpvelox/core/logging/has_logging.dart';
import 'package:stpvelox/core/service/sensors/sensor_reading_strategy.dart';
import 'package:raccoon_transport/messages/types/scalar_f_t.g.dart';
import 'package:raccoon_transport/raccoon_transport.dart';

part 'heading_sensor.g.dart';

double? useHeading(WidgetRef ref) {
  return ref.watch(headingSensorProvider);
}

@riverpod
class HeadingSensor extends _$HeadingSensor with HasLogger {
  StreamSubscription<TransportDecoded<ScalarFT>>? _subscription;
  double? _currentValue;

  @override
  double? build() {
    ref.onDispose(_dispose);
    _startSubscription();
    return _currentValue;
  }

  void _startSubscription() {
    final transport = ref.read(transportServiceProvider);
    _subscription = transport
        .subscribeAs<ScalarFT>(Channels.heading, ScalarFT.decode,
            options: const SubscribeOptions(requestRetained: true))
        .listen(
              (decoded) {
            _currentValue = decoded.value.value;
            state = _currentValue;
          },
          onError: (error) {
            log.severe('Error in heading subscription: $error');
          },
        );
  }

  void _dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}

/// Strategy for reading heading sensor values
class HeadingSensorReadingStrategy extends SensorReadingStrategy {
  @override
  double? readValue(WidgetRef ref, int? port) {
    return useHeading(ref);
  }
}
