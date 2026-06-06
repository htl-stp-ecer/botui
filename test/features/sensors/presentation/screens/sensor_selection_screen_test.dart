import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stpvelox/features/sensors/presentation/screens/sensor_selection_screen.dart';

import '../../../../helpers/fake_lcm.dart';
import '../../../../helpers/pump_app.dart';

void main() {
  tearDown(resetScreen);

  testWidgets('renders one tile per non-IMU category plus a combined IMU tile',
      (tester) async {
    await pumpScreen(tester, const SensorSelectionScreen(),
        overrides: fakeLcmOverrides());

    // Categories rendered as their own tiles (non-IMU):
    expect(find.text('Analog'), findsOneWidget);
    expect(find.text('Digital'), findsOneWidget);
    expect(find.text('Motor'), findsOneWidget);
    expect(find.text('Servo'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);

    // IMU categories collapse into a single 'IMU' tile.
    expect(find.text('IMU'), findsOneWidget);
    expect(find.text('Gyro'), findsNothing);
    expect(find.text('Accel'), findsNothing);
    expect(find.text('Magneto'), findsNothing);
  });

  testWidgets('shows a loading spinner before the future resolves',
      (tester) async {
    await pumpScreen(
      tester,
      const SensorSelectionScreen(),
      overrides: fakeLcmOverrides(),
      settle: false,
    );
    // Before pumpAndSettle the FutureProvider is in loading state.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
