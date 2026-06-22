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

  Future<Map<String, dynamic>> _post(String path, String? body) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse('$baseUrl$path'));
      request.headers.set('X-API-Token', _token);
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(body);
      }
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      if (responseBody.isEmpty) return {};
      return jsonDecode(responseBody) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }
}
