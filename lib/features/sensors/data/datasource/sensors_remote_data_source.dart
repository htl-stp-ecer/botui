import 'package:stpvelox/features/sensors/domain/entities/sensor.dart';
import 'package:stpvelox/features/sensors/domain/entities/sensor_category.dart';
import 'package:stpvelox/features/sensors/domain/entities/sensor_type.dart';
import 'package:stpvelox/features/sensors/presentation/screens/quaternion_screen.dart';
import 'package:stpvelox/features/sensors/presentation/screens/system_health_screen.dart';
import 'package:stpvelox/features/sensors/presentation/screens/sensor_graph_screen.dart';
import 'package:stpvelox/features/sensors/presentation/screens/sensor_motor_screen.dart';
import 'package:stpvelox/features/sensors/presentation/screens/sensor_servo_screen.dart';
import 'package:stpvelox/features/camera/presentation/pages/camera_menu_screen.dart';

abstract class SensorsRemoteDataSource {
  Future<List<Sensor>> fetchSensors();
}

class SensorsRemoteDataSourceImpl implements SensorsRemoteDataSource {
  Sensor getAnalogSensor(int port) {
    return Sensor(
        category: SensorCategory.analog,
        name: 'Analog $port',
        getSensorScreen: (sensor) => SensorGraphScreen(
            sensor: sensor,
            graphMin: 0,
            graphMax: 4095,
            sensorType: SensorType.analog,
            port: port));
  }

  Sensor getDigitalSensor(int port) {
    return Sensor(
        category: SensorCategory.digital,
        name: 'Digital $port',
        getSensorScreen: (sensor) => SensorGraphScreen(
            sensor: sensor,
            graphMin: 0,
            graphMax: 1,
            sensorType: SensorType.digital,
            port: port));
  }

  Sensor getMotorSensor(int port) {
    return Sensor(
        category: SensorCategory.motor,
        name: 'Motor $port',
        getSensorScreen: (sensor) =>
            SensorMotorScreen(sensor: sensor, port: port));
  }

  Sensor getServoSensor(int port) {
    return Sensor(
        category: SensorCategory.servo,
        name: 'Servo $port',
        getSensorScreen: (sensor) =>
            SensorServoScreen(sensor: sensor, port: port));
  }

  @override
  Future<List<Sensor>> fetchSensors() async {
    return [
      // Analog sensors (0-5)
      for (int port = 0; port < 6; port++) getAnalogSensor(port),

      // Digital sensors (0-9)
      for (int port = 0; port < 11; port++) getDigitalSensor(port),

      // Motor sensors (0-3)
      for (int port = 0; port < 4; port++) getMotorSensor(port),

      // Servo sensors (0-3)
      for (int port = 0; port < 4; port++) getServoSensor(port),

      // IMU sensors - using LCM system
      Sensor(
        category: SensorCategory.gyro,
        name: 'Gyro X',
        getSensorScreen: (sensor) => SensorGraphScreen(
          sensor: sensor,
          graphMin: -180,
          graphMax: 180,
          sensorType: SensorType.gyroX,
        ),
      ),
      Sensor(
        category: SensorCategory.gyro,
        name: 'Gyro Y',
        getSensorScreen: (sensor) => SensorGraphScreen(
          sensor: sensor,
          graphMin: -180,
          graphMax: 180,
          sensorType: SensorType.gyroY,
        ),
      ),
      Sensor(
        category: SensorCategory.gyro,
        name: 'Gyro Z',
        getSensorScreen: (sensor) => SensorGraphScreen(
          sensor: sensor,
          graphMin: -180,
          graphMax: 180,
          sensorType: SensorType.gyroZ,
        ),
      ),
      Sensor(
        category: SensorCategory.accel,
        name: 'Accel X',
        getSensorScreen: (sensor) => SensorGraphScreen(
          sensor: sensor,
          graphMin: -10,
          graphMax: 10,
          sensorType: SensorType.accelX,
        ),
      ),
      Sensor(
        category: SensorCategory.accel,
        name: 'Accel Y',
        getSensorScreen: (sensor) => SensorGraphScreen(
          sensor: sensor,
          graphMin: -10,
          graphMax: 10,
          sensorType: SensorType.accelY,
        ),
      ),
      Sensor(
        category: SensorCategory.accel,
        name: 'Accel Z',
        getSensorScreen: (sensor) => SensorGraphScreen(
          sensor: sensor,
          graphMin: -10,
          graphMax: 10,
          sensorType: SensorType.accelZ,
        ),
      ),
      Sensor(
        category: SensorCategory.mag,
        name: 'Mag X',
        getSensorScreen: (sensor) => SensorGraphScreen(
          sensor: sensor,
          graphMin: -256,
          graphMax: 256,
          sensorType: SensorType.magX,
        ),
      ),
      Sensor(
        category: SensorCategory.mag,
        name: 'Mag Y',
        getSensorScreen: (sensor) => SensorGraphScreen(
          sensor: sensor,
          graphMin: -256,
          graphMax: 256,
          sensorType: SensorType.magY,
        ),
      ),
      Sensor(
        category: SensorCategory.mag,
        name: 'Mag Z',
        getSensorScreen: (sensor) => SensorGraphScreen(
          sensor: sensor,
          graphMin: -256,
          graphMax: 256,
          sensorType: SensorType.magZ,
        ),
      ),
      // Quaternion / Orientation sensor
      Sensor(
        category: SensorCategory.orientation,
        name: 'Orientation',
        getSensorScreen: (sensor) => QuaternionScreen(sensor: sensor),
      ),
      // Heading sensor
      Sensor(
        category: SensorCategory.heading,
        name: 'Heading',
        getSensorScreen: (sensor) => SensorGraphScreen(
          sensor: sensor,
          graphMin: 0,
          graphMax: 360,
          sensorType: SensorType.heading,
        ),
      ),
      // Camera
      Sensor(
        category: SensorCategory.camera,
        name: 'Camera',
        getSensorScreen: (sensor) => const CameraMenuScreen(),
      ),
      // System health (CPU, RAM, Disk, Temp, Battery, Uptime)
      Sensor(
        category: SensorCategory.system,
        name: 'System',
        getSensorScreen: (sensor) => const SystemHealthScreen(),
      ),
    ];
  }
}
