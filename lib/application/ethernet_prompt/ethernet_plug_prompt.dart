import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/application/overview/overview_info_provider.dart';
import 'package:stpvelox/application/screensaver/screensaver_settings_provider.dart';
import 'package:stpvelox/application/theme/color_theme_provider.dart';
import 'package:stpvelox/core/logging/has_logging.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/theme/app_theme.dart';
import 'package:stpvelox/core/widgets/app_toast.dart';
import 'package:stpvelox/core/widgets/raccoon_dialog.dart';
import 'package:stpvelox/features/wifi/application/network_mode_notifier.dart';
import 'package:stpvelox/features/wifi/application/wifi_provider.dart';
import 'package:stpvelox/features/wifi/domain/enities/network_mode.dart';

/// Asks about the ethernet cable as it is plugged in or pulled out:
///  * plugged in (not in Ethernet Mode): "Switch to Ethernet Mode?"
///  * pulled out while in Ethernet Mode: back to client or to hotspot mode?
///
/// Wraps the whole app. Only a change triggers a question: a cable that was
/// already in when the app started does not, and neither does one that stays
/// in after the user said no.
class EthernetPlugPrompt extends ConsumerStatefulWidget {
  const EthernetPlugPrompt({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<EthernetPlugPrompt> createState() => _EthernetPlugPromptState();
}

class _EthernetPlugPromptState extends ConsumerState<EthernetPlugPrompt>
    with HasLogger {
  bool _running = false;
  int _since = -1; // version of the last answer from the robot
  bool? _cablePlugged; // null until the first reading
  bool _wasEthernetMode = false;

  @override
  void initState() {
    super.initState();
    _running = true;
    _listen();
  }

  @override
  void dispose() {
    _running = false;
    super.dispose();
  }

  /// Waits for the robot to report a change (long poll: the answer comes the
  /// moment the cable or the mode changes), instead of asking every few
  /// seconds.
  Future<void> _listen() async {
    while (_running) {
      try {
        final event = await ref.read(wifiRepositoryProvider).waitLanEvent(_since);
        _since = event.version;
        await _handle(event.cableConnected, event.ethernetModeActive);
      } catch (e) {
        // Robot not reachable (or an older server); try again shortly.
        log.fine('Ethernet event wait failed: $e');
        await Future<void>.delayed(const Duration(seconds: 3));
      }
    }
  }

  Future<void> _handle(bool plugged, bool inEthernetMode) async {
    // The robot reported a change (cable, mode, hotspot): keep the network
    // screens in step even if the change did not come from them.
    unawaited(ref.read(networkModeProvider.notifier).syncNetworkMode());
    // The overview shows address, Wi-Fi/hotspot name and mode: refresh it on
    // the same event instead of polling.
    unawaited(ref.read(overviewInfoProvider.notifier).refresh());
    final justPlugged = _cablePlugged == false && plugged;
    final justUnplugged = _cablePlugged == true && !plugged;
    final wasEthernetMode = _wasEthernetMode;
    _cablePlugged = plugged;
    _wasEthernetMode = inEthernetMode;
    if (justPlugged && !inEthernetMode) {
      await _askSwitchToEthernet();
    } else if (justUnplugged && (inEthernetMode || wasEthernetMode)) {
      await _askWhereToGo();
    }
  }

  Future<void> _askSwitchToEthernet() async {
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    final yes = await showRaccoonConfirmDialog(
      context,
      title: 'Ethernet cable connected',
      message: 'Do you want to switch to Ethernet Mode?\n'
          'Wi-Fi and the hotspot will be turned off.',
      confirmLabel: 'Switch',
      cancelLabel: 'Not now',
      icon: Icons.cable_rounded,
      iconColor: Colors.lightBlueAccent,
      confirmColor: Colors.green[700]!,
    );
    if (!yes) return;
    final notifier = ref.read(networkModeProvider.notifier);
    await notifier.updateNetworkMode(NetworkMode.lanOnly);
    final state = ref.read(networkModeProvider);
    if (state.mode != NetworkMode.lanOnly) {
      AppToast.error(state.errorMessage ?? 'Could not switch to Ethernet Mode');
    }
  }

  /// The cable was pulled in Ethernet Mode: Wi-Fi is off, so the robot needs a
  /// new way to be reached. The user picks client or hotspot mode. (If nobody
  /// answers, the server turns Wi-Fi back on by itself after about 30 s.)
  Future<void> _askWhereToGo() async {
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    final theme = ref.read(colorThemeProvider);
    final choice = await showRaccoonDialog<NetworkMode>(
      context,
      dismissible: false,
      builder: (ctx) => RaccoonDialog(
        icon: Icons.cable_rounded,
        iconColor: Colors.orangeAccent,
        title: 'Ethernet cable unplugged',
        message: 'Which mode do you want to switch to?',
        actions: [
          RaccoonDialogAction(
            label: 'WiFi',
            color: theme.tileColor(TileColor.teal, 0),
            onPressed: () => Navigator.of(ctx).pop(NetworkMode.client),
          ),
          RaccoonDialogAction(
            label: 'Hotspot',
            color: theme.tileColor(TileColor.purple, 1),
            onPressed: () => Navigator.of(ctx).pop(NetworkMode.accessPoint),
          ),
        ],
      ),
    );
    if (choice == null) return;
    await ref.read(networkModeProvider.notifier).updateNetworkMode(choice);
    final state = ref.read(networkModeProvider);
    if (state.mode == choice) {
      AppToast.success(choice == NetworkMode.client
          ? 'Switched to WiFi Mode'
          : 'Switched to Hotspot Mode');
    } else {
      AppToast.error(state.errorMessage ?? 'Could not switch mode');
    }
  }

  /// Anything that arrived while the screensaver covered the screen is shown
  /// as soon as it is gone; a moment later, so the UI has drawn first.
  void _refreshAfterScreensaver() {
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      unawaited(ref.read(networkModeProvider.notifier).syncNetworkMode());
      unawaited(ref.read(overviewInfoProvider.notifier).refresh());
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(screensaverShowingProvider, (previous, showing) {
      if (previous == true && !showing) _refreshAfterScreensaver();
    });
    return widget.child;
  }
}
