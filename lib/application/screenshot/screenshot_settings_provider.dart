import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stpvelox/core/di/injection.dart';

/// Key for SharedPreferences storage
class ScreenshotSettingsKeys {
  static const String mode = 'screenshot_mode';
}

/// When the built-in button's triple-click may take a screenshot.
enum ScreenshotMode { always, whenIdle, never }

class ScreenshotConfig {
  static const ScreenshotMode defaultMode = ScreenshotMode.always;
}

/// Notifier for the screenshot mode, persisted like the overview setting.
class ScreenshotModeNotifier extends Notifier<ScreenshotMode> {
  late SharedPreferences _prefs;

  @override
  ScreenshotMode build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    final stored = _prefs.getString(ScreenshotSettingsKeys.mode);
    return ScreenshotMode.values.asNameMap()[stored] ??
        ScreenshotConfig.defaultMode;
  }

  Future<void> setMode(ScreenshotMode mode) async {
    await _prefs.setString(ScreenshotSettingsKeys.mode, mode.name);
    state = mode;
  }

  /// Cycles always -> whenIdle -> never -> always.
  Future<void> toggle() => setMode(switch (state) {
        ScreenshotMode.always => ScreenshotMode.whenIdle,
        ScreenshotMode.whenIdle => ScreenshotMode.never,
        ScreenshotMode.never => ScreenshotMode.always,
      });
}

final screenshotModeProvider =
    NotifierProvider<ScreenshotModeNotifier, ScreenshotMode>(
  ScreenshotModeNotifier.new,
);
