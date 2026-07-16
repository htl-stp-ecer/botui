// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'program_lifecycle_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// keepAlive: this holds the app-global "currently running program" session.
/// It must NOT autoDispose — under the dynamic-UI (screen_render) rebuild storm
/// an autoDispose provider is created and torn down many times per second,
/// which previously (a) fired onDispose→kill() spuriously (cancel storms) and
/// (b) threw "Ref after disposed" when stopProgram wrote `state` after an await.

@ProviderFor(ProgramLifecycleService)
const programLifecycleServiceProvider = ProgramLifecycleServiceProvider._();

/// keepAlive: this holds the app-global "currently running program" session.
/// It must NOT autoDispose — under the dynamic-UI (screen_render) rebuild storm
/// an autoDispose provider is created and torn down many times per second,
/// which previously (a) fired onDispose→kill() spuriously (cancel storms) and
/// (b) threw "Ref after disposed" when stopProgram wrote `state` after an await.
final class ProgramLifecycleServiceProvider
    extends $NotifierProvider<ProgramLifecycleService, ProgramSession?> {
  /// keepAlive: this holds the app-global "currently running program" session.
  /// It must NOT autoDispose — under the dynamic-UI (screen_render) rebuild storm
  /// an autoDispose provider is created and torn down many times per second,
  /// which previously (a) fired onDispose→kill() spuriously (cancel storms) and
  /// (b) threw "Ref after disposed" when stopProgram wrote `state` after an await.
  const ProgramLifecycleServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'programLifecycleServiceProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$programLifecycleServiceHash();

  @$internal
  @override
  ProgramLifecycleService create() => ProgramLifecycleService();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProgramSession? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProgramSession?>(value),
    );
  }
}

String _$programLifecycleServiceHash() =>
    r'70c11ea336591ab81794168ab170d48c532d61c5';

/// keepAlive: this holds the app-global "currently running program" session.
/// It must NOT autoDispose — under the dynamic-UI (screen_render) rebuild storm
/// an autoDispose provider is created and torn down many times per second,
/// which previously (a) fired onDispose→kill() spuriously (cancel storms) and
/// (b) threw "Ref after disposed" when stopProgram wrote `state` after an await.

abstract class _$ProgramLifecycleService extends $Notifier<ProgramSession?> {
  ProgramSession? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<ProgramSession?, ProgramSession?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<ProgramSession?, ProgramSession?>,
        ProgramSession?,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
