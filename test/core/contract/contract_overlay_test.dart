import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:raccoon_transport/raccoon_transport.dart';
import 'package:stpvelox/core/contract/contract_check.dart';
import 'package:stpvelox/core/contract/contract_overlay.dart';

ContractCheckResult result(String outcome, {String? reason, String message = ''}) {
  final r = ContractCheckResult(
    component: 'botui',
    componentVersion: 'v73',
    ownHash: '93ac36836810c9fe',
    ownTransportVersion: 'v69',
    bundleFile: '/etc/raccoon-bundle.json',
  );
  r.expectedHash = '1111111111111111';
  r.expectedTransportVersion = 'v70';
  r.result = outcome;
  r.reason = reason;
  r.message = message;
  return r;
}

Widget app(ContractCheckResult? r) => ProviderScope(
      overrides: [contractCheckResultProvider.overrideWithValue(r)],
      child: const MaterialApp(home: Scaffold(body: Stack(children: [ContractOverlay()]))),
    );

void main() {
  testWidgets('nothing is shown without a result or when everything matches', (tester) async {
    await tester.pumpWidget(app(null));
    expect(find.text('Transport mismatch'), findsNothing);
    await tester.pumpWidget(app(result(contractOk)));
    expect(find.text('Transport mismatch'), findsNothing);
    expect(find.text('DEV TRANSPORT'), findsNothing);
  });

  testWidgets('a mismatch shows the popup until it is acknowledged', (tester) async {
    await tester.pumpWidget(app(result(contractMismatch)));
    expect(find.text('Transport mismatch'), findsOneWidget);
    expect(find.textContaining('flash the latest Raccoon image'), findsOneWidget);
    await tester.tap(find.text('Acknowledge'));
    await tester.pump();
    expect(find.text('Transport mismatch'), findsNothing);
  });

  testWidgets('a bundle error shows the popup with the reason', (tester) async {
    await tester.pumpWidget(app(result(contractBundleError,
        reason: 'file-missing', message: 'transport contract check failed: bundle file is missing: /etc/raccoon-bundle.json')));
    expect(find.textContaining('bundle file is missing'), findsOneWidget);
  });

  testWidgets('dev mode shows only a badge', (tester) async {
    await tester.pumpWidget(app(result(contractDevWarning)));
    expect(find.text('DEV TRANSPORT'), findsOneWidget);
    expect(find.text('Transport mismatch'), findsNothing);
  });

  test('popup message names both sides', () {
    final text = contractPopupMessage(result(contractMismatch));
    expect(text, contains('93ac36836810c9fe'));
    expect(text, contains('1111111111111111'));
    expect(text, contains('v70'));
  });
}
