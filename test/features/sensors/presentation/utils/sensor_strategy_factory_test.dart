import 'package:flutter_test/flutter_test.dart';
import 'package:stpvelox/core/service/sensors/accelerometer_sensor.dart';
import 'package:stpvelox/core/service/sensors/analog_sensor.dart';
import 'package:stpvelox/core/service/sensors/battery_voltage_sensor.dart';
import 'package:stpvelox/core/service/sensors/cpu_temperature_sensor.dart';
import 'package:stpvelox/core/service/sensors/digital_sensor.dart';
import 'package:stpvelox/core/service/sensors/gyro_sensor.dart';
import 'package:stpvelox/core/service/sensors/heading_sensor.dart';
import 'package:stpvelox/core/service/sensors/magnetometer_sensor.dart';
import 'package:stpvelox/core/service/sensors/quaternion_sensor.dart';
import 'package:stpvelox/core/service/sensors/temperature_sensor.dart';
import 'package:stpvelox/features/sensors/domain/entities/sensor_type.dart';
import 'package:stpvelox/features/sensors/presentation/utils/sensor_strategy_factory.dart';

void main() {
  group('SensorStrategyFactory.createStrategy', () {
    test('maps each SensorType to a non-null strategy', () {
      for (final t in SensorType.values) {
        expect(SensorStrategyFactory.createStrategy(t), isNotNull,
            reason: 'missing strategy for $t');
      }
    });

    test('returns the expected concrete strategy per axis', () {
      expect(SensorStrategyFactory.createStrategy(SensorType.analog),
          isA<AnalogSensorReadingStrategy>());
      expect(SensorStrategyFactory.createStrategy(SensorType.digital),
          isA<DigitalSensorReadingStrategy>());
      expect(SensorStrategyFactory.createStrategy(SensorType.gyroX),
          isA<GyroXSensorReadingStrategy>());
      expect(SensorStrategyFactory.createStrategy(SensorType.gyroY),
          isA<GyroYSensorReadingStrategy>());
      expect(SensorStrategyFactory.createStrategy(SensorType.gyroZ),
          isA<GyroZSensorReadingStrategy>());
      expect(SensorStrategyFactory.createStrategy(SensorType.accelX),
          isA<AccelXSensorReadingStrategy>());
      expect(SensorStrategyFactory.createStrategy(SensorType.accelY),
          isA<AccelYSensorReadingStrategy>());
      expect(SensorStrategyFactory.createStrategy(SensorType.accelZ),
          isA<AccelZSensorReadingStrategy>());
      expect(SensorStrategyFactory.createStrategy(SensorType.magX),
          isA<MagXSensorReadingStrategy>());
      expect(SensorStrategyFactory.createStrategy(SensorType.magY),
          isA<MagYSensorReadingStrategy>());
      expect(SensorStrategyFactory.createStrategy(SensorType.magZ),
          isA<MagZSensorReadingStrategy>());
      expect(SensorStrategyFactory.createStrategy(SensorType.quaternionW),
          isA<QuaternionWSensorReadingStrategy>());
      expect(SensorStrategyFactory.createStrategy(SensorType.heading),
          isA<HeadingSensorReadingStrategy>());
      expect(SensorStrategyFactory.createStrategy(SensorType.temperature),
          isA<TemperatureSensorReadingStrategy>());
      expect(SensorStrategyFactory.createStrategy(SensorType.cpuTemperature),
          isA<CpuTemperatureSensorReadingStrategy>());
      expect(SensorStrategyFactory.createStrategy(SensorType.batteryVoltage),
          isA<BatteryVoltageSensorReadingStrategy>());
    });
  });
}
