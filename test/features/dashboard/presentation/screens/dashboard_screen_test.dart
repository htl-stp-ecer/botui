import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stpvelox/features/dashboard/presentation/screens/dashboard_screen.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  tearDown(resetScreen);

  testWidgets('renders the three primary entry tiles', (tester) async {
    await pumpScreen(tester, const DashboardScreen());

    expect(find.text('Sensors & Actors'), findsOneWidget);
    expect(find.text('Programs'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('each tile is wrapped in a GestureDetector so it is tappable',
      (tester) async {
    await pumpScreen(tester, const DashboardScreen());

    // Exactly three tappable dashboard tiles — one per route.
    final gestures = find.byType(GestureDetector);
    expect(gestures, findsNWidgets(3));
  });
}
