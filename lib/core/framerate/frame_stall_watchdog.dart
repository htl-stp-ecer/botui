import 'dart:async';
import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

final _log = Logger('FrameStallWatchdog');

/// Detects a wedged rendering pipeline and recovers from it.
///
/// **Why** — on flutter-pi (Pi 3 / VC4) the framework can end up in a state
/// where everything *except* rendering keeps running: timers fire, touch
/// input is delivered, GoRouter navigates and the transport keeps ticking,
/// but no frame ever reaches the display. The screen freezes on its last
/// image while the logic continues underneath. Observed deterministically on
/// certain dynamic-UI screen transitions (2026-06-13, "Distance Calibration"):
/// no Dart exception, no GPU/DRM kernel fault, the engine simply goes
/// quiescent — raster thread idle in `epoll_wait`, UI isolate parked, the
/// flutter-pi main thread blocked in `select()` waiting for a DRM event that
/// never comes. `scheduleFrame()` stops translating into rendered frames, so
/// the pipeline never wakes itself back up.
///
/// **How** — this watchdog runs on a wall-clock [Timer], NOT a frame callback,
/// so it keeps ticking even after frame production has stopped. A
/// [SchedulerBinding.addTimingsCallback] records whenever a frame actually
/// completes. Each tick:
///
///  * If a frame completed since the last tick → healthy, reset.
///  * Otherwise count the stall. After [_softKickTicks] with no frames, try a
///    soft recovery: force a frame and a synchronous warm-up frame. On a
///    healthy-but-idle screen this renders immediately and clears the stall
///    (so it doubles as a cheap liveness probe). On a wedged pipeline it does
///    nothing.
///  * If *forced* frames still produce nothing after [_hardRestartTicks], the
///    pipeline is genuinely wedged — exit the process. systemd
///    (`Restart=always`, see `systemd/flutter-ui.service`) brings the UI back
///    within a couple of seconds: a brief restart flicker instead of a
///    permanent freeze.
class FrameStallWatchdog with WidgetsBindingObserver {
  FrameStallWatchdog._();

  static final FrameStallWatchdog instance = FrameStallWatchdog._();

  Timer? _timer;
  bool _frameSinceLastTick = false;
  int _stalledTicks = 0;

  /// Wall-clock cadence of the watchdog poll.
  static const Duration _tick = Duration(seconds: 1);

  /// Stall duration (in ticks) before attempting a soft recovery kick.
  static const int _softKickTicks = 3;

  /// Stall duration (in ticks) before giving up and self-restarting.
  /// Chosen well beyond any legitimate render pause so a healthy idle screen
  /// is never restarted — only a truly wedged pipeline reaches this.
  static const int _hardRestartTicks = 10;

  /// Exit code used for a watchdog-triggered restart (visible in the journal).
  static const int _restartExitCode = 42;

  void start() {
    if (_timer != null) return;
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
    _timer = Timer.periodic(_tick, _onTick);
    _log.info(
      'armed (poll=${_tick.inSeconds}s, softKick=${_softKickTicks}s, '
      'hardRestart=${_hardRestartTicks}s)',
    );
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    _frameSinceLastTick = true;
  }

  void _onTick(Timer _) {
    if (_frameSinceLastTick) {
      if (_stalledTicks > 0) {
        _log.info('render pipeline recovered after ${_stalledTicks}s');
      }
      _stalledTicks = 0;
      _frameSinceLastTick = false;
      return;
    }

    // No frame completed during the last interval.
    _stalledTicks++;

    final binding = WidgetsBinding.instance;
    final pending = binding.hasScheduledFrame;
    _log.warning(
      'no frame for ${_stalledTicks}s (hasScheduledFrame=$pending)',
    );

    if (_stalledTicks >= _hardRestartTicks) {
      _log.shout(
        'render pipeline wedged for ${_stalledTicks}s — exiting so systemd '
        'restarts the UI (recovery from a permanent freeze)',
      );
      // Give the journal a moment to flush the SHOUT line, then exit.
      // systemd's Restart=always brings flutter-pi straight back.
      exit(_restartExitCode);
    }

    if (_stalledTicks >= _softKickTicks) {
      _log.warning('soft recovery: forcing a frame + warm-up frame');
      try {
        binding.scheduleForcedFrame();
        binding.scheduleWarmUpFrame();
      } catch (e) {
        _log.warning('soft recovery threw: $e');
      }
    }
  }
}
