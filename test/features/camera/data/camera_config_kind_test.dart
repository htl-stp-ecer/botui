import 'package:flutter_test/flutter_test.dart';
import 'package:stpvelox/features/camera/data/camera_config_api.dart';

void main() {
  test('the backend and the processor have their own endpoints and keys', () {
    expect(CamConfigKind.backend.listPath, 'backends');
    expect(CamConfigKind.backend.configPath, 'config');
    expect(CamConfigKind.backend.choiceKey, 'backend');
    expect(CamConfigKind.processor.listPath, 'processors');
    expect(CamConfigKind.processor.configPath, 'processors/config');
    expect(CamConfigKind.processor.choiceKey, 'processor');
  });

  test('the settings of backends and of processors are kept apart', () {
    expect(CamConfigKind.backend.settingsFolder, isNot(CamConfigKind.processor.settingsFolder));
    expect(CamConfigKind.processor.title, 'Camera processor');
    expect(CamConfigKind.processor.noun, 'processor');
  });
}
