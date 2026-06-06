// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'accelerometer_sensor.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AccelerometerSensor)
const accelerometerSensorProvider = AccelerometerSensorProvider._();

final class AccelerometerSensorProvider
    extends $NotifierProvider<AccelerometerSensor, Accel?> {
  const AccelerometerSensorProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'accelerometerSensorProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$accelerometerSensorHash();

  @$internal
  @override
  AccelerometerSensor create() => AccelerometerSensor();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Accel? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Accel?>(value),
    );
  }
}

String _$accelerometerSensorHash() =>
    r'51534c596088ebc665c32cda4f05b44b480a6de9';

abstract class _$AccelerometerSensor extends $Notifier<Accel?> {
  Accel? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<Accel?, Accel?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<Accel?, Accel?>, Accel?, Object?, Object?>;
    element.handleValue(ref, created);
  }
}
