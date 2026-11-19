import 'package:stpvelox/core/service/raccoon_execution_client.dart';
import 'package:stpvelox/features/camera/domain/camera_models.dart';

/// The camera endpoints of the robot server (`/api/v1/camera/...`): which
/// backends there are, what they can be configured with, and the choice.
class CameraConfigApi {
  CameraConfigApi(this._client);

  final RaccoonExecutionClient _client;

  static Future<CameraConfigApi> create() async =>
      CameraConfigApi(await RaccoonExecutionClient.create());

  /// Built-in backends first, then those found in the projects on the robot.
  Future<List<CamBackendInfo>> listBackends() async {
    final json = await _client.requestJson('GET', '/api/v1/camera/backends');
    return ((json['backends'] as List?) ?? const [])
        .map((b) => CamBackendInfo.fromJson(b as Map<String, dynamic>))
        .toList();
  }

  /// [backend] with its options filled in.
  Future<CamBackendInfo> describe(CamBackendInfo backend) async {
    final query = {
      'path': backend.path,
      if (backend.projectId != null) 'project_id': backend.projectId!,
    };
    final path = Uri(
      path: '/api/v1/camera/backends/describe',
      queryParameters: query,
    ).toString();
    final json = await _client.requestJson('GET', path);
    return backend.withOptions(
      ((json['options'] as List?) ?? const [])
          .map((o) => CamOption.fromJson(o as Map<String, dynamic>))
          .toList(),
    );
  }

  /// The backend chosen on the robot, or null if none was.
  Future<CamBackendChoice?> savedChoice() async {
    final json = await _client.requestJson('GET', '/api/v1/camera/config');
    final backend = json['backend'];
    return backend is Map<String, dynamic>
        ? CamBackendChoice.fromJson(backend)
        : null;
  }

  /// Keeps [cfg] as the configuration of [backend]; the server checks it
  /// first and answers with the values as their declared types.
  Future<CamBackendChoice> save(
    CamBackendInfo backend,
    Map<String, dynamic> cfg,
  ) async {
    final json = await _client.requestJson(
      'PUT',
      '/api/v1/camera/config',
      body: {
        'path': backend.path,
        'cfg': cfg,
        'project_id': backend.projectId,
      },
    );
    return CamBackendChoice.fromJson(json['backend'] as Map<String, dynamic>);
  }

  /// Forgets the choice: the camera service goes back to its own default.
  Future<void> clear() async {
    await _client.requestJson('DELETE', '/api/v1/camera/config');
  }
}
