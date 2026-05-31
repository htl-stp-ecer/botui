// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analog_sensor.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AnalogSensor)
const analogSensorProvider = AnalogSensorFamily._();

final class AnalogSensorProvider extends $NotifierProvider<AnalogSensor, int?> {
  const AnalogSensorProvider._(
      {required AnalogSensorFamily super.from, required int super.argument})
      : super(
          retry: null,
          name: r'analogSensorProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$analogSensorHash();

  @override
  String toString() {
    return r'analogSensorProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  AnalogSensor create() => AnalogSensor();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AnalogSensorProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$analogSensorHash() => r'238304318e9b48b973b63179a58c1728838b36eb';

final class AnalogSensorFamily extends $Family
    with $ClassFamilyOverride<AnalogSensor, int?, int?, int?, int> {
  const AnalogSensorFamily._()
      : super(
          retry: null,
          name: r'analogSensorProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  AnalogSensorProvider call(
    int port,
  ) =>
      AnalogSensorProvider._(argument: port, from: this);

  @override
  String toString() => r'analogSensorProvider';
}

abstract class _$AnalogSensor extends $Notifier<int?> {
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
