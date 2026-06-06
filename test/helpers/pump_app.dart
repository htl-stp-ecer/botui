import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// Forces the test view to the Wombat's 800x480 panel so layouts
/// that depend on physical size (ResponsiveGrid, etc.) match production.
void useWombatScreen([WidgetTester? tester]) {
  final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.single;
  view
    ..physicalSize = const Size(800, 480)
    ..devicePixelRatio = 1.0;
}

void resetScreen() {
  final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.single;
  view.resetPhysicalSize();
  view.resetDevicePixelRatio();
}

/// Wraps [child] in a [ProviderScope] (with optional [overrides]) and a
/// dark [MaterialApp] sized to the Wombat panel, then pumps it.
///
/// Use [overrides] to inject fake repositories / services for the screen
/// under test. The pump uses `pumpAndSettle()` so initial Futures
/// resolve before assertions run.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
  bool settle = true,
}) async {
  useWombatScreen(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: child,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }
}
