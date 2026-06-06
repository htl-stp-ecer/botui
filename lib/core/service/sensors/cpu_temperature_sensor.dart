import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stpvelox/core/transport/domain/providers.dart';
import 'package:stpvelox/core/transport/models/transport_decoded.dart';
import 'package:stpvelox/core/logging/has_logging.dart';
import 'package:stpvelox/core/service/sensors/sensor_reading_strategy.dart';
import 'package:raccoon_transport/messages/types/scalar_f_t.g.dart';
import 'package:raccoon_transport/raccoon_transport.dart';

part 'cpu_temperature_sensor.g.dart';

double? useCpuTemperature(WidgetRef ref) {
  return ref.watch(cpuTemperatureSensorProvider);
}

@riverpod
class CpuTemperatureSensor extends _$CpuTemperatureSensor with HasLogger {
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
    _subscription =
        transport.subscribeAs<ScalarFT>(Channels.cpuTemperature, ScalarFT.decode).listen(
              (decoded) {
            _currentValue = decoded.value.value;
            state = _currentValue;
          },
          onError: (error) {
            log.severe('Error in CPU temperature subscription: $error');
          },
        );
  }

  void _dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}

/// Strategy for reading CPU temperature sensor values
class CpuTemperatureSensorReadingStrategy extends SensorReadingStrategy {
  @override
  double? readValue(WidgetRef ref, int? port) {
    return useCpuTemperature(ref);
  }
}


