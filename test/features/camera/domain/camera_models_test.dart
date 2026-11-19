import 'package:flutter_test/flutter_test.dart';
import 'package:stpvelox/features/camera/domain/camera_models.dart';

void main() {
  group('CamOption', () {
    test('reads what the server sends', () {
      final option = CamOption.fromJson({
        'name': 'resolution',
        'type': 'size',
        'default': [320, 240],
        'required': false,
        'min': null,
        'max': null,
        'choices': [],
        'length': null,
        'description': 'Requested image size',
        'unit': 'px',
      });
      expect(option.name, 'resolution');
      expect(option.type, 'size');
      expect(option.defaultValue, [320, 240]);
      expect(option.unit, 'px');
      expect(option.required, isFalse);
    });

    test('numbers and choices keep their types', () {
      final option = CamOption.fromJson({
        'name': 'fps',
        'type': 'int',
        'default': 15,
        'min': 1,
        'max': 60.5,
        'choices': ['a', 'b'],
        'length': 4,
      });
      expect(option.min, 1);
      expect(option.max, 60.5);
      expect(option.choices, ['a', 'b']);
      expect(option.length, 4);
    });
  });

  group('CamBackendInfo', () {
    test('a built-in backend is labelled Built-In', () {
      final info = CamBackendInfo.fromJson({
        'path': 'raccoon_cam.backends.usb:UsbCameraBackend',
        'name': 'usb',
        'description': 'Delivers frames from a USB camera.',
        'origin': {'kind': 'builtin', 'project': null},
        'project_id': null,
        'options': [
          {'name': 'fps', 'type': 'int', 'default': 15},
        ],
      });
      expect(info.isBuiltIn, isTrue);
      expect(info.label, 'Built-In · usb');
      expect(info.options.single.name, 'fps');
      expect(info.key, '|raccoon_cam.backends.usb:UsbCameraBackend');
    });

    test('a project backend says which project it is from', () {
      final info = CamBackendInfo.fromJson({
        'path': 'src.mine:Mine',
        'name': 'mine',
        'origin': {'kind': 'project', 'project': 'My Robot'},
        'project_id': 'uuid-1',
        'project_dir': '/home/pi/programs/my-robot',
      });
      expect(info.isBuiltIn, isFalse);
      expect(info.label, 'Project (My Robot) · mine');
      expect(info.projectDir, '/home/pi/programs/my-robot');
      expect(info.options, isEmpty);
    });

    test('two projects with the same path are different entries', () {
      CamBackendInfo of(String id) => CamBackendInfo.fromJson({
            'path': 'src.mine:Mine',
            'name': 'mine',
            'origin': {'kind': 'project', 'project': id},
            'project_id': id,
          });
      expect(of('a').key, isNot(of('b').key));
    });

    test('withOptions keeps everything else', () {
      final info = CamBackendInfo.fromJson({
        'path': 'a:B',
        'name': 'b',
        'origin': {'kind': 'project', 'project': 'P'},
        'project_id': 'p1',
      }).withOptions(const [CamOption(name: 'gain', type: 'float')]);
      expect(info.options.single.name, 'gain');
      expect(info.label, 'Project (P) · b');
      expect(info.projectId, 'p1');
    });
  });

  group('CamBackendChoice', () {
    test('reads the saved choice', () {
      final choice = CamBackendChoice.fromJson({
        'path': 'a:B',
        'cfg': {'fps': 20, 'resolution': [640, 480]},
        'project_dir': null,
      });
      expect(choice.path, 'a:B');
      expect(choice.cfg['fps'], 20);
      expect(choice.projectDir, isNull);
    });
  });
}
