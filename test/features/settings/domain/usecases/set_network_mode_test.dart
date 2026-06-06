import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stpvelox/features/settings/domain/usecases/set_network_mode.dart';
import 'package:stpvelox/features/wifi/domain/enities/network_mode.dart';

import '../../../../helpers/mocks.dart';

void main() {
  setUpAll(registerCommonFallbacks);

  late MockWifiRepository repo;
  late SetNetworkMode useCase;

  setUp(() {
    repo = MockWifiRepository();
    useCase = SetNetworkMode(repo);
  });

  for (final mode in NetworkMode.values) {
    test('forwards $mode to repository.setNetworkMode', () async {
      when(() => repo.setNetworkMode(any())).thenAnswer((_) async {});
      await useCase.call(mode);
      verify(() => repo.setNetworkMode(mode)).called(1);
    });
  }
}
