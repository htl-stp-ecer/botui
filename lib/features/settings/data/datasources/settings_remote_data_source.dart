import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stpvelox/core/widgets/raccoon_dialog.dart';
import 'package:stpvelox/application/screensaver/screensaver_settings_provider.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/utils/sudo_process.dart';
import 'package:stpvelox/features/settings/domain/entities/setting.dart';
import 'package:stpvelox/features/settings/domain/usecases/reboot.dart';

abstract class SettingsRemoteDataSource {
  Future<List<Setting>> fetchSettings();
}

class SettingsRemoteDataSourceImpl implements SettingsRemoteDataSource {
  final RebootDevice reboot;
  final SharedPreferences sharedPreferences;
  bool allowSpiCommands = false;

  SettingsRemoteDataSourceImpl(
      {required this.reboot, required this.sharedPreferences});

  @override
  Future<List<Setting>> fetchSettings() async {
    return [
      Setting(
        icon: Icons.wifi,
        label: "Wi-Fi",
        color: Colors.green,
        type: SettingType.button,
        onTap: (context) => context.push(AppRoutes.wifi),
      ),
      Setting(
        icon: Icons.videocam,
        label: "Camera",
        color: Colors.blue,
        type: SettingType.button,
        onTap: (context) => context.push(AppRoutes.camera),
      ),
      Setting(
        icon: Icons.power_settings_new,
        label: "Shutdown",
        color: Colors.red,
        type: SettingType.button,
        onTap: (_) async {
          await _shutdownDevice();
        },
      ),
      Setting(
        icon: Icons.refresh,
        label: "Reboot",
        color: Colors.orange,
        type: SettingType.button,
        onTap: (_) async {
          await reboot.call();
        },
      ),
      Setting(
        icon: Icons.display_settings,
        label: "Calibrate",
        color: Colors.purple,
        type: SettingType.button,
        onTap: (context) => context.push(AppRoutes.touchCalibration),
      ),
      Setting(
        icon: Icons.screen_rotation,
        label: "Rotate",
        color: Colors.teal,
        type: SettingType.button,
        onTap: (context) => context.push(AppRoutes.screenRotation),
      ),
      Setting(
        icon: Icons.remove_red_eye,
        label: "Hide UI",
        color: Colors.blue,
        type: SettingType.button,
        onTap: (context) async {
          final confirmed = await showRaccoonConfirmDialog(
            context,
            title: 'Hide UI?',
            message: 'The UI will stop. Reboot required to restore.',
            confirmLabel: 'Hide UI',
          );
          if (confirmed) {
            await SudoProcess.run('systemctl', ['stop', 'flutter-ui']);
          }
        },
      ),
      Setting(
        icon: Icons.analytics_outlined,
        label: "Status",
        color: Colors.greenAccent,
        onTap: (context) => context.push(AppRoutes.serviceStatus),
      ),
      Setting(
        icon: Icons.emoji_emotions,
        label: "Personality",
        color: Colors.pinkAccent,
        type: SettingType.button,
        onTap: (context) => context.push(AppRoutes.personality),
      ),
      Setting(
        icon: Icons.face,
        label: "Screensaver",
        color: Colors.cyan,
        type: SettingType.toggle,
        value: () => sharedPreferences.getBool(ScreensaverSettingsKeys.enabled) ??
            ScreensaverConfig.defaultEnabled,
        onTap: (_) async {
          final currentValue = sharedPreferences.getBool(ScreensaverSettingsKeys.enabled) ??
              ScreensaverConfig.defaultEnabled;
          await sharedPreferences.setBool(ScreensaverSettingsKeys.enabled, !currentValue);
        },
      ),
    ];
  }

  Future<void> _shutdownDevice() async {
    await SudoProcess.run('shutdown', ['-h', 'now']);
  }
}
