// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'servo_sensor.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ServoModeSensor)
const servoModeSensorProvider = ServoModeSensorFamily._();

final class ServoModeSensorProvider
    extends $NotifierProvider<ServoModeSensor, ServoMode?> {
  const ServoModeSensorProvider._(
      {required ServoModeSensorFamily super.from, required int super.argument})
      : super(
          retry: null,
          name: r'servoModeSensorProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$servoModeSensorHash();

  @override
  String toString() {
    return r'servoModeSensorProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ServoModeSensor create() => ServoModeSensor();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ServoMode? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ServoMode?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ServoModeSensorProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$servoModeSensorHash() => r'f40bd3e36a172aebaff5fc96f37ee7aafb79c023';

final class ServoModeSensorFamily extends $Family
    with
        $ClassFamilyOverride<ServoModeSensor, ServoMode?, ServoMode?,
            ServoMode?, int> {
  const ServoModeSensorFamily._()
      : super(
          retry: null,
          name: r'servoModeSensorProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  ServoModeSensorProvider call(
    int port,
  ) =>
      ServoModeSensorProvider._(argument: port, from: this);

  @override
  String toString() => r'servoModeSensorProvider';
}

abstract class _$ServoModeSensor extends $Notifier<ServoMode?> {
  late final _$args = ref.$arg as int;
  int get port => _$args;

  ServoMode? build(
    int port,
  );
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(
      _$args,
    );
    final ref = this.ref as $Ref<ServoMode?, ServoMode?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<ServoMode?, ServoMode?>, ServoMode?, Object?, Object?>;
    element.handleValue(ref, created);
  }
}
