import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stpvelox/application/overview/overview_settings_provider.dart';
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
              color: TileColor.pink,
              onPressed: () => context.push(AppRoutes.colorTheme),
            ),
            ResponsiveGridTile(
              icon: Icons.screen_rotation,
              label: 'Rotate',
              color: TileColor.teal,
              onPressed: () => context.push(AppRoutes.screenRotation),
            ),
            const _OverviewSideTile(),
            _ScreensaverTile(prefs: prefs),
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
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Hide UI?',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'The UI will stop. Reboot required to restore.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400], fontSize: 16),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[700],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Cancel',
                            style: TextStyle(fontSize: 18, color: Colors.white)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[700],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Hide UI',
                            style: TextStyle(fontSize: 18, color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) {
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
      color: _enabled ? TileColor.cyan : TileColor.grey,
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
    final (icon, label, color) = switch (side) {
      OverviewSide.left => (
          Icons.align_horizontal_left,
          'Overview Left',
          TileColor.indigo
        ),
      OverviewSide.right => (
          Icons.align_horizontal_right,
          'Overview Right',
          TileColor.indigo
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
