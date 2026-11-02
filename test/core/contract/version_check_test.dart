import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stpvelox/core/contract/version_check.dart';

// Cases from raccoon-transport contract/COMPONENT_VERSION_CHECK.md (own version v73).
const cases = <(String, String, String?)>[
  ('"v73"', 'ok', null),
  ('"73"', 'ok', null),
  ('" v73 "', 'ok', null),
  ('"V73"', 'ok', null),
  ('"v74"', 'version-mismatch', null),
  ('"v073"', 'version-mismatch', null),
  ('"dev"', 'dev-warnung', 'version-omitted'),
  ('""', 'bundle-fehler', 'version-field-empty'),
  ('"  "', 'bundle-fehler', 'version-field-empty'),
  ('73', 'bundle-fehler', 'version-field-missing'),
];

String write(String content) {
  final dir = Directory.systemTemp.createTempSync('botui_version_');
  addTearDown(() => dir.deleteSync(recursive: true));
  final path = '${dir.path}/bundle.json';
  File(path).writeAsStringSync(content);
  return path;
}

void main() {
  for (final (entry, result, reason) in cases) {
    test('entry $entry is $result', () {
      final path = write('{"bundle":"b","components":{"botui":$entry}}');
      final check = botuiVersionCheck('v73', bundleFile: path)!;
      expect(check.name, 'version');
      expect(check.result, result);
      expect(check.reason, reason);
    });
  }

  test('missing entry and missing components', () {
    for (final text in ['{"components":{"raccoon-cli":"v1"}}', '{"contract_hash":"x"}']) {
      final check = botuiVersionCheck('73', bundleFile: write(text))!;
      expect(check.result, 'bundle-fehler');
      expect(check.reason, 'version-field-missing');
      expect(check.message, contains('no version for botui'));
    }
  });

  test('the mismatch message names both sides', () {
    final check = botuiVersionCheck('v73', bundleFile: write('{"bundle":"2026.11.02","components":{"botui":"v74"}}'))!;
    expect(check.message,
        'component version mismatch: botui is v73 but bundle 2026.11.02 expects v74; update or reflash so all components match');
    expect(check.expected, 'v74');
  });

  test('no readable bundle means no check', () {
    expect(botuiVersionCheck('73', bundleFile: '/nonexistent/bundle.json'), isNull);
    expect(botuiVersionCheck('73', bundleFile: write('{nope')), isNull);
    expect(botuiVersionCheck('73', bundleFile: write('[1]')), isNull);
  });
}
