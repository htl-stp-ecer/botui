import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:stpvelox/application/theme/color_theme_provider.dart';
import 'package:stpvelox/core/theme/app_theme.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/dev_menu/presentation/dev_menu_active_provider.dart';
import 'package:stpvelox/features/program/domain/services/program_lifecycle_service.dart';
import 'package:stpvelox/features/program/domain/services/raccoon_program_running_provider.dart';
import 'package:stpvelox/core/utils/local_test.dart';
import 'package:stpvelox/core/utils/sudo_process.dart';

final _log = Logger('DevMenuScreen');

class DevMenuScreen extends ConsumerWidget {
  const DevMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(programLifecycleServiceProvider);
    // A program can be running on the robot even when botui holds no session
    // (started externally, or session lost across a UI restart / autoDispose).
    // Gate the Stop button on the server's actual running state too, so it is
    // reachable in those cases — otherwise onTap is null and the tile is inert.
    final serverRunning =
        ref.watch(raccoonProgramRunningProvider).asData?.value ?? false;
    final isRunning = (session != null && session.isRunning) || serverRunning;

    void close() => ref.read(devMenuActiveProvider.notifier).hide();

    // The Dev Menu is a top-level overlay (a sibling of the Navigator), so
    // navigate via the router provider rather than context — then close the
    // overlay so the pushed route (which paints below us) is visible.
    void openRoute(String route) {
      close();
      ref.read(appRouterProvider).push(route);
    }

    return Scaffold(
      appBar: createTopBar(context, 'Dev Menu', onBack: close),
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
                      index: 0,
                      label: 'Stop Program',
                      icon: Icons.stop_circle,
                      color: isRunning ? TileColor.red : TileColor.grey,
                      onTap: isRunning
                          ? () async {
                              _log.warning(
                                  '[StopButton] tapped — isRunning=$isRunning, session=$session');
                              try {
                                final exitCode = await ref
                                    .read(programLifecycleServiceProvider.notifier)
                                    .stopProgram();
                                _log.info(
                                    '[StopButton] stopProgram() returned exitCode=$exitCode');
                              } catch (e, st) {
                                _log.severe(
                                    '[StopButton] stopProgram() threw: $e', e, st);
                              }
                              close();
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _DevMenuTile(
                      index: 1,
                      label: 'Restart UI',
                      icon: Icons.refresh,
                      color: TileColor.orange,
                      onTap: () => _restartUI(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _DevMenuTile(
                      index: 2,
                      label: 'Reboot Robot',
                      icon: Icons.power_settings_new,
                      color: TileColor.red,
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
                            index: 3,
                            label: 'Flappy Wombat',
                            icon: Icons.games,
                            color: TileColor.green,
                            onTap: () => openRoute(AppRoutes.flappyWombat),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _DevMenuTile(
                            index: 4,
                            label: 'Tilt Maze',
                            icon: Icons.explore,
                            color: TileColor.purple,
                            onTap: () => openRoute(AppRoutes.tiltMaze),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _DevMenuTile(
                            index: 5,
                            label: 'Reset STM32',
                            icon: Icons.memory,
                            color: TileColor.teal,
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
    if (kLocalTest) {
      print('[local-test] not running: bash /home/pi/flash_files/reset_coprocessor.sh');
    } else {
      Process.run('bash', ['/home/pi/flash_files/reset_coprocessor.sh']);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Resetting STM32...'), duration: Duration(seconds: 2)),
    );
  }

  void _restartUI(BuildContext context) {
    SudoProcess.run('systemctl', ['restart', 'flutter-ui.service']);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Restarting UI...'), duration: Duration(seconds: 2)),
    );
  }

  void _rebootRobot(BuildContext context) {
    SudoProcess.run('reboot', []);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rebooting robot...'), duration: Duration(seconds: 2)),
    );
  }
}

class _DevMenuTile extends ConsumerWidget {
  final String label;
  final IconData icon;
  final TileColor color;
  final VoidCallback? onTap;
  final int index;

  const _DevMenuTile({
    required this.index,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(colorThemeProvider);
    final tileColor = theme.tileColor(color, index);
    final fg = theme.textColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(color: Colors.black38, offset: Offset(0, 4), blurRadius: 6),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: fg),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color: fg,
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
