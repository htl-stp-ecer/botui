import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raccoon_transport/raccoon_transport.dart';
import 'package:stpvelox/core/lcm/domain/services/lcm_service.dart';
import 'package:stpvelox/core/lcm/models/lcm_decoded.dart';

/// Subclasses [LcmService] and replaces [subscribe] with an in-memory
/// broadcast stream so tests run without a real RaccoonTransport.
/// [subscribeAs] (which contains the throttle + decode under test) is
/// inherited unchanged.
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

  void emit(String channel) {
    controllers[channel]?.add(LcmDecodedRaw(
      topic: channel,
      utime: 0,
      data: Uint8List(0),
    ));
  }
}

int _decode(_) => 0;

void main() {
  test('subscribeAs throttle caps emission rate to ~60Hz under 200Hz input',
      () async {
    final fake = _FakeLcmService();

    var throttled = 0;
    var baseline = 0;

    final throttledSub = fake
        .subscribeAs<int>('throttled', _decode,
            throttle: kUiSensorSampleRate)
        .listen((_) => throttled++);
    final baselineSub =
        fake.subscribeAs<int>('baseline', _decode).listen((_) => baseline++);

    // 200 events at 5ms cadence = 1s of sustained 200 Hz input.
    for (var i = 0; i < 200; i++) {
      fake.emit('throttled');
      fake.emit('baseline');
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    // Drain the trailing edge of the last throttle window.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await throttledSub.cancel();
    await baselineSub.cancel();

    expect(baseline, 200,
        reason: 'unthrottled stream must pass every event');
    // 1s / 16ms ≈ 62 windows. throttleTime(leading+trailing) emits
    // 1-2 per window, so a generous upper bound of 135 is safe.
    expect(throttled, lessThan(135),
        reason: 'throttled stream must be capped near display refresh');
    expect(throttled, greaterThan(40),
        reason: 'throttled stream must still deliver events');

    // Print actual rate so test logs show the measured reduction.
    // ignore: avoid_print
    print('measured: baseline=$baseline throttled=$throttled '
        '(reduction ${(100 * (1 - throttled / baseline)).toStringAsFixed(1)}%)');
  });

  testWidgets(
      'StreamBuilder rebuild count tracks throttled emission rate',
      (tester) async {
    final fake = _FakeLcmService();
    final stream = fake.subscribeAs<int>('gyro-ish', _decode,
        throttle: kUiSensorSampleRate);

    var rebuilds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StreamBuilder<LcmDecoded<int>>(
          stream: stream,
          builder: (context, snapshot) {
            rebuilds++;
            return Text('${snapshot.data?.value ?? '-'}');
          },
        ),
      ),
    );

    final initialRebuilds = rebuilds;

    // Use runAsync so real Timers (throttleTime) fire on the wall clock.
    await tester.runAsync(() async {
      for (var i = 0; i < 200; i++) {
        fake.emit('gyro-ish');
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    // Pump frames so StreamBuilder's setState calls produce builds.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    final dataRebuilds = rebuilds - initialRebuilds;
    expect(dataRebuilds, lessThan(135),
        reason: 'StreamBuilder rebuilds must be throttled');
    expect(dataRebuilds, greaterThan(0),
        reason: 'StreamBuilder must receive at least one throttled event');

    // ignore: avoid_print
    print('widget rebuilds under 200Hz input: $dataRebuilds');
  });

  test('subscribe releases broadcast controller when last listener cancels',
      () async {
    final fake = _FakeLcmService();
    final stream = fake.subscribe('release-me');
    final controller = fake.controllers['release-me']!;

    final sub1 = stream.listen((_) {});
    final sub2 = stream.listen((_) {});
    expect(controller.hasListener, isTrue);

    await sub1.cancel();
    expect(controller.hasListener, isTrue,
        reason: 'second listener still attached');

    await sub2.cancel();
    expect(controller.hasListener, isFalse,
        reason: 'all listeners gone — transport sub eligible for release');
  });
}
