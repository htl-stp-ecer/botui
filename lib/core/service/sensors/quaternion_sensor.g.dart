// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quaternion_sensor.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(QuaternionSensor)
const quaternionSensorProvider = QuaternionSensorProvider._();

final class QuaternionSensorProvider
    extends $NotifierProvider<QuaternionSensor, Quaternion?> {
  const QuaternionSensorProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'quaternionSensorProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$quaternionSensorHash();

  @$internal
  @override
  QuaternionSensor create() => QuaternionSensor();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Quaternion? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Quaternion?>(value),
    );
  }
}

String _$quaternionSensorHash() => r'66e5678f994cda91faf98b4c18d96703efa8f2f4';

abstract class _$QuaternionSensor extends $Notifier<Quaternion?> {
  Quaternion? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<Quaternion?, Quaternion?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<Quaternion?, Quaternion?>, Quaternion?, Object?, Object?>;
    element.handleValue(ref, created);
  }
}
