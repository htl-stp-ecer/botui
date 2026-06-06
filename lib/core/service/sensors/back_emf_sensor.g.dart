// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'back_emf_sensor.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BackEmfSensor)
const backEmfSensorProvider = BackEmfSensorFamily._();

final class BackEmfSensorProvider
    extends $NotifierProvider<BackEmfSensor, int?> {
  const BackEmfSensorProvider._(
      {required BackEmfSensorFamily super.from, required int super.argument})
      : super(
          retry: null,
          name: r'backEmfSensorProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$backEmfSensorHash();

  @override
  String toString() {
    return r'backEmfSensorProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  BackEmfSensor create() => BackEmfSensor();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BackEmfSensorProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$backEmfSensorHash() => r'ed3ee8bfe0ac8a679c9333f39cd0d3fea1a709e5';

final class BackEmfSensorFamily extends $Family
    with $ClassFamilyOverride<BackEmfSensor, int?, int?, int?, int> {
  const BackEmfSensorFamily._()
      : super(
          retry: null,
          name: r'backEmfSensorProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  BackEmfSensorProvider call(
    int port,
  ) =>
      BackEmfSensorProvider._(argument: port, from: this);

  @override
  String toString() => r'backEmfSensorProvider';
}

abstract class _$BackEmfSensor extends $Notifier<int?> {
  late final _$args = ref.$arg as int;
  int get port => _$args;

  int? build(
    int port,
  );
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(
      _$args,
    );
    final ref = this.ref as $Ref<int?, int?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<int?, int?>, int?, Object?, Object?>;
    element.handleValue(ref, created);
  }
}
