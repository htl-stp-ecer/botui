import 'package:flutter_test/flutter_test.dart';
import 'package:stpvelox/core/utils/local_test.dart';
import 'package:stpvelox/core/utils/sudo_process.dart';

// Run with: flutter test --dart-define=LOCAL_TEST=true test/core/utils/sudo_process_local_test_test.dart
// (test-locally.py starts the app this way.)
void main() {
  test('in local test mode SudoProcess runs nothing and looks successful', () async {
    expect(await SudoProcess.isPasswordless('shutdown', ['-h', 'now']), isTrue);

    final shutdown = await SudoProcess.run('shutdown', ['-h', 'now']);
    expect(shutdown.exitCode, 0);
    expect(shutdown.stdout, '');

    final reboot = await SudoProcess.runWith(['reboot']);
    expect(reboot.exitCode, 0);
  }, skip: kLocalTest ? null : 'needs --dart-define=LOCAL_TEST=true');
}
