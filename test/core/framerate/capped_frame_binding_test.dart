import 'package:flutter_test/flutter_test.dart';
import 'package:stpvelox/core/framerate/capped_frame_binding.dart';

void main() {
  // CappedFrameBinding subclasses WidgetsFlutterBinding; in a test runner
  // the binding is already TestWidgetsFlutterBinding, so we can't validate
  // the runtime swap here. These tests guard the public contract that
  // production code (main.dart) depends on.

  test('minInterval is 33ms (≈30 FPS Pi 3 cap — regression guard)', () {
    // If this is ever changed without intent the Pi 3 frame pacing the
    // bridge poll thread (also 33ms) was tuned against will drift.
    expect(CappedFrameBinding.minInterval,
        const Duration(milliseconds: 33));
  });

  test('ensureInitialized is idempotent and never throws on second call', () {
    // The test runner already installed TestWidgetsFlutterBinding, so the
    // internal _initialized guard is the only path that runs here. We
    // call twice to prove a misordered main() (e.g. via a hot restart)
    // does not crash.
    expect(CappedFrameBinding.ensureInitialized, returnsNormally);
    expect(CappedFrameBinding.ensureInitialized, returnsNormally);
  });
}
