/// True when the app was started by `test-locally.py` (`--dart-define=LOCAL_TEST=true`).
///
/// That is the app on a developer PC, not on the robot: nothing may change the system.
/// [SudoProcess] does not run anything in this mode, it only prints what it would have run.
const bool kLocalTest = bool.fromEnvironment('LOCAL_TEST');

/// True with `test-locally.py --no-debug`: hides the red DEBUG banner in the corner.
const bool kHideDebugBanner = bool.fromEnvironment('HIDE_DEBUG_BANNER');
