import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stpvelox/core/di/injection.dart';
import 'package:stpvelox/core/theme/app_theme.dart';
import 'package:stpvelox/themes.dart';

class ColorThemeKeys {
  static const String theme = 'color_theme';
}

/// The selected color theme, persisted like the screensaver setting. An unknown
/// or missing stored id (e.g. a removed theme) selects the first theme in
/// [appThemes].
class ColorThemeNotifier extends Notifier<AppTheme> {
  late SharedPreferences _prefs;

  @override
  AppTheme build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    final id = _prefs.getString(ColorThemeKeys.theme);
    return appThemes.firstWhere((t) => t.id == id,
        orElse: () => appThemes.first);
  }

  Future<void> setTheme(String id) async {
    await _prefs.setString(ColorThemeKeys.theme, id);
    state =
        appThemes.firstWhere((t) => t.id == id, orElse: () => appThemes.first);
  }
}

final colorThemeProvider = NotifierProvider<ColorThemeNotifier, AppTheme>(
  ColorThemeNotifier.new,
);
