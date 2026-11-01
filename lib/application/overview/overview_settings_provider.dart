import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stpvelox/core/di/injection.dart';

/// Key for SharedPreferences storage
class OverviewSettingsKeys {
  static const String side = 'overview_side';
}

/// Which half of the main screen the overview section occupies, or [off]
/// to hide it (the menu then fills the whole screen).
enum OverviewSide { left, right, off }

class OverviewConfig {
  static const OverviewSide defaultSide = OverviewSide.left;
}

/// Notifier for the overview side, persisted like the screensaver setting.
class OverviewSideNotifier extends Notifier<OverviewSide> {
  late SharedPreferences _prefs;

  @override
  OverviewSide build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    final stored = _prefs.getString(OverviewSettingsKeys.side);
    return OverviewSide.values.asNameMap()[stored] ??
        OverviewConfig.defaultSide;
  }

  Future<void> setSide(OverviewSide side) async {
    await _prefs.setString(OverviewSettingsKeys.side, side.name);
    state = side;
  }

  /// Cycles left -> right -> off -> left.
  Future<void> toggle() => setSide(switch (state) {
        OverviewSide.left => OverviewSide.right,
        OverviewSide.right => OverviewSide.off,
        OverviewSide.off => OverviewSide.left,
      });
}

final overviewSideProvider =
    NotifierProvider<OverviewSideNotifier, OverviewSide>(
  OverviewSideNotifier.new,
);
