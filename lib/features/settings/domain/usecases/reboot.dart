import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stpvelox/core/utils/sudo_process.dart';

part 'reboot.g.dart';

@riverpod
RebootDevice rebootDevice(Ref ref) {
  return RebootDevice();
}

class RebootDevice {
  /// Returns false (and does nothing) if passwordless sudo is missing.
  Future<bool> call([bool isShutdown = false]) async {
    final command = isShutdown ? 'shutdown' : 'reboot';
    final args = isShutdown ? ['-h', 'now'] : <String>[];
    if (!await SudoProcess.isPasswordless(command, args)) return false;
    await SudoProcess.run(command, args);
    return true;
  }
}
