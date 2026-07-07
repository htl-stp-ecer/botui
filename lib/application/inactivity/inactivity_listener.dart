import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/application/inactivity/inactivity_notifier.dart';
import 'package:stpvelox/application/screensaver/screensaver_settings_provider.dart';
import 'package:stpvelox/core/logging/has_logging.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/main.dart' show dynamicUiActiveProvider;

class InactivityListener extends ConsumerStatefulWidget {
  const InactivityListener({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<InactivityListener> createState() => _InactivityListenerState();
}

class _InactivityListenerState extends ConsumerState<InactivityListener> with HasLogger {
  Timer? _retryTimer;

  void _handleUserActivity(String source) {
    log.finer('User activity detected from: $source');
    ref.read(inactivityProvider.notifier).userActivityDetected();
  }

  void _showScreensaver() {
    final isShowing = ref.read(screensaverShowingProvider);
    if (isShowing) return;

    final screensaverEnabled = ref.read(screensaverEnabledProvider);
    if (!screensaverEnabled) {
      log.fine('Screensaver disabled in settings');
      return;
    }

    // If a custom (dynamic) UI screen is active, don't show — reschedule 1s later
    final dynamicUiActive = ref.read(dynamicUiActiveProvider);
    if (dynamicUiActive) {
      log.fine('Screensaver deferred — dynamic UI is active, retrying in 1s');
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(seconds: 1), () {
        if (mounted && ref.read(inactivityProvider)) {
          _showScreensaver();
        }
      });
      return;
    }

    log.info('Showing screensaver');
    ref.read(screensaverShowingProvider.notifier).set(true);

    final router = ref.read(appRouterProvider);
    // Guard against stacking a second robotFace route on top of an existing
    // one. If a prior race left the flag out of sync with the navigator (flag
    // false while the route was still up), pushing again would stack two
    // robotFace routes — one pop would only remove the top, freezing the
    // screensaver. Never push if it is already the current route.
    final currentLocation = router.state.uri.path;
    if (currentLocation == AppRoutes.robotFace) {
      log.fine('Screensaver route already on top — not pushing again');
      return;
    }
    router.push(AppRoutes.robotFace);
  }

  void _hideScreensaver() {
    _retryTimer?.cancel();
    final isShowing = ref.read(screensaverShowingProvider);
    if (!isShowing) return;

    log.info('Hiding screensaver');
    ref.read(screensaverShowingProvider.notifier).set(false);

    final router = ref.read(appRouterProvider);
    if (router.canPop()) {
      router.pop();
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(inactivityProvider, (previous, isInactive) {
      if (isInactive) {
        _showScreensaver();
      } else {
        _hideScreensaver();
      }
    });

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => _handleUserActivity('GestureDetector.onTap'),
      onScaleStart: (_) => _handleUserActivity('GestureDetector.onScaleStart'),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _handleUserActivity('Listener.onPointerDown'),
        onPointerMove: (_) => _handleUserActivity('Listener.onPointerMove'),
        onPointerUp: (_) => _handleUserActivity('Listener.onPointerUp'),
        onPointerSignal: (_) => _handleUserActivity('Listener.onPointerSignal'),
        child: widget.child,
      ),
    );
  }
}
