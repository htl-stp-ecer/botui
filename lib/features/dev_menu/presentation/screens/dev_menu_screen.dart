import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/program/domain/services/program_lifecycle_service.dart';
import 'package:stpvelox/main.dart';

class DevMenuScreen extends ConsumerStatefulWidget {
  const DevMenuScreen({super.key});

  @override
  ConsumerState<DevMenuScreen> createState() => _DevMenuScreenState();
}

class _DevMenuScreenState extends ConsumerState<DevMenuScreen> {
  @override
  void dispose() {
    ref.read(devMenuActiveProvider.notifier).set(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(programLifecycleServiceProvider);
    final isRunning = session != null && session.isRunning;

    return Scaffold(
      appBar: createTopBar(context, 'Dev Menu'),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _DevMenuTile(
                      label: 'Stop Program',
                      icon: Icons.stop_circle,
                      color: isRunning ? Colors.red.shade700 : Colors.grey.shade700,
                      onTap: isRunning
                          ? () => ref
                              .read(programLifecycleServiceProvider.notifier)
                              .stopProgram()
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _DevMenuTile(
                      label: 'Restart UI',
                      icon: Icons.refresh,
                      color: Colors.orange,
                      onTap: () => _restartUI(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _DevMenuTile(
                      label: 'Reboot Robot',
                      icon: Icons.power_settings_new,
                      color: Colors.red,
                      onTap: () => _rebootRobot(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Fun',
                    style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _DevMenuTile(
                            label: 'Flappy Wombat',
                            icon: Icons.games,
                            color: Colors.green,
                            onTap: () => context.push(AppRoutes.flappyWombat),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _DevMenuTile(
                            label: 'Tilt Maze',
                            icon: Icons.explore,
                            color: Colors.purple,
                            onTap: () => context.push(AppRoutes.tiltMaze),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _DevMenuTile(
                            label: 'Reset STM32',
                            icon: Icons.memory,
                            color: Colors.teal,
                            onTap: () => _resetStm32(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _resetStm32(BuildContext context) {
    Process.run('bash', ['/home/pi/flash_files/reset_coprocessor.sh']);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Resetting STM32...'), duration: Duration(seconds: 2)),
    );
  }

  void _restartUI(BuildContext context) {
    Process.run('sudo', ['systemctl', 'restart', 'flutter-ui.service']);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Restarting UI...'), duration: Duration(seconds: 2)),
    );
  }

  void _rebootRobot(BuildContext context) {
    Process.run('sudo', ['reboot']);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rebooting robot...'), duration: Duration(seconds: 2)),
    );
  }
}

class _DevMenuTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _DevMenuTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Colors.black38, offset: Offset(0, 4), blurRadius: 6),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
