import 'dart:async';

import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stpvelox/core/service/raccoon_execution_client.dart';
import 'package:stpvelox/features/program/domain/entities/program.dart';
import 'package:stpvelox/features/program/domain/entities/program_session.dart';

part 'program_lifecycle_service.g.dart';

final _log = Logger('ProgramLifecycleService');

/// keepAlive: this holds the app-global "currently running program" session.
/// It must NOT autoDispose — under the dynamic-UI (screen_render) rebuild storm
/// an autoDispose provider is created and torn down many times per second,
/// which previously (a) fired onDispose→kill() spuriously (cancel storms) and
/// (b) threw "Ref after disposed" when stopProgram wrote `state` after an await.
@Riverpod(keepAlive: true)
class ProgramLifecycleService extends _$ProgramLifecycleService {
  ProgramSession? _session;
  bool _stopping = false;

  @override
  ProgramSession? build() {
    // Intentionally NO onDispose(kill): stopping a running robot program must
    // only happen on an explicit user action (Dev Menu → Stop), never as a
    // side effect of provider/UI teardown (e.g. a FrameStallWatchdog restart).
    return null;
  }

  Future<ProgramSession> startProgram(
    Program program,
    Map<String, String> args, {
    List<String> extraFlags = const [],
  }) async {
    _log.info('[startProgram] Starting: ${program.name} flags=$extraFlags');
    _session =
        await ProgramSession.create(program, args, extraFlags: extraFlags);
    state = _session;
    return _session!;
  }

  /// Stop the running program.
  ///
  /// For direct-process sessions we kill the local process. Otherwise we cancel
  /// whatever the raccoon **server** reports as running — which is authoritative
  /// and independent of our local [_session], whose `command_id` may be stale
  /// (an older overlapping run) or absent (started outside botui, or lost to a
  /// UI restart). Idempotent via [_stopping] so a burst of taps issues one
  /// cancel, not dozens.
  Future<int> stopProgram() async {
    if (_stopping) {
      _log.info('[stopProgram] already stopping — ignoring re-entrant call');
      return -1;
    }
    _stopping = true;
    _log.warning('[stopProgram] stopProgram() called');
    try {
      // Direct-process path: no server command exists, kill locally.
      if (_session != null && _session!.isDirectProcess) {
        final result = await _session!.kill();
        _session = null;
        state = null;
        _log.info('[stopProgram] direct process stopped, exit code: $result');
        return result;
      }

      // Raccoon path: cancel the server's actual running command.
      final client = await RaccoonExecutionClient.create();
      final running = await client.getRunningCommand();
      if (running == null) {
        _log.info('[stopProgram] server reports nothing running');
        await _session?.detach();
        _session = null;
        state = null;
        return -1;
      }
      _log.warning('[stopProgram] cancelling running command ${running.commandId}');
      await client.cancel(running.commandId);
      _log.info('[stopProgram] running command cancelled');
      await _session?.detach();
      _session = null;
      state = null;
      return 0;
    } catch (e, st) {
      _log.severe('[stopProgram] failed: $e', e, st);
      return -1;
    } finally {
      _stopping = false;
    }
  }
}
