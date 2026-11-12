import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:stpvelox/core/service/raccoon_execution_client.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:xterm/xterm.dart';

final _log = Logger('LogRunScreen');

/// The lines of one run, formatted like `raccoon logs show`.
class LogRunScreen extends StatefulWidget {
  final String projectId;

  /// Index within the project, newest = 1.
  final int runIndex;
  final String title;

  const LogRunScreen({
    super.key,
    required this.projectId,
    required this.runIndex,
    required this.title,
  });

  @override
  State<LogRunScreen> createState() => _LogRunScreenState();
}

class _LogRunScreenState extends State<LogRunScreen> {
  late final Terminal _terminal;
  late final TerminalController _terminalController;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 20000);
    _terminalController = TerminalController();
    _load();
  }

  Future<void> _load() async {
    try {
      final client = await RaccoonExecutionClient.create();
      final lines = await client.getLogRun(widget.projectId, widget.runIndex);
      if (lines.isEmpty) {
        _terminal.write('No log lines in this run.\r\n');
      }
      final out = StringBuffer();
      for (final line in lines) {
        out.write(_format(line));
        out.write('\r\n');
      }
      _terminal.write(out.toString());
    } catch (e, st) {
      _log.severe('[load] failed', e, st);
      _terminal.write('\x1b[31mCould not load log: $e\x1b[0m\r\n');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: createTopBar(context, widget.title),
      body: SafeArea(
        child: Stack(
          children: [
            TerminalView(
              _terminal,
              controller: _terminalController,
              textStyle: const TerminalStyle(
                fontSize: 12,
                fontFamily: 'DejaVu Sans Mono',
              ),
              padding: const EdgeInsets.all(8),
            ),
            if (_loading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}

String _color(String level) {
  switch (level.toUpperCase()) {
    case 'ERROR':
      return '\x1b[1;31m';
    case 'CRITICAL':
      return '\x1b[1;37;41m';
    case 'WARN':
    case 'WARNING':
      return '\x1b[33m';
    case 'INFO':
      return '\x1b[32m';
    case 'DEBUG':
      return '\x1b[2;36m';
    default:
      return '\x1b[2m';
  }
}

String _pad(String s, int width) =>
    s.length >= width ? s.substring(0, width) : s.padRight(width);

/// `elapsed LEVEL file:line func message`, the columns of `raccoon logs show`.
String _format(LogLine l) {
  const reset = '\x1b[0m';
  final location = l.source.isEmpty
      ? ''
      : (l.line > 0 ? '${l.source}:${l.line}' : l.source);
  final level = l.level == 'WARNING' ? 'WARN' : l.level;
  final message = l.message.replaceAll('\r\n', '\n').replaceAll('\n', '\r\n');
  return '\x1b[2m${l.elapsed.toStringAsFixed(3).padLeft(9)}s$reset '
      '${_color(level)}${_pad(level, 8)}$reset '
      '\x1b[2;36m${_pad(location, 30)}$reset '
      '${l.func.isEmpty ? '' : '\x1b[2;3m${_pad(l.func, 24)}$reset '}'
      '$message';
}
