import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stpvelox/features/wifi/presentation/pages/wifi_menu_screen.dart';

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

  testWidgets('shows manage connection and network scan entries',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: WifiMenuScreen(),
        ),
      ),
    );

    expect(find.text('Manage Connection'), findsOneWidget);
    expect(find.text('Network Scan'), findsOneWidget);
    expect(find.text('Scan Networks'), findsNothing);
    expect(find.text('Hotspot Settings'), findsNothing);
    expect(find.text('LAN Status'), findsNothing);
  });
}
