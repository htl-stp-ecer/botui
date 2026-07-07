import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Whether the Dev Menu overlay is currently shown.
///
/// The Dev Menu is painted at the top-level Stack (see main's
/// `_AppServicesStarter`) ABOVE the DynamicUIScreen, so it is the only UI
/// that stays on top of a program's dynamic UI. Button 10 toggles this via
/// [show]; the menu closes itself via [hide].
final devMenuActiveProvider =
    NotifierProvider<DevMenuActive, bool>(DevMenuActive.new);

class DevMenuActive extends Notifier<bool> {
  @override
  bool build() => false;

  void show() => state = true;
  void hide() => state = false;
}
