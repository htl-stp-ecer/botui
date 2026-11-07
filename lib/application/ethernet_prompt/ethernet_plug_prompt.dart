import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  static const _interval = Duration(seconds: 3);

  Timer? _timer;
  bool? _cablePlugged; // null until the first reading
  bool _wasEthernetMode = false;
  bool _asking = false;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_interval, (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_polling || _asking) return;
    _polling = true;
    try {
      final repository = ref.read(wifiRepositoryProvider);
      final plugged = await repository.isEthernetCableConnected();
      final inEthernetMode = await repository.isLanOnlyModeActive();
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
    } catch (e) {
      // Robot not reachable right now; try again on the next tick.
      log.fine('Ethernet cable check failed: $e');
    } finally {
      _polling = false;
    }
  }

  Future<void> _askSwitchToEthernet() async {
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    _asking = true;
    try {
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
      if (state.mode == NetworkMode.lanOnly) {
        AppToast.success('Switched to Ethernet Mode');
      } else {
        AppToast.error(state.errorMessage ?? 'Could not switch to Ethernet Mode');
      }
    } finally {
      _asking = false;
    }
  }

  /// The cable was pulled in Ethernet Mode: Wi-Fi is off, so the robot needs a
  /// new way to be reached. The user picks client or hotspot mode. (If nobody
  /// answers, the server turns Wi-Fi back on by itself after about 30 s.)
  Future<void> _askWhereToGo() async {
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    _asking = true;
    try {
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
              label: 'Client',
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
            ? 'Switched to Client Mode'
            : 'Switched to Hotspot Mode');
      } else {
        AppToast.error(state.errorMessage ?? 'Could not switch mode');
      }
    } finally {
      _asking = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
