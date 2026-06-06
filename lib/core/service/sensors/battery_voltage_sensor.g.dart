// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'battery_voltage_sensor.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BatteryVoltageSensor)
const batteryVoltageSensorProvider = BatteryVoltageSensorProvider._();

final class BatteryVoltageSensorProvider
    extends $NotifierProvider<BatteryVoltageSensor, double?> {
  const BatteryVoltageSensorProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'batteryVoltageSensorProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$batteryVoltageSensorHash();

  @$internal
  @override
  BatteryVoltageSensor create() => BatteryVoltageSensor();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double?>(value),
    );
  }
}

String _$batteryVoltageSensorHash() =>
    r'f5925b20332b6732c5ff0911dfa0569af1a865a3';

abstract class _$BatteryVoltageSensor extends $Notifier<double?> {
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
