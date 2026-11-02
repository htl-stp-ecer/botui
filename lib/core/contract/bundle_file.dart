import 'dart:convert';
import 'dart:io';

const _defaultBundleFile = '/etc/raccoon-bundle.json';

/// The bundle manifest on the robot (`/etc/raccoon-bundle.json`), shown on the
/// Versions page exactly as it is written there. Never throws: a missing or
/// broken file is reported in [error].
class BundleFile {
  BundleFile._(this.path, this.json, this.error);

  final String path;

  /// The parsed top-level object, or null when the file could not be read.
  final Map<String, dynamic>? json;

  /// `missing` or `unreadable` when [json] is null.
  final String? error;

  /// Reads the file. [path] defaults to `$RACCOON_BUNDLE_FILE`, then `/etc/raccoon-bundle.json`.
  static BundleFile read({String? path}) {
    final resolved = path ?? _envPath() ?? _defaultBundleFile;
    try {
      final file = File(resolved);
      if (!file.existsSync()) return BundleFile._(resolved, null, 'missing');
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, dynamic>) return BundleFile._(resolved, null, 'unreadable');
      return BundleFile._(resolved, decoded, null);
    } on FileSystemException {
      return BundleFile._(resolved, null, 'unreadable');
    } on FormatException {
      return BundleFile._(resolved, null, 'unreadable');
    }
  }

  static String? _envPath() {
    final value = Platform.environment['RACCOON_BUNDLE_FILE'];
    return (value == null || value.isEmpty) ? null : value;
  }

  /// A JSON value as text: strings exactly as written, anything else as JSON.
  static String _text(Object? value) => value is String ? value : jsonEncode(value);

  /// The `bundle` field (the bundle name), or null when absent.
  String? get name => json == null || !json!.containsKey('bundle') ? null : _text(json!['bundle']);

  /// `contract_hash` first, then every entry of `components` in file order, with
  /// the keys and values exactly as they stand in the file (`v173`, `dev`, empty
  /// strings stay empty).
  List<MapEntry<String, String>> get entries {
    final data = json;
    if (data == null) return const [];
    final result = <MapEntry<String, String>>[];
    if (data.containsKey('contract_hash')) {
      result.add(MapEntry('contract_hash', _text(data['contract_hash'])));
    }
    final components = data['components'];
    if (components is Map<String, dynamic>) {
      for (final e in components.entries) {
        result.add(MapEntry(e.key, _text(e.value)));
      }
    }
    return result;
  }
}
