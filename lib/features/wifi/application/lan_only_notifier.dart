import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/core/logging/has_logging.dart';
import 'package:stpvelox/features/wifi/application/wifi_provider.dart';
import 'package:stpvelox/features/wifi/domain/application/lan_only_state.dart';
import 'package:stpvelox/features/wifi/domain/repositories/i_wifi_repository.dart';

class LanOnlyNotifier extends Notifier<LanOnlyState> with HasLogger {
  late final IWifiRepository _repository;
  Timer? _cableMonitorTimer;
  bool _isMonitoring = false;

  @override
  LanOnlyState build() {
    _repository = ref.read(wifiRepositoryProvider);
    // Clean up timer when the notifier is disposed
    ref.onDispose(() {
      _stopCableMonitoring();
    });
    return LanOnlyState();
  }

  /// Start monitoring the cable connection status
  void _startCableMonitoring() {
    if (_isMonitoring) return;

    _isMonitoring = true;
    log.info('Starting LAN cable monitoring');

    // Check cable status every 3 seconds
    _cableMonitorTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) async {
      await _checkCableStatus();
    });
  }

  /// Stop monitoring the cable connection status
  void _stopCableMonitoring() {
    if (!_isMonitoring) return;

    _isMonitoring = false;
    _cableMonitorTimer?.cancel();
    _cableMonitorTimer = null;
    log.info('Stopped LAN cable monitoring');
  }

  /// Check if cable is still connected, trigger callback if disconnected
  Future<void> _checkCableStatus() async {
    if (!state.isActive) {
      _stopCableMonitoring();
      return;
    }

    try {
      final isCableConnected = await _repository.isEthernetCableConnected();

      if (!isCableConnected && state.isCableConnected) {
        // Cable was just disconnected
        log.warning(
            'LAN cable disconnected, triggering automatic switch to client mode');
        state = state.copyWith(isCableConnected: false);

        // Notify that cable was disconnected - the network mode notifier will handle the switch
        _onCableDisconnected();
      } else if (isCableConnected != state.isCableConnected) {
        // Update cable status
        state = state.copyWith(isCableConnected: isCableConnected);
      }
    } catch (e) {
      log.severe('Error checking cable status: $e');
    }
  }

  /// Called when cable is disconnected - triggers network mode switch
  void _onCableDisconnected() {
    // We need to switch to client mode, but we can't directly access networkModeNotifier
    // from here due to circular dependency. Instead, we'll set a flag in the state
    // that the network mode notifier will check.
    state = state.copyWith(
      errorMessage: 'LAN_CABLE_DISCONNECTED',
    );
  }

  Future<void> checkStatus() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final isActive = await _repository.isLanOnlyModeActive();
      final isCableConnected = await _repository.isEthernetCableConnected();

      if (isActive) {
        final deviceInfo = await _repository.getDeviceInfo();
        state = state.copyWith(
          isActive: isActive,
          isCableConnected:
              deviceInfo.ethernetCableConnected || isCableConnected,
          ipAddress: deviceInfo.ethernetIpAddress ?? deviceInfo.ipAddress,
          macAddress: deviceInfo.ethernetMacAddress ?? deviceInfo.macAddress,
          isLoading: false,
          errorMessage: null,
        );
      } else {
        state = state.copyWith(
          isActive: false,
          isCableConnected: isCableConnected,
          isLoading: false,
          errorMessage: null,
        );
      }
    } catch (e) {
      log.severe('Failed to check LAN only status: $e');
      state = state.copyWith(
        errorMessage: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> enable() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // Check if cable is connected first
      final isCableConnected = await _repository.isEthernetCableConnected();

      if (!isCableConnected) {
        state = state.copyWith(
          errorMessage:
              'No ethernet cable detected. Please connect a LAN cable before enabling LAN only mode.',
          isLoading: false,
          isCableConnected: false,
        );
        log.warning(
            'Attempted to enable LAN only mode without cable connected');
        return;
      }

      await _repository.enableLanOnlyMode();
      await checkStatus();
      // Clear error message on success
      state = state.copyWith(errorMessage: null);
      log.info('LAN only mode enabled');

      // Start monitoring cable connection
      _startCableMonitoring();
    } catch (e) {
      log.severe('Failed to enable LAN only mode: $e');
      state = state.copyWith(
        errorMessage: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> disable() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // Stop monitoring cable connection
      _stopCableMonitoring();

      await _repository.disableLanOnlyMode();
      state = state.copyWith(
        isActive: false,
        isLoading: false,
        ipAddress: null,
        macAddress: null,
        errorMessage: null,
      );
      log.info('LAN only mode disabled');
    } catch (e) {
      log.severe('Failed to disable LAN only mode: $e');
      state = state.copyWith(
        errorMessage: e.toString(),
        isLoading: false,
      );
    }
  }
}
