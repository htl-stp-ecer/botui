// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'motor_position_sensor.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MotorPositionSensor)
const motorPositionSensorProvider = MotorPositionSensorFamily._();

final class MotorPositionSensorProvider
    extends $NotifierProvider<MotorPositionSensor, int?> {
  const MotorPositionSensorProvider._(
      {required MotorPositionSensorFamily super.from,
      required int super.argument})
      : super(
          retry: null,
          name: r'motorPositionSensorProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$motorPositionSensorHash();

  @override
  String toString() {
    return r'motorPositionSensorProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MotorPositionSensor create() => MotorPositionSensor();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MotorPositionSensorProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$motorPositionSensorHash() =>
    r'a936431d95a3270f6e872fcc983bd533b32dfe43';

final class MotorPositionSensorFamily extends $Family
    with $ClassFamilyOverride<MotorPositionSensor, int?, int?, int?, int> {
  const MotorPositionSensorFamily._()
      : super(
          retry: null,
          name: r'motorPositionSensorProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  MotorPositionSensorProvider call(
    int port,
  ) =>
      MotorPositionSensorProvider._(argument: port, from: this);

  @override
  String toString() => r'motorPositionSensorProvider';
}

abstract class _$MotorPositionSensor extends $Notifier<int?> {
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
