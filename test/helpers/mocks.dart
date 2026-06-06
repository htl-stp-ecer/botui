import 'package:mocktail/mocktail.dart';
import 'package:stpvelox/features/sensors/domain/repositories/sensor_repository.dart';
import 'package:stpvelox/features/wifi/domain/enities/network_mode.dart';
import 'package:stpvelox/features/wifi/domain/repositories/i_wifi_repository.dart';

/// Mocktail mocks for the major repository boundaries. Tests `stub`
/// these per-case via `when(() => mock.x()).thenAnswer(...)`.
class MockSensorRepository extends Mock implements SensorRepository {}

class MockWifiRepository extends Mock implements IWifiRepository {}

/// Call once in setUpAll() of any suite that uses mocktail with enums
/// or other non-nullable defaults.
void registerCommonFallbacks() {
  registerFallbackValue(NetworkMode.client);
}
