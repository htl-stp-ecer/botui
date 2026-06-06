// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'temperature_sensor.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TemperatureSensor)
const temperatureSensorProvider = TemperatureSensorProvider._();

final class TemperatureSensorProvider
    extends $NotifierProvider<TemperatureSensor, double?> {
  const TemperatureSensorProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'temperatureSensorProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$temperatureSensorHash();

  @$internal
  @override
  TemperatureSensor create() => TemperatureSensor();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double?>(value),
    );
  }
}

String _$temperatureSensorHash() => r'0fcf11064ecae86bec114558eebf37cbf7c662e8';

abstract class _$TemperatureSensor extends $Notifier<double?> {
  double? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<double?, double?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<double?, double?>, double?, Object?, Object?>;
    element.handleValue(ref, created);
  }
}
