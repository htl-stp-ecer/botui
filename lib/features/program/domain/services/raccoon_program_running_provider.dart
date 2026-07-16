import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:stpvelox/core/service/raccoon_execution_client.dart';

final _log = Logger('RaccoonProgramRunning');

/// Whether the raccoon server currently reports a running command.
///
/// This is intentionally independent of [ProgramLifecycleService]'s in-memory
/// `_session`: a program can be running on the robot even when botui holds no
/// session — e.g. it was started externally (`raccoon run` from a laptop) or
/// the autoDispose provider dropped the session across a UI restart. The Dev
/// Menu's Stop button gates on this so it stays reachable in those cases.
///
/// autoDispose so it re-fetches each time the Dev Menu opens (fresh state)
/// and does not linger once the menu closes.
final raccoonProgramRunningProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  try {
    final client = await RaccoonExecutionClient.create();
    final running = await client.getRunningCommand();
    _log.info('[running] server running command: ${running?.commandId}');
    return running != null;
  } catch (e) {
    // No token file (not on the Pi), server down, etc. — treat as "not running"
    // so the button simply stays disabled rather than crashing the menu.
    _log.warning('[running] could not query server: $e');
    return false;
  }
});
