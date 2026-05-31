import 'package:flutter/widgets.dart';

/// A [WidgetsFlutterBinding] subclass that caps the engine's frame
/// production to a fixed maximum rate (default 30 FPS).
///
/// **Why** — on Pi 3 (VC4 GPU) sustained 60 FPS is not reachable for this
/// app: the raster phase clusters around the 16.7 ms vsync period and
/// frequently spills into the next slot, producing jittery 35-48 FPS with
/// frequent 30↔60 oscillation. Capping at a rate the GPU can reliably hit
/// makes playback **uniform** instead of fluctuating, which reads as
/// smoother despite the lower number.
///
/// **How** — intercept [handleBeginFrame] (the engine→framework vsync
/// callback). If the previous accepted frame is younger than
/// [minInterval], reschedule a vsync and **skip** both [handleBeginFrame]
/// and the matching [handleDrawFrame] for this slot. Only the
/// `WidgetsFlutterBinding.scheduleFrame()` path itself is left untouched,
/// so the engine's initial frame and all forced frames still get through.
class CappedFrameBinding extends WidgetsFlutterBinding {
  /// Minimum interval between consecutive rendered frames. 33 ms ≈ 30 FPS.
  static const Duration minInterval = Duration(milliseconds: 33);

  Duration _lastAcceptedTimestamp = Duration.zero;
  bool _skipDrawForCurrentVsync = false;

  /// Install this binding. Must be called before `runApp` instead of
  /// `WidgetsFlutterBinding.ensureInitialized()`.
  static WidgetsBinding ensureInitialized() {
    if (!_initialized) {
      _initialized = true;
      CappedFrameBinding();
    }
    return WidgetsBinding.instance;
  }

  static bool _initialized = false;

  @override
  void handleBeginFrame(Duration? rawTimeStamp) {
    final stamp = rawTimeStamp ?? Duration.zero;
    final since = stamp - _lastAcceptedTimestamp;
    if (_lastAcceptedTimestamp != Duration.zero && since < minInterval) {
      // Too soon — ask the engine for another vsync and drop this one
      // (and its paired drawFrame).
      _skipDrawForCurrentVsync = true;
      scheduleFrame();
      return;
    }
    _skipDrawForCurrentVsync = false;
    _lastAcceptedTimestamp = stamp;
    super.handleBeginFrame(rawTimeStamp);
  }

  @override
  void handleDrawFrame() {
    if (_skipDrawForCurrentVsync) {
      _skipDrawForCurrentVsync = false;
      return;
    }
    super.handleDrawFrame();
  }
}
