import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/core/logging/has_logging.dart';
import 'package:stpvelox/core/widgets/app_toast.dart';
import 'package:stpvelox/features/wifi/application/wifi_provider.dart';
import 'package:stpvelox/features/wifi/domain/application/ethernet_mode_message.dart';
import 'package:stpvelox/features/wifi/domain/application/lan_only_state.dart';
import 'package:stpvelox/features/wifi/domain/repositories/i_wifi_repository.dart';

class LanOnlyNotifier extends Notifier<LanOnlyState> with HasLogger {
  late final IWifiRepository _repository;

  @override
  LanOnlyState build() {
    _repository = ref.read(wifiRepositoryProvider);
    return LanOnlyState();
  }

  /// Forgets that Ethernet Mode was on, without calling the robot (the caller
  /// switches the mode there in one step).
  void reset() {
    state = state.copyWith(
      isActive: false,
      ipAddress: null,
      macAddress: null,
      role: null,
      errorMessage: null,
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
              'No ethernet cable detected. Please connect an ethernet cable before enabling Ethernet Mode.',
          isLoading: false,
          isCableConnected: false,
        );
        log.warning(
            'Attempted to enable LAN only mode without cable connected');
        return;
      }

      final role = await _repository.enableLanOnlyMode();
      // The badge as soon as the robot says how it connected (client or
      // host); the rest below only refreshes what is shown.
      AppToast.success(ethernetModeMessage(role),
          duration: const Duration(seconds: 4));
      await checkStatus();
      // Clear error message on success
      state = state.copyWith(errorMessage: null, role: role);
      log.info('LAN only mode enabled');

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
