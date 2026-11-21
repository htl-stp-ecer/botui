// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bus_servo_sensor.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BusServoSensor)
const busServoSensorProvider = BusServoSensorFamily._();

final class BusServoSensorProvider
    extends $NotifierProvider<BusServoSensor, BusServoState> {
  const BusServoSensorProvider._(
      {required BusServoSensorFamily super.from, required int super.argument})
      : super(
          retry: null,
          name: r'busServoSensorProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$busServoSensorHash();

  @override
  String toString() {
    return r'busServoSensorProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  BusServoSensor create() => BusServoSensor();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BusServoState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BusServoState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BusServoSensorProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$busServoSensorHash() => r'ee7efe914f41e999728a25b22e65d37c38a3ef38';

final class BusServoSensorFamily extends $Family
    with
        $ClassFamilyOverride<BusServoSensor, BusServoState, BusServoState,
            BusServoState, int> {
  const BusServoSensorFamily._()
      : super(
          retry: null,
          name: r'busServoSensorProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  BusServoSensorProvider call(
    int port,
  ) =>
      BusServoSensorProvider._(argument: port, from: this);

  @override
  String toString() => r'busServoSensorProvider';
}

abstract class _$BusServoSensor extends $Notifier<BusServoState> {
  late final _$args = ref.$arg as int;
  int get port => _$args;

  BusServoState build(
    int port,
  );
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(
      _$args,
    );
    final ref = this.ref as $Ref<BusServoState, BusServoState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<BusServoState, BusServoState>,
        BusServoState,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
