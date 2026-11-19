import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stpvelox/core/widgets/raccoon_dialog.dart';
import 'package:stpvelox/application/overview/overview_settings_provider.dart';
import 'package:stpvelox/application/screenshot/screenshot_settings_provider.dart';
import 'package:stpvelox/application/screensaver/screensaver_settings_provider.dart';
import 'package:stpvelox/core/di/injection.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/theme/app_theme.dart';
import 'package:stpvelox/core/utils/sudo_process.dart';
import 'package:stpvelox/core/widgets/responsive_grid.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/wifi/presentation/widgets/grid_tile.dart';

class DisplaySettingsScreen extends ConsumerWidget {
  const DisplaySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(sharedPreferencesProvider);

    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: createTopBar(context, 'Display'),
      body: SafeArea(
        child: ResponsiveGrid(
          children: [
            ResponsiveGridTile(
              icon: Icons.palette,
              label: 'Color Theme',
              color: TileColor.red,
              onPressed: () => context.push(AppRoutes.colorTheme),
            ),
            const _OverviewSideTile(),
            const _ScreenshotModeTile(),
            _ScreensaverTile(prefs: prefs),
            ResponsiveGridTile(
              icon: Icons.screen_rotation,
              label: 'Rotate',
              color: TileColor.teal,
              onPressed: () => context.push(AppRoutes.screenRotation),
            ),
            ResponsiveGridTile(
              icon: Icons.display_settings,
              label: 'Calibrate',
              color: TileColor.purple,
              onPressed: () => context.push(AppRoutes.touchCalibration),
            ),
            ResponsiveGridTile(
              icon: Icons.remove_red_eye,
              label: 'Hide UI',
              color: TileColor.blueGrey,
              onPressed: () => _confirmHideUi(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmHideUi(BuildContext context) async {
    final confirmed = await showRaccoonConfirmDialog(
      context,
      title: 'Hide UI?',
      message: 'The UI will stop. Reboot required to restore.',
      confirmLabel: 'Hide UI',
    );
    if (confirmed) {
      await SudoProcess.run('systemctl', ['stop', 'flutter-ui']);
    }
  }
}

class _ScreensaverTile extends StatefulWidget {
  final SharedPreferences prefs;

  const _ScreensaverTile({required this.prefs});

  @override
  State<_ScreensaverTile> createState() => _ScreensaverTileState();
}

class _ScreensaverTileState extends State<_ScreensaverTile> {
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _enabled = widget.prefs.getBool(ScreensaverSettingsKeys.enabled) ??
        ScreensaverConfig.defaultEnabled;
  }

  Future<void> _toggle() async {
    final next = !_enabled;
    await widget.prefs.setBool(ScreensaverSettingsKeys.enabled, next);
    setState(() => _enabled = next);
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveGridTile(
      icon: _enabled ? Icons.face : Icons.face_retouching_off,
      label: _enabled ? 'Screensaver On' : 'Screensaver Off',
      color: _enabled ? TileColor.orange : TileColor.grey,
      onPressed: _toggle,
    );
  }
}

/// Switches which half of the main screen the overview section is on.
class _OverviewSideTile extends ConsumerWidget {
  const _OverviewSideTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final side = ref.watch(overviewSideProvider);
    // In portrait the dashboard stacks the overview: stored "right" is top,
    // "left" is bottom, so the option is named accordingly.
    final isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    final (icon, label, color) = switch (side) {
      OverviewSide.left => (
          isPortrait
              ? Icons.align_vertical_bottom
              : Icons.align_horizontal_left,
          isPortrait ? 'Overview Bottom' : 'Overview Left',
          TileColor.blue
        ),
      OverviewSide.right => (
          isPortrait ? Icons.align_vertical_top : Icons.align_horizontal_right,
          isPortrait ? 'Overview Top' : 'Overview Right',
          TileColor.blue
        ),
      OverviewSide.off => (
          Icons.visibility_off,
          'Overview Off',
          TileColor.grey
        ),
    };
    return ResponsiveGridTile(
      icon: icon,
      label: label,
      color: color,
      onPressed: () => ref.read(overviewSideProvider.notifier).toggle(),
    );
  }
}

/// Cycles when the triple-click on the built-in button may take a screenshot.
class _ScreenshotModeTile extends ConsumerWidget {
  const _ScreenshotModeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(screenshotModeProvider);
    final (icon, label, color) = switch (mode) {
      ScreenshotMode.always => (
          Icons.photo_camera,
          'Screenshots: Always',
          TileColor.green
        ),
      ScreenshotMode.whenIdle => (
          Icons.motion_photos_pause,
          'Screenshots:\nIdle Only',
          TileColor.green
        ),
      ScreenshotMode.never => (
          Icons.no_photography,
          'Screenshots: Never',
          TileColor.grey
        ),
    };
    return ResponsiveGridTile(
      icon: icon,
      label: label,
      color: color,
      onPressed: () => ref.read(screenshotModeProvider.notifier).toggle(),
    );
  }
}
