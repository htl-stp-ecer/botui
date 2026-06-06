import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stpvelox/features/sensors/domain/entities/sensor.dart';
import 'package:stpvelox/features/sensors/domain/entities/sensor_category.dart';
import 'package:stpvelox/features/sensors/domain/usecases/get_sensors.dart';

import '../../../../helpers/mocks.dart';

Sensor _makeSensor(String name) => Sensor(
      category: SensorCategory.analog,
      name: name,
      getSensorScreen: (_) => const SizedBox.shrink(),
    );

void main() {
  late MockSensorRepository repo;
  late GetSensors useCase;

  setUp(() {
    repo = MockSensorRepository();
    useCase = GetSensors(repository: repo);
  });

  test('delegates to repository.getSensors and returns its list', () async {
    final sensors = [_makeSensor('a'), _makeSensor('b')];
    when(() => repo.getSensors()).thenAnswer((_) async => sensors);

    final result = await useCase.execute();

    expect(result, same(sensors));
    verify(() => repo.getSensors()).called(1);
    verifyNoMoreInteractions(repo);
  });

  test('propagates repository errors', () async {
    when(() => repo.getSensors()).thenThrow(StateError('boom'));
    expect(useCase.execute(), throwsA(isA<StateError>()));
  });
}
