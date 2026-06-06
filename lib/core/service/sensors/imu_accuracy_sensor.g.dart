// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'imu_accuracy_sensor.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ImuAccuracySensor)
const imuAccuracySensorProvider = ImuAccuracySensorProvider._();

final class ImuAccuracySensorProvider
    extends $NotifierProvider<ImuAccuracySensor, ImuAccuracy> {
  const ImuAccuracySensorProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'imuAccuracySensorProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$imuAccuracySensorHash();

  @$internal
  @override
  ImuAccuracySensor create() => ImuAccuracySensor();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImuAccuracy value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImuAccuracy>(value),
    );
  }
}

String _$imuAccuracySensorHash() => r'fde308b59b182584943637d7116717135db42d8e';

abstract class _$ImuAccuracySensor extends $Notifier<ImuAccuracy> {
  ImuAccuracy build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<ImuAccuracy, ImuAccuracy>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<ImuAccuracy, ImuAccuracy>, ImuAccuracy, Object?, Object?>;
    element.handleValue(ref, created);
  }
}
