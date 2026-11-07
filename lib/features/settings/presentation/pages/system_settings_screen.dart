import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:stpvelox/core/widgets/raccoon_dialog.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/theme/app_theme.dart';
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
    final confirmed = await showRaccoonConfirmDialog(
      context,
      title: '$title?',
      message: text,
      confirmLabel: title,
      icon: icon,
      iconColor: color,
      confirmColor: shutdown ? Colors.red[700]! : Colors.orange[700]!,
    );
    if (confirmed) {
      final ok = await RebootDevice().call(shutdown);
      if (!ok && context.mounted) {
        await showRaccoonErrorDialog(
            context,
            shutdown
                ? "Missing passwordless sudo, can't shut down"
                : "Missing passwordless sudo, can't reboot");
      }
    }
  }
}
