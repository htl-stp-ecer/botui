// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'servo_command_sensor.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ServoCommandSensor)
const servoCommandSensorProvider = ServoCommandSensorFamily._();

final class ServoCommandSensorProvider
    extends $NotifierProvider<ServoCommandSensor, double?> {
  const ServoCommandSensorProvider._(
      {required ServoCommandSensorFamily super.from,
      required int super.argument})
      : super(
          retry: null,
          name: r'servoCommandSensorProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$servoCommandSensorHash();

  @override
  String toString() {
    return r'servoCommandSensorProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ServoCommandSensor create() => ServoCommandSensor();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ServoCommandSensorProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$servoCommandSensorHash() =>
    r'd128e4431f119cdb1d517c31c888ccfbec2e274e';

final class ServoCommandSensorFamily extends $Family
    with
        $ClassFamilyOverride<ServoCommandSensor, double?, double?, double?,
            int> {
  const ServoCommandSensorFamily._()
      : super(
          retry: null,
          name: r'servoCommandSensorProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  ServoCommandSensorProvider call(
    int port,
  ) =>
      ServoCommandSensorProvider._(argument: port, from: this);

  @override
  String toString() => r'servoCommandSensorProvider';
}

abstract class _$ServoCommandSensor extends $Notifier<double?> {
  late final _$args = ref.$arg as int;
  int get port => _$args;

  double? build(
    int port,
  );
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(
      _$args,
    );
    final ref = this.ref as $Ref<double?, double?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<double?, double?>, double?, Object?, Object?>;
    element.handleValue(ref, created);
  }
}
