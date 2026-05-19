import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raccoon_transport/raccoon_transport.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stpvelox/core/lcm/domain/providers.dart';
import 'package:stpvelox/core/lcm/models/lcm_decoded.dart';
import 'package:stpvelox/core/logging/has_logging.dart';

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

        if (_context != null) {
          _showErrorDialog(_context!, message);
        }
      },
      onError: (error) {
        log.severe('Error in error message subscription: $error');
      },
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    if (_dialogVisible) {
      // Dismiss the current dialog so we can show the new error
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }

    _dialogVisible = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            icon: const Icon(Icons.error_outline, color: Colors.redAccent, size: 36),
            title: const Text('Error'),
            content: Text(message),
            actions: <Widget>[
              TextButton(
                child: const Text('Acknowledge'),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
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
