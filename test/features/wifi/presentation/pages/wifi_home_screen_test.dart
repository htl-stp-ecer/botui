import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/features/wifi/application/network_mode_notifier.dart';
import 'package:stpvelox/features/wifi/domain/application/network_mode_state.dart';
import 'package:stpvelox/features/wifi/domain/enities/network_mode.dart';
import 'package:stpvelox/features/wifi/presentation/pages/wifi_home_screen.dart';

import '../../../../helpers/fake_lcm.dart';

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

  group('WifiHomeScreen', () {
    testWidgets('shows three mode buttons and client panel by default',
        (tester) async {
      final notifier = TestNetworkModeNotifier(
        initialState: NetworkModeState(mode: NetworkMode.client),
      );

      await tester.pumpWidget(_TestApp(notifier: notifier));
      await tester.pump();

      expect(notifier.loadCalls, 1);
      expect(find.text('Client'), findsOneWidget);
      expect(find.text('Hotspot'), findsOneWidget);
      expect(find.text('LAN Only'), findsOneWidget);
      expect(find.text('Wi-Fi Client Mode'), findsOneWidget);
      expect(find.text('Scan Networks'), findsOneWidget);
      expect(find.text('Saved Networks'), findsOneWidget);
      expect(find.text('Device Info'), findsOneWidget);
      expect(find.text('Wi-Fi Scan'), findsNothing);
      expect(find.text('Hotspot Settings'), findsNothing);
    });

    testWidgets('uses a fixed submenu layout on the target display',
        (tester) async {
      final notifier = TestNetworkModeNotifier(
        initialState: NetworkModeState(mode: NetworkMode.client),
      );

      await tester.pumpWidget(_TestApp(notifier: notifier));
      await tester.pump();

      expect(find.byType(ListView), findsNothing);
      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('expands hotspot panel when hotspot mode is selected',
        (tester) async {
      final notifier = TestNetworkModeNotifier(
        initialState: NetworkModeState(mode: NetworkMode.client),
      );

      await tester.pumpWidget(_TestApp(notifier: notifier));
      await tester.pump();

      await tester.tap(find.text('Hotspot'));
      await tester.pumpAndSettle();

      expect(notifier.updatedModes, [NetworkMode.accessPoint]);
      expect(find.text('Hotspot Mode'), findsOneWidget);
      expect(find.text('Hotspot Settings'), findsOneWidget);
      expect(find.text('Network Status'), findsOneWidget);
      expect(find.text('Wi-Fi Scan'), findsNothing);
      expect(find.text('Saved Networks'), findsNothing);
      expect(find.text('LAN Status'), findsNothing);
    });

    testWidgets('shows loading state and blocks mode changes', (tester) async {
      final notifier = TestNetworkModeNotifier(
        initialState: NetworkModeState(
          mode: NetworkMode.lanOnly,
          isLoading: true,
        ),
      );

      await tester.pumpWidget(_TestApp(notifier: notifier));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.text('Client'));
      await tester.pump();

      expect(notifier.updatedModes, isEmpty);
    });

    testWidgets('shows LAN status without Wi-Fi scan action in LAN only mode',
        (tester) async {
      final notifier = TestNetworkModeNotifier(
        initialState: NetworkModeState(mode: NetworkMode.lanOnly),
      );

      await tester.pumpWidget(_TestApp(notifier: notifier));
      await tester.pump();

      expect(find.text('LAN Only Mode'), findsOneWidget);
      expect(find.text('LAN Status'), findsOneWidget);
      expect(find.text('Wi-Fi Scan'), findsNothing);
    });
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.notifier});

  final TestNetworkModeNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        networkModeProvider.overrideWith(() => notifier),
        ...fakeLcmOverrides(),
      ],
      child: const MaterialApp(
        home: WifiHomeScreen(),
      ),
    );
  }
}

class TestNetworkModeNotifier extends NetworkModeNotifier {
  TestNetworkModeNotifier({required this.initialState});

  final NetworkModeState initialState;
  final List<NetworkMode> updatedModes = [];
  int loadCalls = 0;

  @override
  NetworkModeState build() => initialState;

  @override
  Future<void> loadNetworkMode() async {
    loadCalls += 1;
  }

  @override
  Future<void> updateNetworkMode(NetworkMode mode) async {
    updatedModes.add(mode);
    state = state.copyWith(
      mode: mode,
      isLoading: false,
      errorMessage: () => null,
    );
  }
}
