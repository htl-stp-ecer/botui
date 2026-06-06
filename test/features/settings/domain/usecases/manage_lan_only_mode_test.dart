import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stpvelox/features/settings/domain/usecases/manage_lan_only_mode.dart';

import '../../../../helpers/mocks.dart';

void main() {
  late MockWifiRepository repo;
  late ManageLanOnlyMode useCase;

  setUp(() {
    repo = MockWifiRepository();
    useCase = ManageLanOnlyMode(repo);
  });

  test('enableLanOnlyMode calls repository.enableLanOnlyMode', () async {
    when(() => repo.enableLanOnlyMode()).thenAnswer((_) async {});
    await useCase.enableLanOnlyMode();
    verify(() => repo.enableLanOnlyMode()).called(1);
    verifyNever(() => repo.disableLanOnlyMode());
  });

  test('disableLanOnlyMode calls repository.disableLanOnlyMode', () async {
    when(() => repo.disableLanOnlyMode()).thenAnswer((_) async {});
    await useCase.disableLanOnlyMode();
    verify(() => repo.disableLanOnlyMode()).called(1);
    verifyNever(() => repo.enableLanOnlyMode());
  });

  test('propagates repository errors on enable', () async {
    when(() => repo.enableLanOnlyMode())
        .thenThrow(StateError('nm down'));
    expect(useCase.enableLanOnlyMode(), throwsA(isA<StateError>()));
  });
}
