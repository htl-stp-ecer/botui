import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stpvelox/application/screensaver/screensaver_settings_provider.dart';
import 'package:stpvelox/core/di/injection.dart';
import 'package:stpvelox/core/router/app_router.dart';
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
              icon: Icons.display_settings,
              label: 'Calibrate',
              color: Colors.purple[600]!,
              onPressed: () => context.push(AppRoutes.touchCalibration),
            ),
            ResponsiveGridTile(
              icon: Icons.screen_rotation,
              label: 'Rotate',
              color: Colors.teal[600]!,
              onPressed: () => context.push(AppRoutes.screenRotation),
            ),
            _ScreensaverTile(prefs: prefs),
            ResponsiveGridTile(
              icon: Icons.remove_red_eye,
              label: 'Hide UI',
              color: Colors.blueGrey[600]!,
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
      color: _enabled ? Colors.cyan[600]! : Colors.grey[700]!,
      onPressed: _toggle,
    );
  }
}
