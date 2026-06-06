import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raccoon_transport/raccoon_transport.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:stpvelox/core/lcm/domain/providers.dart';
import 'package:stpvelox/core/lcm/domain/services/lcm_service.dart';
import 'package:stpvelox/core/lcm/models/lcm_decoded.dart';

/// In-memory LcmService used by widget tests so any screen that watches
/// LCM-backed providers (battery voltage, error stream, sensor topics)
/// can render without touching the real raccoon_ring FFI transport.
///
/// Channels emit nothing by default — listeners simply never fire, which
/// matches "no hardware connected" and produces the same UI a fresh boot
/// would show before the bridge has published anything.
class FakeLcmService extends LcmService {
  final Map<String, StreamController<LcmDecodedRaw>> controllers = {};

  @override
  Stream<LcmDecodedRaw> subscribe(String channel,
      {SubscribeOptions options = const SubscribeOptions()}) {
    return controllers
        .putIfAbsent(channel,
            () => StreamController<LcmDecodedRaw>.broadcast())
        .stream;
  }
}

/// Convenience override list — drop into [pumpScreen]'s `overrides`.
List<Override> fakeLcmOverrides([FakeLcmService? service]) => [
      lcmServiceProvider.overrideWith((ref) => service ?? FakeLcmService()),
    ];
