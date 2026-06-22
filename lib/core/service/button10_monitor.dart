import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stpvelox/core/logging/has_logging.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/service/sensors/digital_sensor.dart';
import 'package:stpvelox/features/program/domain/services/program_lifecycle_service.dart';

part 'button10_monitor.g.dart';

/// Monitors button 10 (the built-in controller button) for a long press:
/// - While a program is running: stops the program.
/// - Otherwise: opens the Dev Menu.
@riverpod
class Button10Monitor extends _$Button10Monitor with HasLogger {
  static const _longPressDuration = Duration(seconds: 3);

  DateTime? _holdStart;
  bool _triggered = false;

  @override
  void build() {
    // Watch digital sensor 10
    ref.listen(digitalSensorProvider(10), (previous, next) {
      _onSensorChanged(next);
    });
  }

  void _onSensorChanged(bool? isPressed) {
    if (isPressed == true) {
      // Button pressed - start tracking
      _holdStart ??= DateTime.now();
      _triggered = false;
    } else {
      // Button released - reset
      _holdStart = null;
      _triggered = false;
    }
  }

  /// Call this periodically to check hold duration and trigger actions
  void checkHoldDuration() {
    if (_holdStart == null) return;

    final elapsed = DateTime.now().difference(_holdStart!);

    if (elapsed >= _longPressDuration && !_triggered) {
      _triggered = true;
      _onLongPress();
    }
  }

  void _onLongPress() {
    // A long press is the built-in "stop" control: if a program is running,
    // stop it. Only fall back to the Dev Menu when the robot is idle.
    final session = ref.read(programLifecycleServiceProvider);
    if (session != null && session.isRunning) {
      log.info('Button 10 long-press — stopping running program');
      ref.read(programLifecycleServiceProvider.notifier).stopProgram();
      return;
    }
    _openDevMenu();
  }

  void _openDevMenu() {
    log.info('Button 10 held for 3 seconds - opening Dev Menu!');

    final router = ref.read(appRouterProvider);
    final currentRoute = router.routerDelegate.currentConfiguration.fullPath;

    // Don't open if already on dev menu or any easter egg screen
    if (currentRoute != AppRoutes.devMenu &&
        currentRoute != AppRoutes.flappyWombat) {
      router.push(AppRoutes.devMenu);
    }
  }
}
