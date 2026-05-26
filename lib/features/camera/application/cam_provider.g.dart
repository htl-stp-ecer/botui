// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cam_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider that streams camera detections from LCM (always active)

@ProviderFor(CamDetectionStream)
const camDetectionStreamProvider = CamDetectionStreamProvider._();

/// Provider that streams camera detections from LCM (always active)
final class CamDetectionStreamProvider
    extends $NotifierProvider<CamDetectionStream, CamDetectionData?> {
  /// Provider that streams camera detections from LCM (always active)
  const CamDetectionStreamProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'camDetectionStreamProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$camDetectionStreamHash();

  @$internal
  @override
  CamDetectionStream create() => CamDetectionStream();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CamDetectionData? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CamDetectionData?>(value),
    );
  }
}

String _$camDetectionStreamHash() =>
    r'7a999f6ceef4f853140cc64df9a1d94eb146ebd4';

/// Provider that streams camera detections from LCM (always active)

abstract class _$CamDetectionStream extends $Notifier<CamDetectionData?> {
  CamDetectionData? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<CamDetectionData?, CamDetectionData?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<CamDetectionData?, CamDetectionData?>,
        CamDetectionData?,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}

/// Provider that streams camera frames from LCM (active only when viewer is open)

@ProviderFor(CamFrameStream)
const camFrameStreamProvider = CamFrameStreamProvider._();

/// Provider that streams camera frames from LCM (active only when viewer is open)
final class CamFrameStreamProvider
    extends $NotifierProvider<CamFrameStream, CamFrameData?> {
  /// Provider that streams camera frames from LCM (active only when viewer is open)
  const CamFrameStreamProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'camFrameStreamProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$camFrameStreamHash();

  @$internal
  @override
  CamFrameStream create() => CamFrameStream();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CamFrameData? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CamFrameData?>(value),
    );
  }
}

String _$camFrameStreamHash() => r'e6efb64137fe394b9a73a788033f94236b9a3963';

/// Provider that streams camera frames from LCM (active only when viewer is open)

abstract class _$CamFrameStream extends $Notifier<CamFrameData?> {
  CamFrameData? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<CamFrameData?, CamFrameData?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<CamFrameData?, CamFrameData?>,
        CamFrameData?,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
