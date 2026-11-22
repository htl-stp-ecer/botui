/// What the camera menu knows about a backend: how to list it and which
/// options it can be configured with. These are the JSON objects of the
/// robot server's `/api/v1/camera/...` endpoints.
class CamOption {
  const CamOption({
    required this.name,
    required this.type,
    this.defaultValue,
    this.required = false,
    this.min,
    this.max,
    this.choices = const [],
    this.length,
    this.description = '',
    this.unit = '',
  });

  final String name;

  /// `int`, `float`, `str`, `bool`, `choice`, `size` (`[width, height]`) or `json` (a list or an object; with
  /// `choices` and a list of strings it is a pick from the choices).
  final String type;
  final Object? defaultValue;
  final bool required;
  final num? min;
  final num? max;
  final List<Object?> choices;
  final int? length;
  final String description;
  final String unit;

  factory CamOption.fromJson(Map<String, dynamic> json) => CamOption(
        name: json['name'] as String,
        type: json['type'] as String,
        defaultValue: json['default'],
        required: json['required'] as bool? ?? false,
        min: json['min'] as num?,
        max: json['max'] as num?,
        choices: ((json['choices'] as List?) ?? const []).cast<Object?>(),
        length: (json['length'] as num?)?.toInt(),
        description: json['description'] as String? ?? '',
        unit: json['unit'] as String? ?? '',
      );
}

class CamBackendInfo {
  const CamBackendInfo({
    required this.path,
    required this.name,
    this.description = '',
    this.isBuiltIn = true,
    this.projectName,
    this.projectId,
    this.projectDir,
    this.options = const [],
  });

  /// `module:Class`, as the camera service imports it.
  final String path;
  final String name;
  final String description;
  final bool isBuiltIn;
  final String? projectName;
  final String? projectId;
  final String? projectDir;

  /// Empty in the list; filled when the backend is described.
  final List<CamOption> options;

  /// `Built-In` or `Project (<name>)`.
  String get origin =>
      isBuiltIn ? 'Built-In' : 'Project (${projectName ?? '?'})';

  /// What the dropdown shows.
  String get label => '$origin · $name';

  /// Unique among the backends of the list (two projects may have the same path).
  String get key => '${projectId ?? ''}|$path';

  factory CamBackendInfo.fromJson(Map<String, dynamic> json) {
    final origin = (json['origin'] as Map?) ?? const {};
    return CamBackendInfo(
      path: json['path'] as String,
      name: json['name'] as String? ?? (json['path'] as String),
      description: json['description'] as String? ?? '',
      isBuiltIn: (origin['kind'] as String? ?? 'builtin') == 'builtin',
      projectName: origin['project'] as String?,
      projectId: json['project_id'] as String?,
      projectDir: json['project_dir'] as String?,
      options: ((json['options'] as List?) ?? const [])
          .map((o) => CamOption.fromJson(o as Map<String, dynamic>))
          .toList(),
    );
  }

  CamBackendInfo withOptions(List<CamOption> options) => CamBackendInfo(
        path: path,
        name: name,
        description: description,
        isBuiltIn: isBuiltIn,
        projectName: projectName,
        projectId: projectId,
        projectDir: projectDir,
        options: options,
      );
}

/// The backend chosen on the robot (`GET /api/v1/camera/config`).
class CamBackendChoice {
  const CamBackendChoice({
    required this.path,
    this.cfg = const {},
    this.projectDir,
  });

  final String path;
  final Map<String, dynamic> cfg;
  final String? projectDir;

  factory CamBackendChoice.fromJson(Map<String, dynamic> json) =>
      CamBackendChoice(
        path: json['path'] as String,
        cfg: Map<String, dynamic>.from((json['cfg'] as Map?) ?? const {}),
        projectDir: json['project_dir'] as String?,
      );
}
