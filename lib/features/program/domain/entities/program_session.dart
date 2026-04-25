import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:stpvelox/core/service/raccoon_execution_client.dart';
import 'package:stpvelox/features/program/domain/entities/program.dart';
import 'package:xterm/xterm.dart';

final _log = Logger('ProgramOutput');

class ProgramSession {
  late Terminal terminal;
  late TerminalController terminalController;
  bool _isRunning = false;

  // Raccoon execution client path
  String? _commandId;
  RaccoonExecutionClient? _client;
  StreamSubscription<String>? _outputSubscription;

  // Direct process path (run.sh)
  Process? _process;
  StreamSubscription<List<int>>? _stdoutSubscription;
  StreamSubscription<List<int>>? _stderrSubscription;

  ProgramSession._internal();

  static Future<ProgramSession> create(
      Program program, Map<String, String> args,
      {List<String> extraFlags = const []}) async {
    final session = ProgramSession._internal();

    session.terminal = Terminal();
    session.terminalController = TerminalController();

    // Check if run.sh exists in the program directory (resolve to absolute)
    final parentDirAbsolute = Directory(program.parentDir).absolute.path;
    final runShPath = '$parentDirAbsolute/${program.runScript}';
    final runShFile = File(runShPath);

    if (await runShFile.exists()) {
      // Run run.sh directly
      await _startDirectProcess(session, program, args, extraFlags);
    } else {
      // Fall back to raccoon execution client
      await _startViaRaccoon(session, program, args, extraFlags);
    }

    return session;
  }

  static Future<void> _startDirectProcess(
    ProgramSession session,
    Program program,
    Map<String, String> args,
    List<String> extraFlags,
  ) async {
    // Resolve to absolute path so bash can find the script regardless of cwd
    final parentDirAbsolute = Directory(program.parentDir).absolute.path;
    final runShAbsolute = '$parentDirAbsolute/${program.runScript}';
    _log.info('[startDirect] Running $runShAbsolute in $parentDirAbsolute');

    // Build argument list: --key=value pairs then bare flags
    final argsList = [
      ...args.entries.map((e) => '--${e.key}=${e.value}'),
      ...extraFlags,
    ];

    final process = await Process.start(
      'bash',
      [runShAbsolute, ...argsList],
      workingDirectory: parentDirAbsolute,
    );
    session._process = process;
    session._isRunning = true;

    // Stream stdout into the terminal widget
    session._stdoutSubscription = process.stdout.listen(
      (data) {
        final text = utf8.decode(data, allowMalformed: true);
        session.terminal.write(text.replaceAll('\n', '\r\n'));
        final clean =
            text.replaceAll(RegExp(r'\x1B\[[0-9;]*[a-zA-Z]'), '').trim();
        if (clean.isNotEmpty) _log.info(clean);
      },
      onError: (e) {
        _log.warning('stdout error: $e');
        session.terminal.write('\r\n[stdout error: $e]\r\n');
      },
    );

    // Stream stderr into the terminal widget
    session._stderrSubscription = process.stderr.listen(
      (data) {
        final text = utf8.decode(data, allowMalformed: true);
        session.terminal.write(text.replaceAll('\n', '\r\n'));
        final clean =
            text.replaceAll(RegExp(r'\x1B\[[0-9;]*[a-zA-Z]'), '').trim();
        if (clean.isNotEmpty) _log.warning(clean);
      },
      onError: (e) {
        _log.warning('stderr error: $e');
        session.terminal.write('\r\n[stderr error: $e]\r\n');
      },
    );

    // Handle process exit
    process.exitCode.then((exitCode) {
      session.terminal
          .write('\r\nProcess exited (exit code: $exitCode)\r\n');
      session._isRunning = false;
      _log.info('Program finished: exitCode=$exitCode');
    });
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
    // Direct process path
    if (_process != null) {
      terminal.write('\r\nStopping program...\r\n');

      await _stdoutSubscription?.cancel();
      _stdoutSubscription = null;
      await _stderrSubscription?.cancel();
      _stderrSubscription = null;

      _process!.kill(ProcessSignal.sigterm);
      final exitCode = await _process!.exitCode;
      terminal.write('\r\nProgram stopped (exit code: $exitCode).\r\n');

      _isRunning = false;
      _process = null;
      return exitCode;
    }

    // Raccoon execution client path
    if (_commandId == null) return -1;

    terminal.write('\r\nStopping program...\r\n');

    await _outputSubscription?.cancel();
    _outputSubscription = null;

    try {
      await _client?.cancel(_commandId!);
      terminal.write('\r\nProgram cancelled.\r\n');
    } catch (e) {
      _log.warning('Error cancelling command: $e');
      terminal.write('\r\nError cancelling: $e\r\n');
    }

    _isRunning = false;
    _commandId = null;
    return 0;
  }

  bool get isRunning => _isRunning;
}
