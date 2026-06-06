// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'magnetometer_sensor.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MagnetometerSensor)
const magnetometerSensorProvider = MagnetometerSensorProvider._();

final class MagnetometerSensorProvider
    extends $NotifierProvider<MagnetometerSensor, Magnetometer?> {
  const MagnetometerSensorProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'magnetometerSensorProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$magnetometerSensorHash();

  @$internal
  @override
  MagnetometerSensor create() => MagnetometerSensor();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Magnetometer? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Magnetometer?>(value),
    );
  }
}

String _$magnetometerSensorHash() =>
    r'466a17c9d75915572c93d7ef9ea876298658be77';

abstract class _$MagnetometerSensor extends $Notifier<Magnetometer?> {
  Magnetometer? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<Magnetometer?, Magnetometer?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<Magnetometer?, Magnetometer?>,
        Magnetometer?,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
