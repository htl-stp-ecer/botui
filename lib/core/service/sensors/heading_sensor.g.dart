// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'heading_sensor.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(HeadingSensor)
const headingSensorProvider = HeadingSensorProvider._();

final class HeadingSensorProvider
    extends $NotifierProvider<HeadingSensor, double?> {
  const HeadingSensorProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'headingSensorProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$headingSensorHash();

  @$internal
  @override
  HeadingSensor create() => HeadingSensor();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double?>(value),
    );
  }
}

String _$headingSensorHash() => r'fef800eab833dec6d7fc1596a19faea85b41a175';

abstract class _$HeadingSensor extends $Notifier<double?> {
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
