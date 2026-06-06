import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stpvelox/features/settings/usecases/get_device_info.dart';
import 'package:stpvelox/shared/domain/entities/device_info.dart';

import '../../../helpers/mocks.dart';

void main() {
  test('GetDeviceInfo returns repository.getDeviceInfo result', () async {
    final repo = MockWifiRepository();
    final info = DeviceInfo(
      ipAddress: '10.0.0.5',
      macAddress: 'aa:bb:cc:dd:ee:ff',
    );
    when(() => repo.getDeviceInfo()).thenAnswer((_) async => info);

    final result = await GetDeviceInfo(repository: repo).call();

    expect(result, same(info));
    verify(() => repo.getDeviceInfo()).called(1);
  });
}
