import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/theme/app_theme.dart';
import 'package:stpvelox/core/widgets/error_popup.dart';
import 'package:stpvelox/core/widgets/responsive_grid.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/settings/domain/usecases/reboot.dart';
import 'package:stpvelox/features/wifi/presentation/widgets/grid_tile.dart';

class SystemSettingsScreen extends StatelessWidget {
  const SystemSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: createTopBar(context, 'System'),
      body: SafeArea(
        child: ResponsiveGrid(
          children: [
            ResponsiveGridTile(
              icon: Icons.dns,
              label: 'Hostname',
              color: TileColor.green,
              onPressed: () => context.push(AppRoutes.hostnameSettings),
            ),
            ResponsiveGridTile(
              icon: Icons.keyboard,
              label: 'Keyboard',
              color: TileColor.blue,
              onPressed: () => context.push(AppRoutes.keyboardLocale),
            ),
            ResponsiveGridTile(
              icon: Icons.refresh,
              label: 'Reboot',
              color: TileColor.orange,
              onPressed: () => _confirmPowerAction(context, shutdown: false),
            ),
            ResponsiveGridTile(
              icon: Icons.power_settings_new,
              label: 'Shutdown',
              color: TileColor.red,
              onPressed: () => _confirmPowerAction(context, shutdown: true),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmPowerAction(BuildContext context,
      {required bool shutdown}) async {
    final title = shutdown ? 'Shutdown' : 'Reboot';
    final icon = shutdown ? Icons.power_off : Icons.refresh;
    final color = shutdown ? Colors.red : Colors.orange;
    final text =
        shutdown ? 'The device will power off.' : 'The device will restart.';
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
              Icon(icon, color: color, size: 48),
              const SizedBox(height: 16),
              Text(
                '$title?',
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                text,
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
                          backgroundColor: shutdown ? Colors.red[700] : Colors.orange[700],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(title,
                            style: const TextStyle(
                                fontSize: 18, color: Colors.white)),
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
      final ok = await RebootDevice().call(shutdown);
      if (!ok && context.mounted) {
        await showErrorPopup(
            context,
            shutdown
                ? "Missing passwordless sudo, can't shut down"
                : "Missing passwordless sudo, can't reboot");
      }
    }
  }
}
