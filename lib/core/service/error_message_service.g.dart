// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'error_message_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ErrorMessageService)
const errorMessageServiceProvider = ErrorMessageServiceProvider._();

final class ErrorMessageServiceProvider
    extends $NotifierProvider<ErrorMessageService, String?> {
  const ErrorMessageServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'errorMessageServiceProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$errorMessageServiceHash();

  @$internal
  @override
  ErrorMessageService create() => ErrorMessageService();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$errorMessageServiceHash() =>
    r'fb43e7a4ddc7cded905d1853c3330d68493cc28c';

abstract class _$ErrorMessageService extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<String?, String?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<String?, String?>, String?, Object?, Object?>;
    element.handleValue(ref, created);
  }
}
