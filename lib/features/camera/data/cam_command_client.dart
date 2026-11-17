import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:raccoon_transport/raccoon_transport.dart';
import 'package:stpvelox/core/transport/domain/services/transport_service.dart';
import 'package:stpvelox/core/transport/models/transport_decoded.dart';

/// Where the camera service takes its commands, and where it answers.
const String kCamCommandChannel = 'raccoon/cam/cmd';
const String kCamResponseChannel = 'raccoon/cam/response';

/// The camera service refused a command, or did not answer it.
class CamCommandException implements Exception {
  const CamCommandException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Talks to the camera service the way its own clients do: a JSON command in
/// a `string_t` on `raccoon/cam/cmd`, the answer (matched by `request_id`) on
/// `raccoon/cam/response`.
///
/// The robot UI's transport neither retries a command nor acknowledges an
/// answer, so a command is sent again if no answer arrives (the commands used
/// here are safe to repeat), and the service is told not to repeat its answers
/// (`reliable_reply: false`), which nobody would acknowledge.
class CamCommandClient {
  CamCommandClient(this._transport);

  final TransportService _transport;
  final Map<String, Completer<Map<String, dynamic>>> _pending = {};
  final Random _random = Random.secure();
  StreamSubscription<TransportDecoded<StringT>>? _responses;

  void _listen() {
    _responses ??= _transport
        .subscribeAs<StringT>(kCamResponseChannel, StringT.decode)
        .listen(_onResponse);
  }

  void _onResponse(TransportDecoded<StringT> decoded) {
    final Object? document;
    try {
      document = jsonDecode(decoded.value.value);
    } on FormatException {
      return;
    }
    if (document is! Map) return;
    final completer = _pending[document['request_id']];
    if (completer == null || completer.isCompleted) return;
    final data = document['data'];
    final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    if (document['ok'] == true) {
      completer.complete(map);
    } else {
      completer.completeError(
        CamCommandException((map['error'] ?? 'the command failed').toString()),
      );
    }
  }

  String _newId() =>
      List.generate(16, (_) => _random.nextInt(16).toRadixString(16)).join();

  /// Sends [command] and returns the answer's data. Throws a
  /// [CamCommandException] with the service's own message if it refuses, or
  /// if nothing answers after [attempts] tries of [timeout] each.
  Future<Map<String, dynamic>> call(
    String command, [
    Map<String, dynamic> data = const {},
    Duration timeout = const Duration(seconds: 3),
    int attempts = 3,
  ]) async {
    _listen();
    final id = _newId();
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    final message = jsonEncode({
      'request_id': id,
      'command': command,
      'data': data,
      'reliable_reply': false,
    });
    try {
      for (var attempt = 1; attempt <= attempts; attempt++) {
        await _transport.publish(
          kCamCommandChannel,
          StringT(timestamp: 0, value: message),
          options: const PublishOptions(reliable: true),
        );
        try {
          return await completer.future.timeout(timeout);
        } on TimeoutException {
          // try again
        }
      }
      throw CamCommandException('the camera service did not answer "$command"');
    } finally {
      _pending.remove(id);
    }
  }

  Future<void> close() async {
    await _responses?.cancel();
    _responses = null;
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(const CamCommandException('closed'));
      }
    }
    _pending.clear();
  }
}
