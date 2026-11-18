import 'dart:io';

import 'package:stpvelox/core/utils/local_test.dart';

/// The home directory of the account the app runs as, where the screenshots
/// are saved. Not always `/home/pi`.
String homeDir() {
  final home = Platform.environment['HOME'];
  if (home != null && home.isNotEmpty) return home;
  return kLocalTest ? Directory.systemTemp.path : '/home/pi';
}

/// The account name the app runs as, for commands like `scp <user>@host:...`.
/// The environment first (a service may not set it), then the last part of the
/// home directory.
String loginUser() {
  for (final key in const ['USER', 'LOGNAME']) {
    final value = Platform.environment[key];
    if (value != null && value.isNotEmpty) return value;
  }
  final parts = homeDir().split('/').where((part) => part.isNotEmpty);
  return parts.isEmpty ? 'pi' : parts.last;
}
