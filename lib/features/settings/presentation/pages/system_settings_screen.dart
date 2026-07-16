import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/utils/sudo_process.dart';
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
              icon: Icons.analytics_outlined,
              label: 'Services',
              color: Colors.green[600]!,
              onPressed: () => context.push(AppRoutes.serviceStatus),
            ),
            ResponsiveGridTile(
              icon: Icons.dns,
              label: 'Hostname',
              color: Colors.blue[600]!,
              onPressed: () => context.push(AppRoutes.hostnameSettings),
            ),
            ResponsiveGridTile(
              icon: Icons.keyboard,
              label: 'Keyboard',
              color: Colors.indigo[400]!,
              onPressed: () => context.push(AppRoutes.keyboardLocale),
            ),
            ResponsiveGridTile(
              icon: Icons.refresh,
              label: 'Reboot',
              color: Colors.orange[600]!,
              onPressed: () => RebootDevice().call(),
            ),
            ResponsiveGridTile(
              icon: Icons.power_settings_new,
              label: 'Shutdown',
              color: Colors.red[600]!,
              onPressed: () => _confirmShutdown(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmShutdown(BuildContext context) async {
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
              const Icon(Icons.power_off, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Shutdown?',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'The device will power off.',
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
                        child: const Text('Shutdown',
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
      await SudoProcess.run('shutdown', ['-h', 'now']);
    }
  }
}
