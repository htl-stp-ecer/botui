import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/application/screensaver/screensaver_settings_provider.dart';

class InactivityNotifier extends Notifier<bool> {
  Timer? _timer;
  static const _timeout = Duration(seconds: 30);

  @override
  bool build() {
    ref.onDispose(() => _timer?.cancel());
    // A screen that keeps the screensaver off stops the timer; leaving it starts it again.
    ref.listen<int>(screensaverBlockProvider, (_, blockers) {
      if (blockers > 0) {
        _timer?.cancel();
      } else {
        userActivityDetected();
      }
    });
    if (ref.read(screensaverBlockProvider) == 0) _startTimer();
    return false;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(_timeout, () {
      state = true; // user inactive
    });
  }

  // Call on any user interaction
  void userActivityDetected() {
    state = false;
    if (ref.read(screensaverBlockProvider) == 0) _startTimer();
  }
}

final inactivityProvider = NotifierProvider<InactivityNotifier, bool>(
  InactivityNotifier.new,
);
