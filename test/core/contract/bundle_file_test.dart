import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stpvelox/core/contract/bundle_file.dart';

BundleFile read(String? content) {
  final dir = Directory.systemTemp.createTempSync('bundle_file_');
  addTearDown(() => dir.deleteSync(recursive: true));
  final path = '${dir.path}/raccoon-bundle.json';
  if (content != null) File(path).writeAsStringSync(content);
  return BundleFile.read(path: path);
}

void main() {
  test('shows the bundle name, the hash and every component exactly as written, in file order', () {
    final bundle = read(
        '{"bundle":"2026.11.02-2","contract_hash":"93ac36836810c9fe","components":'
        '{"raccoon-lib":"v155","raccoon-cli":"v173","raccoon-cam":"","botui":"dev","raccoon-transport":"v69"}}');
    expect(bundle.error, isNull);
    expect(bundle.name, '2026.11.02-2');
    expect(bundle.entries.map((e) => '${e.key}=${e.value}').toList(), [
      'contract_hash=93ac36836810c9fe',
      'raccoon-lib=v155',
      'raccoon-cli=v173',
      'raccoon-cam=',
      'botui=dev',
      'raccoon-transport=v69',
    ]);
  });

  test('dev in contract_hash is shown as dev', () {
    final bundle = read('{"contract_hash":"dev","components":{"botui":"v73"}}');
    expect(bundle.entries.first.value, 'dev');
    expect(bundle.name, isNull);
  });

  test('values that are not strings are shown as JSON', () {
    final bundle = read('{"bundle":7,"components":{"botui":73,"x":null}}');
    expect(bundle.name, '7');
    expect(bundle.entries.map((e) => '${e.key}=${e.value}').toList(), ['botui=73', 'x=null']);
  });

  test('a missing file is reported, not thrown', () {
    final bundle = read(null);
    expect(bundle.error, 'missing');
    expect(bundle.entries, isEmpty);
    expect(bundle.name, isNull);
  });

  test('a broken file is reported as unreadable', () {
    expect(read('{"bundle":').error, 'unreadable');
    expect(read('').error, 'unreadable');
    expect(read('["a"]').error, 'unreadable');
  });

  test('a bundle without components still shows the hash', () {
    final bundle = read('{"contract_hash":"93ac36836810c9fe"}');
    expect(bundle.entries.map((e) => e.key).toList(), ['contract_hash']);
  });
}
