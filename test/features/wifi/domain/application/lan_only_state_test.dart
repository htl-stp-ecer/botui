import 'package:flutter_test/flutter_test.dart';
import 'package:stpvelox/features/wifi/domain/application/lan_only_state.dart';

void main() {
  group('LanOnlyState.copyWith', () {
    test('clears nullable fields when null is passed explicitly', () {
      final state = LanOnlyState(
        ipAddress: '192.168.0.22',
        macAddress: 'AA:BB:CC:DD:EE:FF',
        errorMessage: 'No ethernet cable detected.',
      );

      final updated = state.copyWith(
        ipAddress: null,
        macAddress: null,
        errorMessage: null,
      );

      expect(updated.ipAddress, isNull);
      expect(updated.macAddress, isNull);
      expect(updated.errorMessage, isNull);
    });

    test('preserves nullable fields when omitted', () {
      final state = LanOnlyState(
        ipAddress: '192.168.0.22',
        macAddress: 'AA:BB:CC:DD:EE:FF',
        errorMessage: 'No ethernet cable detected.',
      );

      final updated = state.copyWith(isLoading: true);

      expect(updated.isLoading, isTrue);
      expect(updated.ipAddress, '192.168.0.22');
      expect(updated.macAddress, 'AA:BB:CC:DD:EE:FF');
      expect(updated.errorMessage, 'No ethernet cable detected.');
    });
  });
}
