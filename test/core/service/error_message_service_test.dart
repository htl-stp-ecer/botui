import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raccoon_transport/raccoon_transport.dart';
import 'package:stpvelox/core/lcm/domain/providers.dart';
import 'package:stpvelox/core/lcm/domain/services/lcm_service.dart';
import 'package:stpvelox/core/lcm/models/lcm_decoded.dart';
import 'package:stpvelox/core/service/error_message_service.dart';

/// In-memory LcmService — overrides only [subscribe] (raw bytes) so
/// the production [subscribeAs] decode path runs unchanged. Exposes
/// [emitString] which encodes a [StringT] exactly the way the C++
/// publisher would, so what hits the subscriber is a real LCM frame.
class _FakeLcmService extends LcmService {
  final Map<String, StreamController<LcmDecodedRaw>> controllers = {};

  @override
  Stream<LcmDecodedRaw> subscribe(String channel,
      {SubscribeOptions options = const SubscribeOptions()}) {
    return controllers
        .putIfAbsent(channel,
            () => StreamController<LcmDecodedRaw>.broadcast())
        .stream;
  }

  void emitString(String channel, String value) {
    final msg = StringT(timestamp: 1, value: value);
    // 8 byte fingerprint + 8 byte timestamp + 4 byte length + bytes + 1 NUL.
    final size = 8 + 8 + 4 + value.codeUnits.length + 1;
    final buf = LcmBuffer(size);
    msg.encode(buf);
    controllers[channel]?.add(LcmDecodedRaw(
      topic: channel,
      utime: 0,
      data: buf.uint8List,
    ));
  }
}

void main() {
  // rootNavigatorKey.currentContext (used by the dialog path) reaches
  // through WidgetsBinding.instance, which must be initialized even for
  // pure-Dart provider tests in this file.
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> drain() async {
    // Drain the microtask queue so a broadcast-stream add → listener
    // dispatch → notifier state = message round-trip completes.
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('state updates with the decoded message when an error is received',
      () async {
    final fake = _FakeLcmService();
    final container = ProviderContainer(
      overrides: [lcmServiceProvider.overrideWith((ref) => fake)],
    );
    addTearDown(container.dispose);

    // listen forces eager build; the notifier's build() then subscribes.
    container.listen(errorMessageServiceProvider, (_, __) {},
        fireImmediately: true);
    expect(container.read(errorMessageServiceProvider), isNull);

    fake.emitString(Channels.errorMessages, 'motor stalled');
    // Let the broadcast controller dispatch.
    await drain();

    expect(container.read(errorMessageServiceProvider), 'motor stalled');
  });

  test('latest error wins when multiple errors arrive', () async {
    final fake = _FakeLcmService();
    final container = ProviderContainer(
      overrides: [lcmServiceProvider.overrideWith((ref) => fake)],
    );
    addTearDown(container.dispose);

    container.listen(errorMessageServiceProvider, (_, __) {},
        fireImmediately: true);

    fake.emitString(Channels.errorMessages, 'first');
    await drain();
    fake.emitString(Channels.errorMessages, 'second');
    await drain();

    expect(container.read(errorMessageServiceProvider), 'second');
  });

  test('disposing the container cancels the LCM subscription', () async {
    final fake = _FakeLcmService();
    final container = ProviderContainer(
      overrides: [lcmServiceProvider.overrideWith((ref) => fake)],
    );

    container.listen(errorMessageServiceProvider, (_, __) {},
        fireImmediately: true);
    // Trigger lazy stream attachment.
    fake.emitString(Channels.errorMessages, 'init');
    await drain();

    final controller = fake.controllers[Channels.errorMessages]!;
    expect(controller.hasListener, isTrue);

    container.dispose();
    // The provider's onDispose cancels the subscription.
    await drain();
    expect(controller.hasListener, isFalse,
        reason:
            'provider must cancel its LCM subscription on dispose so the '
            'broadcast controller can release its transport sub');
  });

  test('LcmBuffer suppress: confirms helper matches StringT decode round-trip',
      () {
    // Round-trip safeguard so the fake stays honest if StringT changes.
    final msg = StringT(timestamp: 42, value: 'hello');
    const value = 'hello';
    final size = 8 + 8 + 4 + value.codeUnits.length + 1;
    final buf = LcmBuffer(size);
    msg.encode(buf);

    final decoded = StringT.decode(
      LcmBuffer.fromUint8List(Uint8List.fromList(buf.uint8List)),
    );
    expect(decoded.timestamp, 42);
    expect(decoded.value, 'hello');
  });
}
