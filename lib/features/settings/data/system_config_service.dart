import 'dart:io';

import 'package:stpvelox/core/utils/sudo_process.dart';

/// Result of a system-configuration command: whether it succeeded and a short
/// human-readable message suitable for a SnackBar.
class CommandOutcome {
  final bool ok;
  final String message;

  const CommandOutcome(this.ok, this.message);
}

/// A selectable keyboard layout (XKB layout code + display name).
class KeyboardLayout {
  final String code;
  final String name;

  const KeyboardLayout(this.code, this.name);
}

/// Thin wrapper around the OS commands used by the System settings screens.
///
/// Reads run unprivileged (`hostname`, `localectl status`); writes go through
/// [SudoProcess] because the flutter-ui service is unprivileged. Kept as an
/// instance (not statics) so it can be mocked in widget tests.
class SystemConfigService {
  const SystemConfigService();

  /// Supported layouts. Austria/Germany share the XKB `de` layout — there is
  /// no separate `at` layout in XKB.
  static const List<KeyboardLayout> keyboardLayouts = [
    KeyboardLayout('de', 'German (DE / AT)'),
    KeyboardLayout('us', 'English (US)'),
  ];

  /// Whether [name] is a valid RFC 1123 hostname label.
  static bool isValidHostname(String name) {
    return RegExp(r'^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$')
        .hasMatch(name);
  }

  Future<String> getHostname() async {
    try {
      final result = await Process.run('hostname', const []);
      final value = (result.stdout as String).trim();
      if (value.isNotEmpty) return value;
    } catch (_) {/* fall through */}
    try {
      return (await File('/etc/hostname').readAsString()).trim();
    } catch (_) {
      return '';
    }
  }

  /// Sets the system hostname AND the mDNS/Avahi name in one step.
  ///
  /// `hostnamectl set-hostname` updates the static hostname; Avahi publishes
  /// `<hostname>.local`, so restarting `avahi-daemon` makes the new name
  /// visible immediately. `/etc/hosts` is patched best-effort so local name
  /// resolution (and `sudo`) stops warning about an unresolved host.
  Future<CommandOutcome> setHostnameAndMdns(String newName) async {
    final name = newName.trim();
    if (!isValidHostname(name)) {
      return const CommandOutcome(
        false,
        'Invalid hostname (letters, digits, hyphens; no leading/trailing hyphen).',
      );
    }

    final oldName = await getHostname();

    final hostnameResult =
        await SudoProcess.run('hostnamectl', ['set-hostname', name]);
    if (hostnameResult.exitCode != 0) {
      return CommandOutcome(
        false,
        'Failed to set hostname: ${(hostnameResult.stderr as String).trim()}',
      );
    }

    // Best-effort: keep /etc/hosts in sync with the old name.
    if (oldName.isNotEmpty && oldName != name) {
      await SudoProcess.run(
        'sed',
        ['-i', 's/\\b$oldName\\b/$name/g', '/etc/hosts'],
      );
    }

    // Re-publish the mDNS record under the new name.
    final avahiResult =
        await SudoProcess.run('systemctl', ['restart', 'avahi-daemon']);
    if (avahiResult.exitCode != 0) {
      return CommandOutcome(
        true,
        'Hostname set to "$name". mDNS restart failed — reboot to apply .local.',
      );
    }

    return CommandOutcome(true, 'Now reachable as "$name" and "$name.local".');
  }

  static const String _keyboardConf = '/etc/default/keyboard';

  /// Reads the active XKB keyboard layout (used by libinput / flutter-pi) from
  /// `/etc/default/keyboard` — the source of truth on Raspberry Pi OS.
  Future<String> getKeyboardLayout() async {
    try {
      final conf = await File(_keyboardConf).readAsString();
      final match = RegExp(r'XKBLAYOUT="?([^"\n]+)"?').firstMatch(conf);
      if (match != null) return match.group(1)!.trim();
    } catch (_) {/* ignore */}
    return 'us';
  }

  /// Sets the keyboard layout by rewriting the `XKBLAYOUT` line in
  /// `/etc/default/keyboard` directly.
  ///
  /// This deliberately avoids `localectl set-x11-keymap`, which routes through
  /// systemd-localed/polkit and gets denied on a headless Pi even under sudo.
  /// Editing the file only needs sudo. `setupcon` reloads the console keymap;
  /// flutter-pi/libinput pick up the new layout on the next UI start / reboot.
  Future<CommandOutcome> setKeyboardLayout(String code) async {
    final result = await SudoProcess.run('sed', [
      '-i',
      '-e', 's/^XKBLAYOUT=.*/XKBLAYOUT="$code"/',
      '-e', 's/^XKBVARIANT=.*/XKBVARIANT=""/',
      _keyboardConf,
    ]);
    if (result.exitCode != 0) {
      return CommandOutcome(
        false,
        'Failed to set layout (sudo needed for sed): '
        '${(result.stderr as String).trim()}',
      );
    }
    // Best-effort immediate apply for the console; harmless if it fails.
    await SudoProcess.run('setupcon', const ['--force']);
    return CommandOutcome(
      true,
      'Keyboard layout set to "$code". Reboot to fully apply.',
    );
  }
}
