// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(transportService)
const transportServiceProvider = TransportServiceProvider._();

final class TransportServiceProvider extends $FunctionalProvider<
    TransportService,
    TransportService,
    TransportService> with $Provider<TransportService> {
  const TransportServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'transportServiceProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$transportServiceHash();

  @$internal
  @override
  $ProviderElement<TransportService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TransportService create(Ref ref) {
    return transportService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TransportService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TransportService>(value),
    );
  }
}

String _$transportServiceHash() => r'89336ab2cb5b4b3c7805964ad56c5486cf154679';
