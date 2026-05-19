import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stpvelox/core/lcm/domain/providers.dart';
import 'package:stpvelox/core/lcm/models/lcm_decoded.dart';
import 'package:stpvelox/core/logging/has_logging.dart';
import 'package:raccoon_transport/raccoon_transport.dart';

part 'servo_command_sensor.g.dart';

double? useServoCommand(WidgetRef ref, int port) {
  return ref.watch(servoCommandSensorProvider(port));
}

@riverpod
class ServoCommandSensor extends _$ServoCommandSensor with HasLogger {
  StreamSubscription<LcmDecoded<ScalarFT>>? _positionSub;
  StreamSubscription<LcmDecoded<Vector3fT>>? _smoothSub;
  double? _currentValue;

  @override
  double? build(int port) {
    if (port < 0 || port >= 4) return null;
    ref.onDispose(_dispose);
    _startSubscriptions(port);
    return _currentValue;
  }

  void _startSubscriptions(int port) {
    final lcm = ref.read(lcmServiceProvider);

    _positionSub = lcm
        .subscribeAs<ScalarFT>(Channels.servoPositionCommand(port), ScalarFT.decode)
        .listen(
      (decoded) {
        _currentValue = decoded.value.value;
        state = _currentValue;
      },
      onError: (e) => log.severe('Error in servo $port position_cmd subscription: $e'),
    );

    _smoothSub = lcm
        .subscribeAs<Vector3fT>(Channels.servoSmoothPositionCommand(port), Vector3fT.decode)
        .listen(
      (decoded) {
        _currentValue = decoded.value.x;
        state = _currentValue;
      },
      onError: (e) => log.severe('Error in servo $port smooth_cmd subscription: $e'),
    );
  }

  void _dispose() {
    _positionSub?.cancel();
    _positionSub = null;
    _smoothSub?.cancel();
    _smoothSub = null;
  }
}
