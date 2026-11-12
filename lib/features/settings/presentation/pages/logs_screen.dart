import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/service/raccoon_execution_client.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/program/domain/entities/program.dart';
import 'package:stpvelox/features/program/domain/repositories/program_remote_data_source.dart';

final _log = Logger('LogsScreen');

/// How many of the newest runs are fetched per program.
const _runsPerProgram = 20;

/// One row of the list: a run of one program.
class _LogEntry {
  final int number; // running number over all programs, 1 = newest
  final String programName;
  final String projectId;
  final LogRunSummary run;

  const _LogEntry({
    required this.number,
    required this.programName,
    required this.projectId,
    required this.run,
  });
}

/// All runs of all programs, newest first (the first row is `raccoon logs show 1`).
class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  List<_LogEntry>? _entries;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final programs =
          await ref.read(programRemoteDataSourceProvider).getPrograms();
      final client = await RaccoonExecutionClient.create();

      // project_id is the UUID directory name (last segment of parentDir).
      final perProgram = await Future.wait(programs.map((Program program) async {
        final projectId = program.parentDir.split('/').last;
        try {
          final runs =
              await client.listLogRuns(projectId, count: _runsPerProgram);
          return runs.map((r) => (program.name, projectId, r)).toList();
        } catch (e) {
          // One broken project must not hide the logs of the others.
          _log.warning('[load] logs of $projectId failed: $e');
          return <(String, String, LogRunSummary)>[];
        }
      }));

      final all = perProgram.expand((x) => x).toList()
        ..sort((a, b) => b.$3.startTime.compareTo(a.$3.startTime));

      final entries = <_LogEntry>[
        for (var i = 0; i < all.length; i++)
          _LogEntry(
            number: i + 1,
            programName: all[i].$1,
            projectId: all[i].$2,
            run: all[i].$3,
          ),
      ];
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e, st) {
      _log.severe('[load] failed', e, st);
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: createTopBar(
        context,
        'Logs',
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            iconSize: 28,
          ),
        ],
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_loading && _entries == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load logs:\n$_error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent, fontSize: 16),
          ),
        ),
      );
    }
    final entries = _entries ?? const <_LogEntry>[];
    if (entries.isEmpty) {
      return const Center(
        child: Text(
          'No runs yet',
          style: TextStyle(color: Colors.white54, fontSize: 18),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: Colors.white12),
      itemBuilder: (context, i) => _LogRow(entry: entries[i]),
    );
  }
}

class _LogRow extends StatelessWidget {
  final _LogEntry entry;

  const _LogRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final run = entry.run;
    return InkWell(
      onTap: () => context.push(AppRoutes.logRun, extra: {
        'projectId': entry.projectId,
        'runIndex': run.index,
        'title': '#${entry.number} ${entry.programName}',
      }),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              child: Text(
                '${entry.number}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Text(
                entry.programName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
            _LevelDots(levelCounts: run.levelCounts),
            if (run.errors > 0) _Badge('${run.errors} E', Colors.redAccent),
            if (run.warnings > 0) _Badge('${run.warnings} W', Colors.amber),
            const SizedBox(width: 12),
            Text(
              _formatDuration(run.durationSecs),
              style: const TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(width: 16),
            Text(
              _formatTimestamp(run.startTime),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontFamily: 'DejaVu Sans Mono',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One dot per log level that occurs in the run, in the colours `raccoon logs`
/// uses for the levels: INFO green, WARN yellow, ERROR red. TRACE, DEBUG and
/// CRITICAL get no dot.
class _LevelDots extends StatelessWidget {
  final Map<String, int> levelCounts;

  const _LevelDots({required this.levelCounts});

  static const _levels = [
    ('INFO', Colors.green),
    ('WARN', Colors.amber),
    ('ERROR', Colors.red),
  ];

  @override
  Widget build(BuildContext context) {
    // The server may report spdlog's "warning" instead of "WARN".
    final present = <String>{
      for (final e in levelCounts.entries)
        if (e.value > 0)
          e.key.toUpperCase() == 'WARNING' ? 'WARN' : e.key.toUpperCase(),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (level, color) in _levels)
          if (present.contains(level))
            Container(
              width: 14,
              height: 14,
              margin: const EdgeInsets.only(left: 6),
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 14)),
    );
  }
}

String _two(int v) => v.toString().padLeft(2, '0');

String _formatTimestamp(DateTime t) {
  final l = t.isUtc ? t.toLocal() : t;
  return '${_two(l.day)}.${_two(l.month)}.${l.year} '
      '${_two(l.hour)}:${_two(l.minute)}:${_two(l.second)}';
}

String _formatDuration(double secs) {
  if (secs < 60) return '${secs.toStringAsFixed(1)}s';
  final mins = secs ~/ 60;
  final rest = (secs % 60).round();
  return '${mins}m ${rest}s';
}
