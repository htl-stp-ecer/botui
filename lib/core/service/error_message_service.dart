import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raccoon_transport/raccoon_transport.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stpvelox/core/lcm/domain/providers.dart';
import 'package:stpvelox/core/lcm/models/lcm_decoded.dart';
import 'package:stpvelox/core/logging/has_logging.dart';
import 'package:stpvelox/core/router/app_router.dart' show rootNavigatorKey;

part 'error_message_service.g.dart';

@riverpod
class ErrorMessageService extends _$ErrorMessageService with HasLogger {
  StreamSubscription<LcmDecoded<StringT>>? _subscription;
  bool _dialogVisible = false;
  BuildContext? _context;

  @override
  String? build() {
    ref.onDispose(_dispose);
    _startSubscription();
    return null;
  }

  void start(BuildContext context) {
    _context = context;
  }

  void stop() {
    _context = null;
    _dismissIfVisible();
  }

  void _startSubscription() {
    final lcm = ref.read(lcmServiceProvider);
    _subscription = lcm
        .subscribeAs<StringT>(
          Channels.errorMessages,
          StringT.decode,
          options: const SubscribeOptions(requestRetained: true),
        )
        .listen(
      (decoded) {
        final message = decoded.value.value;
        log.warning('Error received via LCM: $message');
        state = message;

        // Prefer the long-lived rootNavigatorKey (lives for the lifetime
        // of GoRouter) over the BuildContext that start() was called
        // with (that one becomes stale as soon as its widget rebuilds).
        // Fall back to _context only if the navigator key isn't attached
        // yet (very early app startup).
        final ctx = rootNavigatorKey.currentContext ?? _context;
        if (ctx != null) {
          try {
            _showErrorDialog(ctx, message);
          } catch (e, st) {
            log.severe('Failed to show error dialog (suppressed to keep '
                'subscription alive): $e\n$st');
            _dialogVisible = false;
          }
        }
      },
      onError: (error) {
        log.severe('Error in error message subscription: $error');
      },
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    // _context can become stale between the LCM frame arriving and this
    // callback firing — the widget that registered it may have been
    // unmounted (Navigator state torn down). When that happens
    // `Navigator.of(context)` throws "Null check operator used on a
    // null value" and kills the whole subscription. Guard with mounted
    // and try/catch so a flaky context never takes down error reporting
    // for the rest of the session.
    if (context is Element && !context.mounted) {
      _dialogVisible = false;
      return;
    }
    // Strict at-most-one dialog: if one is already up, drop the new
    // error rather than stacking modals on top of each other. The
    // previous "pop the old then show the new" path produced an
    // overlap window because Navigator.pop is async and showDialog
    // fired immediately after — users saw two stacked alerts and the
    // bottom one could never be reached after the top was dismissed.
    // The dropped message is still logged + reflected in `state` so
    // any in-app banner / log viewer sees the latest text. If multiple
    // errors fire while one is open, the user dismisses once and the
    // NEXT incoming error opens the next dialog.
    if (_dialogVisible) {
      log.warning('Suppressing duplicate error dialog (one already open): '
          '$message');
      return;
    }

    _dialogVisible = true;

    // Custom Dialog matching the app's dark theme (see e.g.
    // sensor_category_screen.dart's _ShutdownWarningDialog) instead of
    // the default Material AlertDialog which renders with the platform
    // light defaults and looks out of place on the Wombat screen.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (ctx) {
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.grey[900],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Error',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Acknowledge',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).whenComplete(() {
      _dialogVisible = false;
    });
  }

  void _dismissIfVisible() {
    if (_dialogVisible && _context != null) {
      if (Navigator.of(_context!).canPop()) {
        Navigator.of(_context!).pop();
      }
      _dialogVisible = false;
    }
  }

  void _dispose() {
    _subscription?.cancel();
    _subscription = null;
    _context = null;
  }
}
