import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/application/inactivity/inactivity_notifier.dart';
import 'package:stpvelox/application/screensaver/screensaver_settings_provider.dart';

/// No screensaver while this widget is in the tree; one that is up is closed.
///
/// For content that has to stay visible without anyone touching the display
/// (the camera picture, the hardware shutdown popup). Wrap that content in it;
/// the screensaver timer runs again once it is gone.
class KeepScreensaverOff extends ConsumerStatefulWidget {
  const KeepScreensaverOff({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<KeepScreensaverOff> createState() => _KeepScreensaverOffState();
}

class _KeepScreensaverOffState extends ConsumerState<KeepScreensaverOff> {
  // Kept here: `ref` must not be used in dispose.
  late final ScreensaverBlockNotifier _block;
  bool _blocking = false;

  @override
  void initState() {
    super.initState();
    _block = ref.read(screensaverBlockProvider.notifier);
    // A provider must not change while the tree is being built.
    Future.microtask(() {
      if (!mounted) return;
      _blocking = true;
      _block.block();
      ref.read(inactivityProvider.notifier).userActivityDetected();
    });
  }

  @override
  void dispose() {
    // Deferred for the same reason as in initState.
    if (_blocking) Future.microtask(_block.unblock);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
