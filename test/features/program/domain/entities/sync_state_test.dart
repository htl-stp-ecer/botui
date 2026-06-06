import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stpvelox/features/program/domain/entities/sync_state.dart';

void main() {
  group('SyncState.fromJson', () {
    test('parses a fully populated payload', () {
      final s = SyncState.fromJson({
        'version': 7,
        'fingerprint': 'abcdef0123456789deadbeefcafef00d',
        'synced_at': '2026-05-31T08:42:00Z',
        'synced_by': 'tobias@laptop',
      });
      expect(s.version, 7);
      expect(s.fingerprint, startsWith('abcdef0123'));
      expect(s.shortFingerprint, 'abcdef012345');
      expect(s.syncedBy, 'tobias@laptop');
      expect(s.syncedAt, isNotNull);
      expect(s.syncedAt!.toUtc().hour, 8);
      expect(s.hasBeenSynced, isTrue);
    });

    test('treats missing version as 0 and is not hasBeenSynced', () {
      final s = SyncState.fromJson(const {});
      expect(s.version, 0);
      expect(s.fingerprint, isNull);
      expect(s.hasBeenSynced, isFalse);
      expect(s.shortFingerprint, isNull);
    });

    test('hasBeenSynced is false when fingerprint missing despite version > 0',
        () {
      final s = SyncState.fromJson({'version': 3});
      expect(s.hasBeenSynced, isFalse);
    });

    test('tolerates unparseable synced_at by leaving syncedAt null', () {
      final s = SyncState.fromJson({
        'version': 1,
        'fingerprint': 'x' * 64,
        'synced_at': 'not-a-date',
      });
      expect(s.syncedAt, isNull);
    });

    test('coerces numeric version (e.g. JSON double) via toInt', () {
      final s = SyncState.fromJson({'version': 5.0, 'fingerprint': 'a' * 32});
      expect(s.version, 5);
    });
  });

  group('SyncState.loadFromProjectDir', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('sync_state_test_');
    });

    tearDown(() async {
      if (tmp.existsSync()) await tmp.delete(recursive: true);
    });

    test('returns null when .raccoon/sync_state.json does not exist',
        () async {
      final s = await SyncState.loadFromProjectDir(tmp.path);
      expect(s, isNull);
    });

    test('returns parsed state when file is valid', () async {
      final dir = Directory(p.join(tmp.path, '.raccoon'));
      await dir.create(recursive: true);
      await File(p.join(dir.path, 'sync_state.json')).writeAsString(jsonEncode({
        'version': 2,
        'fingerprint': 'f' * 32,
        'synced_by': 'ci',
      }));

      final s = await SyncState.loadFromProjectDir(tmp.path);
      expect(s, isNotNull);
      expect(s!.version, 2);
      expect(s.syncedBy, 'ci');
    });

    test('returns null when file contains garbage rather than throwing',
        () async {
      final dir = Directory(p.join(tmp.path, '.raccoon'));
      await dir.create(recursive: true);
      await File(p.join(dir.path, 'sync_state.json'))
          .writeAsString('{not valid json');

      final s = await SyncState.loadFromProjectDir(tmp.path);
      expect(s, isNull);
    });

    test('returns null when JSON is a list rather than an object', () async {
      final dir = Directory(p.join(tmp.path, '.raccoon'));
      await dir.create(recursive: true);
      await File(p.join(dir.path, 'sync_state.json')).writeAsString('[]');

      final s = await SyncState.loadFromProjectDir(tmp.path);
      expect(s, isNull);
    });
  });
}
