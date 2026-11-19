import 'dart:convert';
import 'dart:io';

import 'package:stpvelox/core/logging/logging.dart';

final _log = getLogger('CameraBackendSettings');

/// The values typed into "Configure backend", kept per built-in backend in
/// `~/.raccoon/botui-cam-settings/backends/<backend>.json`, so switching to
/// another backend and back (or an app update) does not lose them.
///
/// A plain file, because only the UI reads it. The robot server's saved choice
/// (which backend runs) stays where it is.
class CameraBackendSettingsStore {
  CameraBackendSettingsStore({Directory? directory})
      : _directory = directory ?? _defaultDirectory();

  final Directory _directory;

  static Directory _defaultDirectory() {
    final home = Platform.environment['HOME'] ?? '/home/pi';
    return Directory('$home/.raccoon/botui-cam-settings/backends');
  }

  /// `module:Class` or a name, as a safe file name.
  static String fileName(String backend) =>
      '${backend.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}.json';

  File _file(String backend) => File('${_directory.path}/${fileName(backend)}');

  /// The saved values of [backend], or null if there are none (or the file is
  /// unreadable: it is ignored, the defaults apply).
  Future<Map<String, dynamic>?> load(String backend) async {
    try {
      final file = _file(backend);
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      return json is Map ? Map<String, dynamic>.from(json) : null;
    } catch (error) {
      _log.warning('Could not read the settings of $backend: $error');
      return null;
    }
  }

  /// Writes [cfg]; a failure is logged and does not stop saving the choice.
  Future<void> save(String backend, Map<String, dynamic> cfg) async {
    try {
      await _directory.create(recursive: true);
      final file = _file(backend);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(
        const JsonEncoder.withIndent('  ').convert(cfg),
        flush: true,
      );
      await temporary.rename(file.path);
    } catch (error) {
      _log.warning('Could not write the settings of $backend: $error');
    }
  }

  Future<void> delete(String backend) async {
    try {
      final file = _file(backend);
      if (await file.exists()) await file.delete();
    } catch (error) {
      _log.warning('Could not delete the settings of $backend: $error');
    }
  }
}
