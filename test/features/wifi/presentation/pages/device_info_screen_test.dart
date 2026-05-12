import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/core/di/injection.dart';
import 'package:stpvelox/features/wifi/application/wifi_client_notifier.dart';
import 'package:stpvelox/features/wifi/domain/application/wifi_client_state.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_encryption_type.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_network.dart';
import 'package:stpvelox/features/wifi/presentation/pages/device_info_screen.dart';
import 'package:stpvelox/shared/domain/entities/device_info.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.single;
    view
      ..physicalSize = const Size(800, 480)
      ..devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.single;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  group('DeviceInfoScreen', () {
    testWidgets('shows custom loading panel while device info is loading',
        (tester) async {
      final notifier = TestWifiClientNotifier(
        initialState: WifiClientState(isLoading: true),
      );

      await tester.pumpWidget(_DeviceInfoTestApp(notifier: notifier));
      await tester.pump();

      expect(find.text('Collecting network details'), findsOneWidget);
      expect(find.byIcon(Icons.router_rounded), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows device information cards when loaded', (tester) async {
      final notifier = TestWifiClientNotifier(
        initialState: WifiClientState(
          deviceInfo: DeviceInfo(
            ipAddress: '192.168.1.24',
            macAddress: 'AA:BB:CC:DD:EE:FF',
            connectedNetwork: WifiNetwork(
              ssid: 'RobotNet',
              encryptionType: WifiEncryptionType.wpa2Personal,
              isConnected: true,
            ),
          ),
        ),
      );

      await tester.pumpWidget(_DeviceInfoTestApp(notifier: notifier));
      await tester.pump();

      expect(find.text('Addressing'), findsOneWidget);
      expect(find.text('Connection'), findsOneWidget);
      expect(find.text('192.168.1.24'), findsOneWidget);
      expect(find.text('AA:BB:CC:DD:EE:FF'), findsOneWidget);
      expect(find.text('RobotNet'), findsOneWidget);
      expect(find.text('WPA2 Personal'), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
    });
  });
}

class _DeviceInfoTestApp extends StatelessWidget {
  const _DeviceInfoTestApp({required this.notifier});

  final TestWifiClientNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        wifiClientProvider.overrideWith(() => notifier),
        macAddressProvider.overrideWith((ref) async => 'AA:BB:CC:DD:EE:FF'),
      ],
      child: const MaterialApp(
        home: DeviceInfoScreen(),
      ),
    );
  }
}

class TestWifiClientNotifier extends WifiClientNotifier {
  TestWifiClientNotifier({required this.initialState});

  final WifiClientState initialState;
  int loadCalls = 0;

  @override
  WifiClientState build() => initialState;

  @override
  Future<void> loadDeviceInfo() async {
    loadCalls += 1;
  }
}
