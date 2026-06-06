// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'digital_sensor.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DigitalSensor)
const digitalSensorProvider = DigitalSensorFamily._();

final class DigitalSensorProvider
    extends $NotifierProvider<DigitalSensor, bool?> {
  const DigitalSensorProvider._(
      {required DigitalSensorFamily super.from, required int super.argument})
      : super(
          retry: null,
          name: r'digitalSensorProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$digitalSensorHash();

  @override
  String toString() {
    return r'digitalSensorProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  DigitalSensor create() => DigitalSensor();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DigitalSensorProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$digitalSensorHash() => r'4db254ebcb3b6b8b3cdc1ce83a2c5592da0d78ee';

final class DigitalSensorFamily extends $Family
    with $ClassFamilyOverride<DigitalSensor, bool?, bool?, bool?, int> {
  const DigitalSensorFamily._()
      : super(
          retry: null,
          name: r'digitalSensorProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  DigitalSensorProvider call(
    int bit,
  ) =>
      DigitalSensorProvider._(argument: bit, from: this);

  @override
  String toString() => r'digitalSensorProvider';
}

abstract class _$DigitalSensor extends $Notifier<bool?> {
  late final _$args = ref.$arg as int;
  int get bit => _$args;

  bool? build(
    int bit,
  );
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(
      _$args,
    );
    final ref = this.ref as $Ref<bool?, bool?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<bool?, bool?>, bool?, Object?, Object?>;
    element.handleValue(ref, created);
  }
}
