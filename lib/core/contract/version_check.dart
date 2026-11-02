import 'dart:convert';
import 'dart:io';

import 'package:raccoon_transport/raccoon_transport.dart';

const _bundleKey = 'botui';
const _component = 'botui';
const _defaultBundleFile = '/etc/raccoon-bundle.json';

/// `v173` and `173` are the same version; nothing else is normalised.
String _normalize(String value) {
  final t = value.trim();
  return (t.isNotEmpty && (t[0] == 'v' || t[0] == 'V')) ? t.substring(1) : t;
}

String _orUnknown(String? value) => (value == null || value.isEmpty) ? 'unknown' : value;

/// The Bot UI's own version against its `botui` entry in the bundle file
/// (`/etc/raccoon-bundle.json`). Specified for all components in raccoon-transport,
/// `contract/COMPONENT_VERSION_CHECK.md`; the transport's startup check only merges the
/// result (it is handed over as a component check).
///
/// Returns null when the bundle file cannot be read: the transport check reports that.
ComponentCheck? botuiVersionCheck(String version, {String? bundleFile}) {
  final path = bundleFile ??
      ((Platform.environment['RACCOON_BUNDLE_FILE'] ?? '').isNotEmpty
          ? Platform.environment['RACCOON_BUNDLE_FILE']!
          : _defaultBundleFile);

  Object? document;
  try {
    document = jsonDecode(File(path).readAsStringSync());
  } on FileSystemException {
    return null;
  } on FormatException {
    return null;
  }
  if (document is! Map<String, dynamic>) return null;

  final bundle = document['bundle'] is String ? document['bundle'] as String : null;
  final components = document['components'];
  final entry = components is Map<String, dynamic> ? components[_bundleKey] : null;

  if (entry is! String) {
    return ComponentCheck(
      name: 'version',
      result: 'bundle-fehler',
      reason: 'version-field-missing',
      message: 'bundle check failed: bundle file has no version for $_bundleKey: $path',
    );
  }
  final expected = entry.trim();
  if (expected.isEmpty) {
    return ComponentCheck(
      name: 'version',
      result: 'bundle-fehler',
      reason: 'version-field-empty',
      message: 'bundle check failed: bundle file has an empty version for $_bundleKey: $path',
    );
  }
  if (expected == 'dev') {
    return ComponentCheck(
      name: 'version',
      result: 'dev-warnung',
      reason: 'version-omitted',
      expected: expected,
      message: "component version check omitted ('$_bundleKey' is 'dev' in the bundle): "
          '$_component ${_orUnknown(version)} is not compared; mismatches are not enforced',
    );
  }
  if (_normalize(expected) != _normalize(version)) {
    return ComponentCheck(
      name: 'version',
      result: 'version-mismatch',
      expected: expected,
      message: 'component version mismatch: $_component is ${_orUnknown(version)} but bundle '
          '${_orUnknown(bundle)} expects $expected; update or reflash so all components match',
    );
  }
  return ComponentCheck(name: 'version', result: 'ok', expected: expected, message: 'version ok: $version');
}
