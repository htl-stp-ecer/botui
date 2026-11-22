import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raccoon_transport/raccoon_transport.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stpvelox/core/transport/domain/providers.dart';
import 'package:stpvelox/core/transport/models/transport_decoded.dart';
import 'package:stpvelox/core/logging/has_logging.dart';
import 'package:stpvelox/core/router/app_router.dart' show rootNavigatorKey;
import 'package:stpvelox/core/service/notice_queue.dart';
import 'package:stpvelox/core/widgets/raccoon_dialog.dart';

part 'error_message_service.g.dart';

/// Shows the messages that components send on `messages/error` and
/// `messages/warn` (a [MessageT]: a title and a text) as a dialog that has to
/// be acknowledged. One dialog is on screen at a time; the others wait.
@riverpod
class ErrorMessageService extends _$ErrorMessageService with HasLogger {
  final List<StreamSubscription<TransportDecoded<MessageT>>> _subscriptions = [];
  final NoticeQueue _queue = NoticeQueue();
  BuildContext? _context;

  /// The text of the dialog that is on screen; a message with the same kind and title changes it.
  ValueNotifier<NoticeText>? _visible;

  @override
  String? build() {
    ref.onDispose(_dispose);
    _startSubscriptions();
    return null;
  }

  void start(BuildContext context) {
    _context = context;
  }

  void stop() {
    _context = null;
    _dismissIfVisible();
    _queue.clear();
    _visible = null;
  }

  void _startSubscriptions() {
    final transport = ref.read(transportServiceProvider);
    for (final (channel, kind) in [
      (channels.messages.error, NoticeKind.error),
      (channels.messages.warn, NoticeKind.warning),
    ]) {
      _subscriptions.add(
        transport.subscribeAs<MessageT>(channel, MessageT.decode).listen(
          (decoded) => _onMessage(kind, decoded.value),
          onError: (error) {
            log.severe('Error in $channel subscription: $error');
          },
        ),
      );
    }
  }

  void _onMessage(NoticeKind kind, MessageT message) {
    log.warning('${kind.name} received via transport: '
        '${message.title}: ${message.content}');
    state = '${message.title}: ${message.content}';

    final notice = Notice(kind, message.title, message.content);
    switch (_queue.add(notice)) {
      case NoticeResult.shownNow:
        _present(notice);
      case NoticeResult.updatedShowing:
        _visible?.value = (title: notice.title, message: notice.content);
      case NoticeResult.updatedWaiting:
      case NoticeResult.queued:
        break;
    }
  }

  void _present(Notice notice) {
    // Prefer the long-lived rootNavigatorKey (lives for the lifetime of
    // GoRouter) over the BuildContext that start() was called with (that one
    // becomes stale as soon as its widget rebuilds). Fall back to _context
    // only if the navigator key isn't attached yet (very early app startup).
    final context = rootNavigatorKey.currentContext ?? _context;
    // A stale context would make Navigator.of throw and end the subscription.
    if (context == null || (context is Element && !context.mounted)) {
      _finished();
      return;
    }
    final text = ValueNotifier<NoticeText>(
        (title: notice.title, message: notice.content));
    _visible = text;
    try {
      showRaccoonNoticeDialog(
        context,
        warning: notice.kind == NoticeKind.warning,
        text: text,
      ).whenComplete(() => _dialogClosed(text));
    } catch (e, st) {
      log.severe('Failed to show the message dialog (suppressed to keep the '
          'subscription alive): $e\n$st');
      _dialogClosed(text);
    }
  }

  void _dialogClosed(ValueNotifier<NoticeText> text) {
    // The notifier is not disposed: the dialog may still be fading out and listen to it.
    if (identical(_visible, text)) _visible = null;
    _finished();
  }

  void _finished() {
    final next = _queue.next();
    if (next != null) _present(next);
  }

  void _dismissIfVisible() {
    final context = _context;
    if (_queue.showing != null && context != null) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  void _dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _context = null;
  }
}
