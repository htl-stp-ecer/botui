import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stpvelox/core/logging/has_logging.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/application/screenshot/screenshot_settings_provider.dart';
import 'package:stpvelox/core/service/raccoon_execution_client.dart';
import 'package:stpvelox/core/service/screenshot_service.dart';
import 'package:stpvelox/core/service/sensors/digital_sensor.dart';
import 'package:stpvelox/features/dev_menu/presentation/dev_menu_active_provider.dart';
import 'package:stpvelox/features/program/domain/services/program_lifecycle_service.dart';

part 'button10_monitor.g.dart';

/// Monitors button 10 (the built-in controller button) for a long press
/// (Dev Menu) and a triple-click (screenshot to `~/screenshots/`).
///
/// A long press always opens the Dev Menu — including while a program is
/// running. The Dev Menu exposes a "Stop Program" action, so stopping a
/// running program is done there rather than by the button press directly.
@riverpod
class Button10Monitor extends _$Button10Monitor with HasLogger {
  static const _longPressDuration = Duration(seconds: 2);

  static const _tripleClickWindow = Duration(milliseconds: 1200);

  /// Pause after the last click before a triple-click counts.
  static const _settleDelay = Duration(milliseconds: 250);

  DateTime? _holdStart;
  bool _triggered = false;
  bool _wasPressed = false;
  final List<DateTime> _clickTimes = [];
  Timer? _settleTimer;

  @override
  void build() {
    ref.onDispose(() => _settleTimer?.cancel());
    // Watch digital sensor 10
    ref.listen(digitalSensorProvider(10), (previous, next) {
      _onSensorChanged(next);
    });
  }

  void _onSensorChanged(bool? isPressed) {
    if (isPressed == true && !_wasPressed) _registerClick();
    _wasPressed = isPressed == true;

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

  /// Counts press edges. Exactly three clicks, followed by [_settleDelay]
  /// without another click, take a screenshot; more clicks do nothing.
  void _registerClick() {
    final now = DateTime.now();
    _clickTimes.removeWhere((t) => now.difference(t) > _tripleClickWindow);
    _clickTimes.add(now);
    _settleTimer?.cancel();
    _settleTimer = Timer(_settleDelay, _onClicksSettled);
  }

  void _onClicksSettled() {
    final count = _clickTimes.length;
    _clickTimes.clear();
    if (count != 3) return;

    // Flappy Wombat / Tilt Maze use button 10 as game input.
    final route = ref
        .read(appRouterProvider)
        .routerDelegate
        .currentConfiguration
        .fullPath;
    if (route == AppRoutes.flappyWombat || route == AppRoutes.tiltMaze) return;

    _takeScreenshotIfAllowed();
  }

  Future<void> _takeScreenshotIfAllowed() async {
    final mode = ref.read(screenshotModeProvider);
    if (mode == ScreenshotMode.never) {
      log.info('Button 10 triple-click ignored: screenshots are off');
      return;
    }
    if (mode == ScreenshotMode.whenIdle && await _isProgramRunning()) {
      log.info('Button 10 triple-click ignored: a program is running');
      return;
    }
    log.info('Button 10 triple-click - taking screenshot');
    await ref.read(screenshotServiceProvider).capture();
  }

  /// Same notion of "running" as the Dev Menu's Stop button: BotUI's own
  /// session, or whatever the raccoon server reports (e.g. `raccoon run`).
  Future<bool> _isProgramRunning() async {
    final session = ref.read(programLifecycleServiceProvider);
    if (session != null && session.isRunning) return true;
    try {
      final client = await RaccoonExecutionClient.create();
      return await client.getRunningCommand() != null;
    } catch (e) {
      // No token / server down: nothing we know of is running.
      return false;
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
    // The Dev Menu is a top-level overlay (painted above the DynamicUIScreen),
    // not a pushed route — that's what lets it stay on top of a program's
    // dynamic UI so its Stop button is always reachable.
    if (ref.read(devMenuActiveProvider)) return;

    // Don't open while an easter egg that also uses button 10 is on screen.
    final router = ref.read(appRouterProvider);
    final currentRoute = router.routerDelegate.currentConfiguration.fullPath;
    if (currentRoute == AppRoutes.flappyWombat ||
        currentRoute == AppRoutes.tiltMaze) {
      return;
    }

    log.info('Button 10 held for 2 seconds - opening Dev Menu!');
    ref.read(devMenuActiveProvider.notifier).show();
  }
}
