// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shutdown_status_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ShutdownStatusService)
const shutdownStatusServiceProvider = ShutdownStatusServiceProvider._();

final class ShutdownStatusServiceProvider
    extends $NotifierProvider<ShutdownStatusService, ShutdownStatus> {
  const ShutdownStatusServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'shutdownStatusServiceProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$shutdownStatusServiceHash();

  @$internal
  @override
  ShutdownStatusService create() => ShutdownStatusService();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShutdownStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShutdownStatus>(value),
    );
  }
}

String _$shutdownStatusServiceHash() =>
    r'a353ee01e761bb4bc9a0b4597e7df1788699a589';

abstract class _$ShutdownStatusService extends $Notifier<ShutdownStatus> {
  ShutdownStatus build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<ShutdownStatus, ShutdownStatus>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<ShutdownStatus, ShutdownStatus>,
        ShutdownStatus,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}

/// Provider for ShutdownStatus (alias for easier use)

@ProviderFor(shutdownStatus)
const shutdownStatusProvider = ShutdownStatusProvider._();

/// Provider for ShutdownStatus (alias for easier use)

final class ShutdownStatusProvider
    extends $FunctionalProvider<ShutdownStatus, ShutdownStatus, ShutdownStatus>
    with $Provider<ShutdownStatus> {
  /// Provider for ShutdownStatus (alias for easier use)
  const ShutdownStatusProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'shutdownStatusProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$shutdownStatusHash();

  @$internal
  @override
  $ProviderElement<ShutdownStatus> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ShutdownStatus create(Ref ref) {
    return shutdownStatus(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShutdownStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShutdownStatus>(value),
    );
  }
}

String _$shutdownStatusHash() => r'68bc0a8fa3653f842aa085feb41adbc1437f207a';
