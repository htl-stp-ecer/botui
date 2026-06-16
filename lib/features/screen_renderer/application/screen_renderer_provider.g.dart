// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'screen_renderer_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ScreenRenderProvider)
const screenRenderProviderProvider = ScreenRenderProviderProvider._();

final class ScreenRenderProviderProvider
    extends $NotifierProvider<ScreenRenderProvider, Map<String, dynamic>?> {
  const ScreenRenderProviderProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'screenRenderProviderProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$screenRenderProviderHash();

  @$internal
  @override
  ScreenRenderProvider create() => ScreenRenderProvider();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, dynamic>? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, dynamic>?>(value),
    );
  }
}

String _$screenRenderProviderHash() =>
    r'59e4bb6f4ba48e7a2c2f21c2d97d84213773274c';

abstract class _$ScreenRenderProvider extends $Notifier<Map<String, dynamic>?> {
  Map<String, dynamic>? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<Map<String, dynamic>?, Map<String, dynamic>?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<Map<String, dynamic>?, Map<String, dynamic>?>,
        Map<String, dynamic>?,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
