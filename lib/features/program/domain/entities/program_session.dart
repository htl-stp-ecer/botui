import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:stpvelox/core/service/raccoon_execution_client.dart';
import 'package:stpvelox/features/program/domain/entities/program.dart';
import 'package:xterm/xterm.dart';

final _log = Logger('ProgramOutput');

class ProgramSession {
  late Terminal terminal;
  late TerminalController terminalController;
  bool _isRunning = false;
  bool _succeeded = false;

  // Raccoon execution client path
  String? _commandId;
  RaccoonExecutionClient? _client;
  StreamSubscription<String>? _outputSubscription;

  ProgramSession._internal();

  static Future<ProgramSession> create(
      Program program, Map<String, String> args,
      {List<String> extraFlags = const []}) async {
    final session = ProgramSession._internal();

    session.terminal = Terminal();
    session.terminalController = TerminalController();

    await _startViaRaccoon(session, program, args, extraFlags);

    return session;
  }

  static Future<void> _startViaRaccoon(
    ProgramSession session,
    Program program,
    Map<String, String> args,
    List<String> extraFlags,
  ) async {
    final client = await RaccoonExecutionClient.create();
    session._client = client;

    // project_id is the UUID directory name (last segment of parentDir)
    final projectId = program.parentDir.split('/').last;

    // Map args to --key=value strings, then append any bare flags (e.g. --dev).
    final argsList = [
      ...args.entries.map((e) => '--${e.key}=${e.value}'),
      ...extraFlags,
    ];

    final commandId = await client.run(projectId, args: argsList);
    session._commandId = commandId;
    session._isRunning = true;

    // Stream output into the terminal widget
    session._outputSubscription =
        client.streamOutput(commandId).listen(
      (message) {
        // The final message from the service is a JSON status object
        try {
          final json = jsonDecode(message) as Map<String, dynamic>;
          final status = json['status'] as String?;
          final exitCode = json['exit_code'];
          session.terminal
              .write('\r\nProcess $status (exit code: $exitCode)\r\n');
          session._isRunning = false;
          session._succeeded = status == 'completed' && exitCode == 0;
          _log.info('Program finished: status=$status exitCode=$exitCode');
        } catch (_) {
          // Plain output line
          session.terminal.write('$message\r\n');
          // Also log to the Flutter console (strip ANSI codes)
          final clean = message
              .replaceAll(RegExp(r'\x1B\[[0-9;]*[a-zA-Z]'), '')
              .trim();
          if (clean.isNotEmpty) _log.info(clean);
        }
      },
      onError: (e) {
        _log.warning('WebSocket error: $e');
        session.terminal.write('\r\n[output stream error: $e]\r\n');
        session._isRunning = false;
      },
      onDone: () {
        _log.info('Output stream closed');
        session._isRunning = false;
      },
    );
  }

  Future<int> kill({bool force = false}) async {
    _log.warning(
        '[kill] called — commandId=$_commandId, isRunning=$_isRunning');

    // Raccoon execution client path
    if (_commandId == null) {
      _log.warning('[kill] no commandId — nothing to kill');
      return -1;
    }

    _log.info('[kill] taking raccoon path — cancelling commandId=$_commandId');
    terminal.write('\r\nStopping program...\r\n');

    await _outputSubscription?.cancel();
    _outputSubscription = null;

    try {
      await _client?.cancel(_commandId!);
      _log.info('[kill] cancel() completed for commandId=$_commandId');
      terminal.write('\r\nProgram cancelled.\r\n');
    } catch (e, st) {
      _log.severe('[kill] Error cancelling command: $e', e, st);
      terminal.write('\r\nError cancelling: $e\r\n');
    }

    _isRunning = false;
    _commandId = null;
    return 0;
  }

  bool get isRunning => _isRunning;

  /// True once the program has ended on its own with exit code 0. Such a
  /// session has nothing left to show or stop and can be replaced by a fresh run.
  bool get finishedSuccessfully => !_isRunning && _succeeded;

  /// Tear down the session's streams and local bookkeeping WITHOUT issuing an
  /// HTTP cancel. Used when the actual program is stopped authoritatively via
  /// the server's running command (which may differ from this session's,
  /// possibly stale, [_commandId]).
  Future<void> detach() async {
    _log.info('[detach] releasing session (commandId=$_commandId)');
    await _outputSubscription?.cancel();
    _outputSubscription = null;
    _isRunning = false;
    _commandId = null;
  }
}
