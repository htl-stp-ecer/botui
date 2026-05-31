import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stpvelox/features/settings/domain/entities/setting.dart';

void main() {
  group('Setting constructor invariant', () {
    test('button setting without value is OK', () {
      expect(
        () => Setting(
          icon: Icons.wifi,
          label: 'Wifi',
          color: Colors.green,
          type: SettingType.button,
          onTap: (_) {},
        ),
        returnsNormally,
      );
    });

    test('toggle setting without value getter throws AssertionError', () {
      expect(
        () => Setting(
          icon: Icons.wifi,
          label: 'Wifi',
          color: Colors.green,
          type: SettingType.toggle,
          onTap: (_) {},
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('button setting with a value getter throws AssertionError', () {
      expect(
        () => Setting(
          icon: Icons.wifi,
          label: 'Wifi',
          color: Colors.green,
          type: SettingType.button,
          onTap: (_) {},
          value: () => true,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('toggle setting with a value getter is OK', () {
      expect(
        () => Setting(
          icon: Icons.wifi,
          label: 'Wifi',
          color: Colors.green,
          type: SettingType.toggle,
          onTap: (_) {},
          value: () => false,
        ),
        returnsNormally,
      );
    });
  });
}
