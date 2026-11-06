import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

DateTime _lastPush = DateTime.fromMillisecondsSinceEpoch(0);

/// Resistive touchscreens often deliver one press as several taps. A plain
/// `context.push` then stacks the same screen multiple times.
const Duration _pushLockout = Duration(milliseconds: 300);

extension SafeNavigation on BuildContext {
  /// Like [GoRouter.push], but ignores the call if another push happened a
  /// moment ago or if the target is already the screen on top.
  /// Returns null when the push was ignored.
  Future<T?> pushOnce<T extends Object?>(String location, {Object? extra}) {
    final now = DateTime.now();
    if (now.difference(_lastPush) < _pushLockout) return Future.value(null);

    final router = GoRouter.of(this);
    final current = router.routerDelegate.currentConfiguration.uri.path;
    if (Uri.parse(location).path == current) return Future.value(null);

    _lastPush = now;
    return router.push<T>(location, extra: extra);
  }
}
