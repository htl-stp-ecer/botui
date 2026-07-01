import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stpvelox/core/logging/has_logging.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/service/sensors/digital_sensor.dart';

part 'button10_monitor.g.dart';

/// Monitors button 10 (the built-in controller button) for a long press.
///
/// A long press always opens the Dev Menu — including while a program is
/// running. The Dev Menu exposes a "Stop Program" action, so stopping a
/// running program is done there rather than by the button press directly.
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
    // A long press always opens the Dev Menu — even while a program is
    // running. The Dev Menu's "Stop Program" tile handles stopping.
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
