import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/core/logging/has_logging.dart';
import 'package:stpvelox/features/settings/domain/usecases/set_network_mode.dart';
import 'package:stpvelox/features/wifi/application/wifi_provider.dart';
import 'package:stpvelox/features/wifi/domain/application/network_mode_state.dart';
import 'package:stpvelox/features/wifi/domain/enities/network_mode.dart';
import 'package:stpvelox/features/wifi/usecases/get_network_mode.dart';

class NetworkModeNotifier extends Notifier<NetworkModeState> with HasLogger {
  late final GetNetworkMode _getNetworkMode;
  late final SetNetworkMode _setNetworkMode;

  @override
  NetworkModeState build() {
    _getNetworkMode = ref.read(getNetworkModeProvider);
    _setNetworkMode = ref.read(setNetworkModeProvider);

    return NetworkModeState();
  }

  /// Re-reads the mode without the loading state (so the screen does not
  /// flash and no "Switched to" toast shows). For changes that happened
  /// elsewhere: a dialog, the server, the screensaver being up.
  Future<void> syncNetworkMode() async {
    if (state.isLoading) return; // a switch the user started is running
    try {
      final mode = await _getNetworkMode();
      if (mode != state.mode && !state.isLoading) {
        state = state.copyWith(mode: mode);
      }
    } catch (_) {
      // Keep what is shown; the next event or visit tries again.
    }
  }

  Future<void> loadNetworkMode() async {
    state = state.copyWith(isLoading: true, errorMessage: () => null);
    try {
      final mode = await _getNetworkMode();
      state = state.copyWith(mode: mode, isLoading: false, errorMessage: () => null);
    } catch (e) {
      state = state.copyWith(errorMessage: () => e.toString(), isLoading: false);
    }
  }

  Future<void> updateNetworkMode(NetworkMode mode) async {
    final previousMode = state.mode;
    state = state.copyWith(isLoading: true, errorMessage: () => null);
    try {
      // Handle mode-specific logic
      if (mode == NetworkMode.lanOnly) {
        // Enable LAN only mode through the LAN provider
        await ref.read(lanOnlyProvider.notifier).enable();

        // Check if enabling failed (e.g., no cable connected)
        final lanState = ref.read(lanOnlyProvider);
        if (lanState.errorMessage != null) {
          // Revert to previous mode if LAN mode failed
          state = state.copyWith(
            mode: previousMode,
            isLoading: false,
            errorMessage: () => lanState.errorMessage,
          );
          log.warning("Failed to enable LAN mode: ${lanState.errorMessage}");
          return;
        }
      } else if (state.mode == NetworkMode.lanOnly) {
        // Leaving Ethernet Mode: the mode call below does the whole switch on
        // the robot. Disabling Ethernet Mode separately would first send the
        // robot through WiFi mode (connecting to a saved network) on the way
        // to the hotspot.
        ref.read(lanOnlyProvider.notifier).reset();
      }

      // Ethernet Mode was already set by the enable call above; asking again
      // would only run the same steps a second time.
      if (mode != NetworkMode.lanOnly) {
        await _setNetworkMode(mode);
      }

      state = state.copyWith(mode: mode, isLoading: false, errorMessage: () => null);
      log.info("Network mode updated to ${state.mode}");
      // The hotspot may have been stopped (or started) by the switch; do not
      // keep showing the old state.
      unawaited(ref.read(accessPointProvider.notifier).refreshStatus());
    } catch (e) {
      state = state.copyWith(
        mode: previousMode,
        errorMessage: () => e.toString(),
        isLoading: false,
      );
      log.severe("Failed to update network mode: $e");
    }
  }
}

final networkModeProvider =
    NotifierProvider<NetworkModeNotifier, NetworkModeState>(
  NetworkModeNotifier.new,
);
