import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stpvelox/core/di/injection.dart';

/// Key for SharedPreferences storage
class ScreensaverSettingsKeys {
  static const String enabled = 'screensaver_enabled';
}

/// Screensaver configuration
class ScreensaverConfig {
  /// Default: screensaver is disabled
  static const bool defaultEnabled = true;

  /// Hardcoded whitelist of screens where screensaver is allowed.
  /// Add screen names here to enable screensaver on those screens.
  static const List<String> whitelist = [
    'DashboardScreen',
  ];

  /// Check if a screen is in the whitelist
  static bool isWhitelisted(String screenName) {
    return whitelist.contains(screenName);
  }
}

/// Notifier for screensaver enabled state
class ScreensaverEnabledNotifier extends Notifier<bool> {
  late SharedPreferences _prefs;

  @override
  bool build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    return _prefs.getBool(ScreensaverSettingsKeys.enabled) ??
        ScreensaverConfig.defaultEnabled;
  }

  /// Toggle screensaver enabled state
  Future<void> toggle() async {
    final newEnabled = !state;
    await _prefs.setBool(ScreensaverSettingsKeys.enabled, newEnabled);
    state = newEnabled;
  }

  /// Set screensaver enabled state
  Future<void> setEnabled(bool enabled) async {
    await _prefs.setBool(ScreensaverSettingsKeys.enabled, enabled);
    state = enabled;
  }
}

/// Provider for screensaver enabled state
final screensaverEnabledProvider =
    NotifierProvider<ScreensaverEnabledNotifier, bool>(
  ScreensaverEnabledNotifier.new,
);

/// Tracks whether the screensaver is currently showing.
/// Used by other parts of the app (e.g. dynamic UI) to dismiss it.
class ScreensaverShowingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final screensaverShowingProvider =
    NotifierProvider<ScreensaverShowingNotifier, bool>(
  ScreensaverShowingNotifier.new,
);

/// How many open screens keep the screensaver off (see `KeepScreensaverOff`).
/// While it is above 0 the inactivity timer does not run.
class ScreensaverBlockNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void block() => state++;

  void unblock() {
    if (state > 0) state--;
  }
}

final screensaverBlockProvider =
    NotifierProvider<ScreensaverBlockNotifier, int>(
  ScreensaverBlockNotifier.new,
);
