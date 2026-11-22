import 'package:stpvelox/core/service/raccoon_execution_client.dart';
import 'package:stpvelox/features/camera/domain/camera_models.dart';

/// What the camera menu configures: the backend that opens the camera, or the processor that runs on its frames
/// while the UI uses the camera.
enum CamConfigKind {
  backend('backends', 'backend', 'config', 'Camera backend'),
  processor('processors', 'processor', 'processors/config', 'Camera processor');

  const CamConfigKind(
    this.listPath,
    this.choiceKey,
    this.configPath,
    this.title,
  );

  /// `/api/v1/camera/<listPath>` lists them and `/<listPath>/describe` describes one. The list in the
  /// answer has the same key.
  final String listPath;

  /// The key of the saved choice in the answer.
  final String choiceKey;

  /// `/api/v1/camera/<configPath>` is the saved choice.
  final String configPath;

  /// `Camera backend` or `Camera processor`.
  final String title;

  /// `backend` or `processor`.
  String get noun => choiceKey;

  /// The folder of the values typed here, per built-in class.
  String get settingsFolder => listPath;
}

/// The camera endpoints of the robot server (`/api/v1/camera/...`): which
/// backends and processors there are, what they can be configured with, and the choice.
class CameraConfigApi {
  CameraConfigApi(this._client);

  final RaccoonExecutionClient _client;

  static Future<CameraConfigApi> create() async =>
      CameraConfigApi(await RaccoonExecutionClient.create());

  /// Built-in ones first, then those found in the projects on the robot.
  Future<List<CamBackendInfo>> list(CamConfigKind kind) async {
    final json =
        await _client.requestJson('GET', '/api/v1/camera/${kind.listPath}');
    return ((json[kind.listPath] as List?) ?? const [])
        .map((b) => CamBackendInfo.fromJson(b as Map<String, dynamic>))
        .toList();
  }

  /// [item] with its options filled in.
  Future<CamBackendInfo> describe(CamConfigKind kind, CamBackendInfo item) async {
    final query = {
      'path': item.path,
      if (item.projectId != null) 'project_id': item.projectId!,
    };
    final path = Uri(
      path: '/api/v1/camera/${kind.listPath}/describe',
      queryParameters: query,
    ).toString();
    final json = await _client.requestJson('GET', path);
    return item.withOptions(
      ((json['options'] as List?) ?? const [])
          .map((o) => CamOption.fromJson(o as Map<String, dynamic>))
          .toList(),
    );
  }

  /// The choice made on the robot, or null if none was.
  Future<CamBackendChoice?> savedChoice(CamConfigKind kind) async {
    final json =
        await _client.requestJson('GET', '/api/v1/camera/${kind.configPath}');
    final choice = json[kind.choiceKey];
    return choice is Map<String, dynamic>
        ? CamBackendChoice.fromJson(choice)
        : null;
  }

  /// Keeps [cfg] as the configuration of [item]; the server checks it
  /// first and answers with the values as their declared types.
  Future<CamBackendChoice> save(
    CamConfigKind kind,
    CamBackendInfo item,
    Map<String, dynamic> cfg,
  ) async {
    final json = await _client.requestJson(
      'PUT',
      '/api/v1/camera/${kind.configPath}',
      body: {
        'path': item.path,
        'cfg': cfg,
        'project_id': item.projectId,
      },
    );
    return CamBackendChoice.fromJson(json[kind.choiceKey] as Map<String, dynamic>);
  }

  /// Forgets the choice: the camera service goes back to its own default.
  Future<void> clear(CamConfigKind kind) async {
    await _client.requestJson('DELETE', '/api/v1/camera/${kind.configPath}');
  }
}
