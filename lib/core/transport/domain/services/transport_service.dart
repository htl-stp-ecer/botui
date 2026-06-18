import 'dart:async';
import 'dart:typed_data';

import 'package:raccoon_transport/raccoon_transport.dart';
import 'package:rxdart/rxdart.dart';
import 'package:stpvelox/core/transport/models/transport_decoded.dart';
import 'package:stpvelox/core/logging/has_logging.dart';

/// Default throttle window for UI-bound sensor streams. ~60 Hz matches the
/// display refresh — emitting faster only burns CPU without ever being seen.
const Duration kUiSensorSampleRate = Duration(milliseconds: 16);

/// Transport service using raccoon_ring shared-memory IPC.
///
/// Subscriptions are lazy: the underlying transport subscription is only
/// established while at least one listener is attached to the returned
/// broadcast stream. When the last listener cancels, the transport
/// subscription is torn down so packets stop being dispatched for channels
/// nobody is watching.
class TransportService with HasLogger {
  RaccoonRingTransport? _transport;
  Completer<void>? _initCompleter;
  final Map<String, StreamController<TransportDecodedRaw>> _controllers = {};
  final Map<String, TransportSubscription> _subscriptions = {};
  final Map<String, SubscribeOptions> _subscribeOptions = {};

  bool get isInitialized => _transport != null;

  Future<void> get ready => _initCompleter?.future ?? Future.value();

  Future<void> init({String? provider}) async {
    if (_transport != null) {
      log.warning('Transport already initialized');
      return;
    }

    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    _initCompleter = Completer<void>();

    try {
      final nodeName = provider ?? 'stpvelox';
      _transport = await RaccoonRingTransport.create(nodeName);
      // 33 ms ≈ 30 fps. Bridge poll thread is futex-driven; this only
      // drains its queue into Dart streams. UI redraws at 30 fps so
      // faster polling just heats the UI thread.
      _transport!.startSpin(intervalMs: 33);
      log.info('raccoon_ring transport initialized: $nodeName');
      _initCompleter!.complete();
    } catch (e, st) {
      log.severe('Transport init failed: $e', st);
      _initCompleter!.completeError(e, st);
      _initCompleter = null;
      rethrow;
    }
  }

  Future<void> _ensureReady() async {
    if (_transport != null) return;
    if (_initCompleter != null) {
      await _initCompleter!.future;
    } else {
      throw StateError('Transport not initialized. Call init() first.');
    }
  }

  Stream<TransportDecodedRaw> subscribe(String channel,
      {SubscribeOptions options = const SubscribeOptions()}) {
    final existing = _controllers[channel];
    if (existing != null) {
      _subscribeOptions[channel] = options;
      return existing.stream;
    }

    _subscribeOptions[channel] = options;

    late StreamController<TransportDecodedRaw> controller;
    controller = StreamController<TransportDecodedRaw>.broadcast(
      onListen: () => _setupSubscription(channel),
      onCancel: () => _teardownSubscription(channel),
    );
    _controllers[channel] = controller;

    return controller.stream;
  }

  void _setupSubscription(String channel) {
    if (_subscriptions.containsKey(channel)) return;
    if (_transport == null) {
      _initCompleter?.future.then((_) => _setupSubscription(channel));
      return;
    }

    final controller = _controllers[channel];
    if (controller == null || !controller.hasListener) return;

    final options = _subscribeOptions[channel] ?? const SubscribeOptions();

    final sub = _transport!.subscribe(channel, (ch, data) {
      if (!controller.isClosed) {
        controller.add(TransportDecodedRaw(
          topic: ch,
          utime: DateTime.now().microsecondsSinceEpoch,
          data: data,
        ));
      }
    });
    _subscriptions[channel] = sub;
    log.fine('Subscribed to: $channel (retain=${options.requestRetained})');
  }

  void _teardownSubscription(String channel) {
    final controller = _controllers[channel];
    if (controller != null && controller.hasListener) return;

    final sub = _subscriptions.remove(channel);
    if (sub != null) {
      _transport?.unsubscribe(sub);
      log.fine('Transport subscription released for idle channel: $channel');
    }
  }

  Stream<TransportDecoded<T>> subscribeAs<T>(String channel, TransportDecoder<T> decode,
      {SubscribeOptions options = const SubscribeOptions(),
      Duration? throttle}) {
    var raw = subscribe(channel, options: options);
    if (throttle != null) {
      raw = raw.throttleTime(throttle, trailing: true);
    }
    return raw.map((raw) {
      final buffer = LcmBuffer.fromUint8List(raw.data);
      return TransportDecoded<T>(
        topic: raw.topic,
        utime: raw.utime,
        raw: raw.data,
        value: decode(buffer),
      );
    });
  }

  void unsubscribe(String channel) {
    final sub = _subscriptions.remove(channel);
    if (sub != null) {
      _transport?.unsubscribe(sub);
    }

    final controller = _controllers.remove(channel);
    controller?.close();
    _subscribeOptions.remove(channel);

    log.fine('Unsubscribed from: $channel');
  }

  Future<void> publish(String channel, LcmMessage message,
      {PublishOptions options = const PublishOptions()}) async {
    await _ensureReady();
    try {
      final dyn = message as dynamic;
      if (dyn.timestamp == 0) {
        dyn.timestamp = DateTime.now().microsecondsSinceEpoch;
      }
    } catch (_) {}

    final buf = LcmBuffer(65536);
    message.encode(buf);
    final data = Uint8List.sublistView(buf.uint8List, 0, buf.position);
    _transport!.publish(channel, data, deduplicate: options.deduplicate);
  }

  Future<void> publishRaw(String channel, Uint8List data,
      {PublishOptions options = const PublishOptions()}) async {
    await _ensureReady();
    _transport!.publish(channel, data, deduplicate: options.deduplicate);
  }

  void dispose() {
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
    _subscriptions.clear();
    _subscribeOptions.clear();
    _transport?.dispose();
    _transport = null;
    log.info('Transport disposed');
  }
}

/// Raw message (before decoding)
class TransportDecodedRaw {
  final String topic;
  final int utime;
  final Uint8List data;

  TransportDecodedRaw({
    required this.topic,
    required this.utime,
    required this.data,
  });
}
