import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:stpvelox/core/utils/sudo_process.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:xterm/xterm.dart';
import 'package:stpvelox/core/utils/local_test.dart';

class ServiceLogScreen extends StatefulWidget {
  final String serviceName;
  final String displayName;

  const ServiceLogScreen({
    super.key,
    required this.serviceName,
    required this.displayName,
  });

  @override
  State<ServiceLogScreen> createState() => _ServiceLogScreenState();
}

class _ServiceLogScreenState extends State<ServiceLogScreen> {
  late Terminal _terminal;
  late TerminalController _terminalController;
  Process? _journalProcess;
  bool _isFollowing = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 10000);
    _terminalController = TerminalController();
    _startLogStream();
  }

  @override
  void dispose() {
    _stopLogStream();
    super.dispose();
  }

  Future<void> _startLogStream() async {
    setState(() => _loading = true);

    try {
      // First, load recent logs
      final result = await SudoProcess.run(
        'journalctl',
        ['-u', widget.serviceName, '-n', '200', '--no-pager', '-o', 'short-iso'],
      );

      if (result.exitCode == 0) {
        final logs = result.stdout.toString();
        _terminal.write(logs.replaceAll('\n', '\r\n'));
      } else {
        _terminal.write('Failed to load logs: ${result.stderr}\r\n');
      }

      // Then start following new logs
      if (_isFollowing && !kLocalTest) {
        _journalProcess = await Process.start(
          'sudo',
          ['journalctl', '-u', widget.serviceName, '-f', '-n', '0', '-o', 'short-iso'],
        );

        _journalProcess!.stdout.listen((data) {
          final text = String.fromCharCodes(data);
          _terminal.write(text.replaceAll('\n', '\r\n'));
        });

        _journalProcess!.stderr.listen((data) {
          final text = String.fromCharCodes(data);
          _terminal.write('\x1b[31m$text\x1b[0m'.replaceAll('\n', '\r\n'));
        });
      }
    } catch (e) {
      _terminal.write('\x1b[31mError: $e\x1b[0m\r\n');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _stopLogStream() {
    _journalProcess?.kill();
    _journalProcess = null;
  }

  void _toggleFollow() {
    setState(() {
      _isFollowing = !_isFollowing;
      if (_isFollowing) {
        _startLogStream();
      } else {
        _stopLogStream();
      }
    });
  }

  Future<void> _refreshLogs() async {
    _stopLogStream();
    _terminal.buffer.clear();
    _terminal.write('\x1b[2J\x1b[H'); // Clear screen
    await _startLogStream();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: createTopBar(
        context,
        '${widget.displayName} Logs',
        actions: [
          IconButton(
            onPressed: _toggleFollow,
            icon: Icon(
              _isFollowing ? Icons.pause : Icons.play_arrow,
              color: _isFollowing ? Colors.orange : Colors.green,
            ),
            tooltip: _isFollowing ? 'Pause' : 'Resume',
            iconSize: 28,
          ),
          IconButton(
            onPressed: _loading ? null : _refreshLogs,
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            iconSize: 28,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: Colors.grey[900],
              child: Row(
                children: [
                  Icon(
                    _isFollowing ? Icons.fiber_manual_record : Icons.pause_circle_filled,
                    size: 12,
                    color: _isFollowing ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isFollowing ? 'Following logs...' : 'Paused',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    widget.serviceName,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            // Terminal view
            Expanded(
              child: TerminalView(
                _terminal,
                controller: _terminalController,
                textStyle: const TerminalStyle(
                  fontSize: 12,
                  fontFamily: 'DejaVu Sans Mono',
                ),
                padding: const EdgeInsets.all(8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
