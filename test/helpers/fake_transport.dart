import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:stpvelox/core/transport/domain/providers.dart';
import 'package:stpvelox/core/transport/domain/services/transport_service.dart';

/// In-memory TransportService used by widget tests so any screen that watches
/// transport-backed providers (battery voltage, messages, sensor topics)
/// can render without touching the real shared-memory transport.
///
/// Channels emit nothing by default — listeners simply never fire, which
/// matches "no hardware connected" and produces the same UI a fresh boot
/// would show before the bridge has published anything.
class FakeTransportService extends TransportService {
  final Map<String, StreamController<TransportDecodedRaw>> controllers = {};

  @override
  Stream<TransportDecodedRaw> subscribe(String channel) {
    return controllers
        .putIfAbsent(
            channel, () => StreamController<TransportDecodedRaw>.broadcast())
        .stream;
  }
}

/// Convenience override list — drop into [pumpScreen]'s `overrides`.
List<Override> fakeTransportOverrides([FakeTransportService? service]) => [
      transportServiceProvider
          .overrideWith((ref) => service ?? FakeTransportService()),
    ];
