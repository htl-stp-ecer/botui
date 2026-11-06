import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stpvelox/core/router/app_router.dart';

enum ToastKind { info, success, error }

/// The one bottom popup ("badge") used across the app: it fades in, stays for
/// a moment and fades out. Use this instead of `ScaffoldMessenger.showSnackBar`
/// so all popups look and animate the same.
///
/// Needs no BuildContext (it shows on the root overlay), so it is safe to call
/// after an `await`. Only one is visible at a time; a new one replaces the old.
class AppToast {
  AppToast._();

  static const Duration fadeDuration = Duration(milliseconds: 250);
  static const Duration defaultDuration = Duration(seconds: 3);

  static OverlayEntry? _entry;
  static GlobalKey<_ToastViewState>? _viewKey;
  static Timer? _timer;

  static void info(String message, {Duration? duration}) =>
      show(message, kind: ToastKind.info, duration: duration);

  static void success(String message, {Duration? duration}) =>
      show(message, kind: ToastKind.success, duration: duration);

  static void error(String message, {Duration? duration}) =>
      show(message, kind: ToastKind.error, duration: duration);

  static void show(
    String message, {
    ToastKind kind = ToastKind.info,
    Duration? duration,
  }) {
    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay == null) return;

    _removeNow();

    final key = GlobalKey<_ToastViewState>();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastView(
        key: key,
        message: message,
        kind: kind,
        onFadedOut: () {
          if (identical(_entry, entry)) _removeNow();
        },
      ),
    );
    _entry = entry;
    _viewKey = key;
    overlay.insert(entry);

    _timer = Timer(duration ?? defaultDuration, () {
      _viewKey?.currentState?.fadeOut();
    });
  }

  /// Fades out whatever is showing.
  static void dismiss() => _viewKey?.currentState?.fadeOut();

  static void _removeNow() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
    _viewKey = null;
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({
    super.key,
    required this.message,
    required this.kind,
    required this.onFadedOut,
  });

  final String message;
  final ToastKind kind;
  final VoidCallback onFadedOut;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> {
  bool _visible = false;
  bool _fadingOut = false;

  @override
  void initState() {
    super.initState();
    // Start transparent, then fade in on the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  void fadeOut() {
    if (!mounted || _fadingOut) return;
    _fadingOut = true;
    setState(() => _visible = false);
  }

  Color get _color {
    switch (widget.kind) {
      case ToastKind.success:
        return const Color(0xFF2E7D32);
      case ToastKind.error:
        return const Color(0xFFC62828);
      case ToastKind.info:
        return const Color(0xFF303030);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 48,
      right: 48,
      bottom: 16,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: AppToast.fadeDuration,
          curve: Curves.easeInOut,
          onEnd: () {
            if (_fadingOut) widget.onFadedOut();
          },
          child: Center(
            child: Material(
              color: _color,
              elevation: 6,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
