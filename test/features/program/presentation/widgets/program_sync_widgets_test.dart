import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stpvelox/features/program/domain/entities/sync_state.dart';
import 'package:stpvelox/features/program/presentation/widgets/program_sync_widgets.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  tearDown(resetScreen);

  group('ProgramVersionChip', () {
    testWidgets('renders red NOT SYNCED when syncState is null',
        (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: Center(child: ProgramVersionChip(syncState: null))),
      );

      expect(find.text('NOT SYNCED'), findsOneWidget);

      final container = tester.widget<Container>(find.byType(Container).first);
      final deco = container.decoration as BoxDecoration;
      expect(deco.color, Colors.red.shade700);
    });

    testWidgets('renders green vN when project has been synced',
        (tester) async {
      const state = SyncState(
        version: 42,
        fingerprint: 'aaaaaaaaaaaa00000000000000000000',
      );
      await pumpScreen(
        tester,
        const Scaffold(body: Center(child: ProgramVersionChip(syncState: state))),
      );

      expect(find.text('v42'), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container).first);
      final deco = container.decoration as BoxDecoration;
      expect(deco.color, Colors.green.shade700);
    });

    testWidgets('treats version>0 with null fingerprint as NOT SYNCED',
        (tester) async {
      // hasBeenSynced requires both — fingerprint loss means we can't
      // verify the artifact even if a version was recorded somewhere.
      const state = SyncState(version: 5);
      await pumpScreen(
        tester,
        const Scaffold(body: Center(child: ProgramVersionChip(syncState: state))),
      );
      expect(find.text('NOT SYNCED'), findsOneWidget);
      expect(find.text('v5'), findsNothing);
    });
  });

  group('ProgramSyncDetailsCard', () {
    testWidgets('shows the warning box when never synced', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(
            body: ProgramSyncDetailsCard(syncState: null)),
      );
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.textContaining('never been pushed'), findsOneWidget);
    });
  });
}
