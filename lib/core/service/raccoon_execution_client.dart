import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

final _log = Logger('RaccoonExecutionClient');

class RunningCommand {
  final String commandId;
  final String projectId;
  final String commandType;
  final String startedAt;

  const RunningCommand({
    required this.commandId,
    required this.projectId,
    required this.commandType,
    required this.startedAt,
  });
}

/// One run of a project as listed by ``GET /api/v1/logs/<project>/runs``.
/// [index] counts per project, newest = 1 (the number of ``raccoon logs show``).
class LogRunSummary {
  final int index;
  final DateTime startTime;
  final DateTime endTime;
  final double durationSecs;
  final int lineCount;
  final Map<String, int> levelCounts;

  const LogRunSummary({
    required this.index,
    required this.startTime,
    required this.endTime,
    required this.durationSecs,
    required this.lineCount,
    required this.levelCounts,
  });

  factory LogRunSummary.fromJson(Map<String, dynamic> json) => LogRunSummary(
        index: json['index'] as int,
        startTime: DateTime.parse(json['start_time'] as String),
        endTime: DateTime.parse(json['end_time'] as String),
        durationSecs: (json['duration_secs'] as num).toDouble(),
        lineCount: (json['line_count'] as num?)?.toInt() ?? 0,
        levelCounts: ((json['level_counts'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt())),
      );

  int get errors => (levelCounts['ERROR'] ?? 0) + (levelCounts['CRITICAL'] ?? 0);
  int get warnings => levelCounts['WARN'] ?? 0;
}

/// One log line of a run.
class LogLine {
  final double elapsed;
  final String level;
  final String source;
  final int line;
  final String func;
  final String message;

  const LogLine({
    required this.elapsed,
    required this.level,
    required this.source,
    required this.line,
    required this.func,
    required this.message,
  });

  factory LogLine.fromJson(Map<String, dynamic> json) => LogLine(
        elapsed: (json['elapsed'] as num?)?.toDouble() ?? 0,
        level: (json['level'] as String?) ?? '',
        source: (json['source'] as String?) ?? '',
        line: (json['line'] as num?)?.toInt() ?? 0,
        func: (json['func'] as String?) ?? '',
        message: (json['message'] as String?) ?? '',
      );
}

/// Minimal client for the raccoon execution service (HTTP + WebSocket).
/// The service runs on the Pi at localhost:8421.
class RaccoonExecutionClient {
  final String baseUrl;
  final String _token;

  RaccoonExecutionClient._({required this.baseUrl, required String token})
      : _token = token;

  static Future<RaccoonExecutionClient> create({
    String baseUrl = 'http://localhost:8421',
  }) async {
    final tokenFile = File('/home/pi/.raccoon/api_token');
    final token = (await tokenFile.readAsString()).trim();
    _log.fine('API token loaded');
    return RaccoonExecutionClient._(baseUrl: baseUrl, token: token);
  }

  /// Start a program. Returns the command_id assigned by the service.
  Future<String> run(String projectId, {List<String> args = const []}) async {
    final body = jsonEncode({
      'args': args,
      'env': {},
      'deploy_services': false,
    });
    final response = await _post('/api/v1/run/$projectId', body);
    final commandId = response['command_id'] as String;
    _log.info('[run] project=$projectId command_id=$commandId');
    return commandId;
  }

  /// Start a calibration. Returns the command_id assigned by the service.
  Future<String> calibrate(String projectId, {List<String> args = const []}) async {
    final body = jsonEncode({'args': args, 'env': {}});
    final response = await _post('/api/v1/calibrate/$projectId', body);
    final commandId = response['command_id'] as String;
    _log.info('[calibrate] project=$projectId command_id=$commandId');
    return commandId;
  }

  /// Returns the currently running command, or null if the robot is idle.
  Future<RunningCommand?> getRunningCommand() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(
        Uri.parse('$baseUrl/api/v1/commands/running'),
      );
      request.headers.set('X-API-Token', _token);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      if (json['is_running'] != true) return null;
      return RunningCommand(
        commandId: json['command_id'] as String,
        projectId: json['project_id'] as String,
        commandType: json['command_type'] as String,
        startedAt: json['started_at'] as String,
      );
    } finally {
      client.close();
    }
  }

  /// Runs of a project, newest first. Empty when the project has no logs yet.
  Future<List<LogRunSummary>> listLogRuns(String projectId,
      {int count = 20}) async {
    final json = await _getJson('/api/v1/logs/$projectId/runs?n=$count');
    if (json == null) return const [];
    final runs = (json['runs'] as List)
        .map((r) => LogRunSummary.fromJson(r as Map<String, dynamic>))
        .toList();
    runs.sort((a, b) => a.index.compareTo(b.index));
    return runs;
  }

  /// All log lines of one run of a project (index 1 = newest).
  Future<List<LogLine>> getLogRun(String projectId, int index) async {
    final json = await _getJson('/api/v1/logs/$projectId/runs/$index');
    if (json == null) return const [];
    return (json['entries'] as List)
        .map((e) => LogLine.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Cancel a running command.
  Future<void> cancel(String commandId) async {
    _log.info('[cancel] command_id=$commandId');
    await _post('/api/v1/commands/$commandId/cancel', null);
  }

  /// Stream output lines for a command. Each event is a plain text line.
  /// The final message is a JSON status object — callers should try-parse it.
  Stream<String> streamOutput(String commandId) async* {
    final wsBase = baseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');
    final uri = '$wsBase/ws/output/$commandId?token=$_token';
    _log.fine('[stream] connecting to $uri');

    final ws = await WebSocket.connect(uri);
    _log.info('[stream] connected for command_id=$commandId');

    await for (final message in ws) {
      yield message as String;
    }
  }

  /// GET a JSON object. Returns null on 404 (e.g. a project without logs).
  Future<Map<String, dynamic>?> _getJson(String path) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse('$baseUrl$path'));
      request.headers.set('X-API-Token', _token);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode == 404) return null;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
            'GET $path failed: status=${response.statusCode} body=$body');
      }
      return jsonDecode(body) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> _post(String path, String? body) async {
    final client = HttpClient();
    try {
      final url = '$baseUrl$path';
      _log.info('[_post] POST $url body=${body ?? '(none)'}');
      final request = await client.postUrl(Uri.parse(url));
      request.headers.set('X-API-Token', _token);
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(body);
      }
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      _log.info(
          '[_post] POST $url -> status=${response.statusCode} body=$responseBody');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
            'POST $path failed: status=${response.statusCode} body=$responseBody');
      }
      if (responseBody.isEmpty) return {};
      return jsonDecode(responseBody) as Map<String, dynamic>;
    } catch (e, st) {
      _log.severe('[_post] POST $baseUrl$path threw: $e', e, st);
      rethrow;
    } finally {
      client.close();
    }
  }
}
