import 'dart:async';
import 'dart:typed_data';

import 'ffi/iox2_bridge_ffi.dart';

class TransportSubscription {
  final String channel;
  final MessageHandler _handler;

  TransportSubscription._(this.channel, this._handler);

  bool _matchesHandler(MessageHandler handler) =>
      identical(_handler, handler) || handler == _handler;
}

typedef MessageHandler = void Function(String channel, Uint8List data);

class Iceoryx2Transport {
  late final Iox2Node _node;
  final Map<String, Iox2Publisher> _publishers = {};
  final Map<String, _SubEntry> _subscribers = {};
  Timer? _spinTimer;
  bool _disposed = false;

  Iceoryx2Transport._();

  static Future<Iceoryx2Transport> create(String nodeName) async {
    final transport = Iceoryx2Transport._();
    transport._node = Iox2Node(nodeName);
    return transport;
  }

  int publish(String channel, Uint8List data) {
    final pub = _publishers.putIfAbsent(
        channel, () => Iox2Publisher(_node, channel));
    return pub.send(data);
  }

  TransportSubscription subscribe(String channel, MessageHandler handler) {
    final entry = _subscribers.putIfAbsent(channel, () {
      final sub = Iox2Subscriber(_node, channel);
      return _SubEntry(sub, channel);
    });

    entry._addHandler(handler);
    return TransportSubscription._(channel, handler);
  }

  void unsubscribe(TransportSubscription subscription) {
    final entry = _subscribers[subscription.channel];
    if (entry == null) return;

    entry._removeHandler(subscription._handler);

    if (entry._handlers.isEmpty) {
      _subscribers.remove(subscription.channel);
      entry.sub.dispose();
    }
  }

  void spinOnce() {
    if (_disposed) return;

    for (final entry in _subscribers.values.toList()) {
      Uint8List? data;
      try {
        data = entry.sub.receive();
      } catch (_) {
        continue;
      }
      if (data == null) continue;

      for (final handler in entry._handlers.toList()) {
        try {
          handler(entry._channel, data);
        } catch (_) {}
      }
    }
  }

  void startSpin({int intervalMs = 10}) {
    _spinTimer?.cancel();
    _spinTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      spinOnce();
    });
  }

  void stopSpin() {
    _spinTimer?.cancel();
    _spinTimer = null;
  }

  void dispose() {
    _disposed = true;
    stopSpin();
    for (final pub in _publishers.values) {
      pub.dispose();
    }
    _publishers.clear();
    for (final entry in _subscribers.values) {
      entry.sub.dispose();
    }
    _subscribers.clear();
    _node.dispose();
  }
}

class _SubEntry {
  final Iox2Subscriber sub;
  final String _channel;
  final List<MessageHandler> _handlers = [];

  _SubEntry(this.sub, this._channel);

  void _addHandler(MessageHandler handler) {
    _handlers.add(handler);
  }

  void _removeHandler(MessageHandler handler) {
    _handlers.removeWhere((h) => identical(h, handler) || h == handler);
  }
}
