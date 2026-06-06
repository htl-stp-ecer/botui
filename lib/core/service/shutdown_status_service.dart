import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stpvelox/core/transport/domain/providers.dart';
import 'package:stpvelox/core/transport/models/transport_decoded.dart';
import 'package:stpvelox/core/logging/has_logging.dart';
import 'package:raccoon_transport/messages/types/scalar_i32_t.g.dart';
import 'package:raccoon_transport/raccoon_transport.dart';

part 'shutdown_status_service.g.dart';

/// Shutdown flags bitmask constants
class ShutdownFlags {
  static const int servoShutdown = 0x01; // bit 0
  static const int motorShutdown = 0x02; // bit 1
  static const int watchdogTriggered = 0x04; // bit 2 — source = heartbeat watchdog

  /// Check if servo shutdown is enabled
  static bool isServoShutdown(int flags) => (flags & servoShutdown) != 0;

  /// Check if motor shutdown is enabled
  static bool isMotorShutdown(int flags) => (flags & motorShutdown) != 0;

  /// Check if the shutdown was triggered by the heartbeat watchdog
  /// (else: user-initiated via SHUTDOWN_CMD).
  static bool isWatchdogTriggered(int flags) => (flags & watchdogTriggered) != 0;

  /// Check if any shutdown is enabled
  static bool isAnyShutdown(int flags) => flags != 0;
}

/// Current shutdown status state
class ShutdownStatus {
  final bool servoShutdown;
  final bool motorShutdown;
  final bool triggeredByWatchdog;

  const ShutdownStatus({
    this.servoShutdown = false,
    this.motorShutdown = false,
    this.triggeredByWatchdog = false,
  });

  bool get isAnyShutdown => servoShutdown || motorShutdown;

  ShutdownStatus copyWith({
    bool? servoShutdown,
    bool? motorShutdown,
    bool? triggeredByWatchdog,
  }) {
    return ShutdownStatus(
      servoShutdown: servoShutdown ?? this.servoShutdown,
      motorShutdown: motorShutdown ?? this.motorShutdown,
      triggeredByWatchdog: triggeredByWatchdog ?? this.triggeredByWatchdog,
    );
  }

  @override
  String toString() =>
      'ShutdownStatus(servo: $servoShutdown, motor: $motorShutdown, '
      'watchdog: $triggeredByWatchdog)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShutdownStatus &&
          runtimeType == other.runtimeType &&
          servoShutdown == other.servoShutdown &&
          motorShutdown == other.motorShutdown &&
          triggeredByWatchdog == other.triggeredByWatchdog;

  @override
  int get hashCode =>
      servoShutdown.hashCode ^
      motorShutdown.hashCode ^
      triggeredByWatchdog.hashCode;
}

/// Helper function to get shutdown status
ShutdownStatus useShutdownStatus(WidgetRef ref) {
  return ref.watch(shutdownStatusProvider);
}

@Riverpod(keepAlive: true)
class ShutdownStatusService extends _$ShutdownStatusService with HasLogger {
  StreamSubscription<TransportDecoded<ScalarI32T>>? _subscription;
  ShutdownStatus _currentStatus = const ShutdownStatus();

  @override
  ShutdownStatus build() {
    ref.onDispose(_dispose);
    _startSubscription();
    return _currentStatus;
  }

  void _startSubscription() {
    final transport = ref.read(transportServiceProvider);
    _subscription = transport
        .subscribeAs<ScalarI32T>(
            Channels.shutdownStatus, ScalarI32T.decode,
            options: const SubscribeOptions(requestRetained: true))
        .listen(
      (decoded) {
        final flags = decoded.value.value;
        _currentStatus = ShutdownStatus(
          servoShutdown: ShutdownFlags.isServoShutdown(flags),
          motorShutdown: ShutdownFlags.isMotorShutdown(flags),
          triggeredByWatchdog: ShutdownFlags.isWatchdogTriggered(flags),
        );
        log.info('Shutdown status updated: $_currentStatus');
        state = _currentStatus;
      },
      onError: (error) {
        log.severe('Error in shutdown status subscription: $error');
      },
    );
  }

  void _dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Send command to enable/disable shutdown
  Future<void> setShutdown(bool enabled) async {
    final transport = ref.read(transportServiceProvider);
    await transport.publish(
      Channels.shutdownCmd,
      ScalarI32T(timestamp: DateTime.now().microsecondsSinceEpoch, value: enabled ? 1 : 0),
      options: const PublishOptions(reliable: true),
    );
    log.info('Sent shutdown command: ${enabled ? "enable" : "disable"}');
  }
}

/// Provider for ShutdownStatus (alias for easier use)
@riverpod
ShutdownStatus shutdownStatus(Ref ref) {
  return ref.watch(shutdownStatusServiceProvider);
}
