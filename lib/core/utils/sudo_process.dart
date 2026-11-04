import 'dart:io';

import 'package:stpvelox/core/utils/local_test.dart';

/// All sudo calls use `-n` (non-interactive): without passwordless sudo they
/// fail immediately instead of prompting on the tty and hanging.
class SudoProcess {
  /// True if sudo may run [command] without asking for a password. `-n` makes
  /// sudo fail immediately instead of prompting, and `-l` only checks the rule
  /// without executing anything. Also false if sudo itself is missing.
  static Future<bool> isPasswordless(String command,
      [List<String> args = const []]) async {
    if (kLocalTest) return true;
    try {
      final result = await Process.run('sudo', ['-n', '-l', command, ...args])
          .timeout(const Duration(seconds: 10));
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<ProcessResult> run(String command, List<String> args) async {
    if (kLocalTest) return _skipped([command, ...args]);
    final result = await Process.run('sudo', ['-n', command, ...args]);
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    return result;
  }

  static Future<ProcessResult> runWith(List<String> command) async {
    if (kLocalTest) return _skipped(command);
    final result = await Process.run('sudo', ['-n', ...command]);
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    return result;
  }

  /// Local test mode (see [kLocalTest]): the command is not run. It looks successful
  /// with no output, so screens go on as they would on the robot.
  static ProcessResult _skipped(List<String> command) {
    print('[local-test] not running: sudo -n ${command.join(' ')}');
    return ProcessResult(0, 0, '', '');
  }
}
