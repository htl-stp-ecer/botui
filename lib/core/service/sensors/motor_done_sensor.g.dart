// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'motor_done_sensor.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MotorDoneSensor)
const motorDoneSensorProvider = MotorDoneSensorFamily._();

final class MotorDoneSensorProvider
    extends $NotifierProvider<MotorDoneSensor, int?> {
  const MotorDoneSensorProvider._(
      {required MotorDoneSensorFamily super.from, required int super.argument})
      : super(
          retry: null,
          name: r'motorDoneSensorProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$motorDoneSensorHash();

  @override
  String toString() {
    return r'motorDoneSensorProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MotorDoneSensor create() => MotorDoneSensor();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MotorDoneSensorProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$motorDoneSensorHash() => r'e1858eb287316bf3c567a205db042c0969234fca';

final class MotorDoneSensorFamily extends $Family
    with $ClassFamilyOverride<MotorDoneSensor, int?, int?, int?, int> {
  const MotorDoneSensorFamily._()
      : super(
          retry: null,
          name: r'motorDoneSensorProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  MotorDoneSensorProvider call(
    int port,
  ) =>
      MotorDoneSensorProvider._(argument: port, from: this);

  @override
  String toString() => r'motorDoneSensorProvider';
}

abstract class _$MotorDoneSensor extends $Notifier<int?> {
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
