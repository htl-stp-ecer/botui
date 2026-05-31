import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stpvelox/features/sensors/data/datasource/sensors_remote_data_source.dart';
import 'package:stpvelox/features/sensors/data/repositories/sensor_repository_impl.dart';
import 'package:stpvelox/features/sensors/domain/entities/sensor.dart';
import 'package:stpvelox/features/sensors/domain/entities/sensor_category.dart';

class _MockDataSource extends Mock implements SensorsRemoteDataSource {}

void main() {
  test('SensorRepositoryImpl forwards to data source', () async {
    final ds = _MockDataSource();
    final sensors = [
      Sensor(
        category: SensorCategory.analog,
        name: 'A0',
        getSensorScreen: (_) => const SizedBox.shrink(),
      ),
    ];
    when(() => ds.fetchSensors()).thenAnswer((_) async => sensors);

    final repo = SensorRepositoryImpl(remoteDataSource: ds);
    final result = await repo.getSensors();

    expect(result, sensors);
    verify(() => ds.fetchSensors()).called(1);
  });

  group('SensorsRemoteDataSourceImpl.fetchSensors (integration)', () {
    // Hits the real data source — no mocks. Verifies the static
    // configuration that drives the sensor menu so a typo in port counts
    // would fail loudly here instead of silently at runtime.

    test('produces the expected port-count fan-out per category', () async {
      final list = await SensorsRemoteDataSourceImpl().fetchSensors();

      Iterable<Sensor> of(SensorCategory c) =>
          list.where((s) => s.category == c);

      expect(of(SensorCategory.analog).length, 6);
      expect(of(SensorCategory.digital).length, 11);
      expect(of(SensorCategory.motor).length, 4);
      expect(of(SensorCategory.servo).length, 4);
      expect(of(SensorCategory.gyro).length, greaterThanOrEqualTo(3));
      expect(of(SensorCategory.accel).length, greaterThanOrEqualTo(3));
      expect(of(SensorCategory.mag).length, greaterThanOrEqualTo(3));
      expect(of(SensorCategory.system).length, greaterThanOrEqualTo(1));
    });

    test('sensor names are unique', () async {
      final list = await SensorsRemoteDataSourceImpl().fetchSensors();
      final names = list.map((s) => s.name).toList();
      expect(names.toSet().length, names.length,
          reason: 'duplicate sensor names would collide in the picker');
    });
  });
}
