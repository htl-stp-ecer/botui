// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cam_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider that streams camera detections from the vision daemon.

@ProviderFor(CamDetectionStream)
const camDetectionStreamProvider = CamDetectionStreamProvider._();

/// Provider that streams camera detections from the vision daemon.
final class CamDetectionStreamProvider
    extends $NotifierProvider<CamDetectionStream, CamDetectionData?> {
  /// Provider that streams camera detections from the vision daemon.
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
    r'76fe4b73be1fc901e5553fce91c57cb6115edd08';

/// Provider that streams camera detections from the vision daemon.

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

/// Provider that streams camera JPEG frames from the vision daemon.

@ProviderFor(CamFrameStream)
const camFrameStreamProvider = CamFrameStreamProvider._();

/// Provider that streams camera JPEG frames from the vision daemon.
final class CamFrameStreamProvider
    extends $NotifierProvider<CamFrameStream, CamFrameData?> {
  /// Provider that streams camera JPEG frames from the vision daemon.
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

String _$camFrameStreamHash() => r'2d8b849a87bc2a8e9b17c2ecf90ef136957982bc';

/// Provider that streams camera JPEG frames from the vision daemon.

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
