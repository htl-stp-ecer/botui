import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/features/settings/domain/usecases/manage_saved_networks.dart';
import 'package:stpvelox/features/settings/usecases/get_device_info.dart';
import 'package:stpvelox/features/wifi/application/wifi_provider.dart';
import 'package:stpvelox/features/wifi/domain/application/wifi_client_state.dart';
import 'package:stpvelox/features/wifi/domain/enities/saved_network.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_credentials.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_encryption_type.dart';
import 'package:stpvelox/features/wifi/domain/usecases/forget_wifi.dart';
import 'package:stpvelox/features/wifi/usecases/connect_to_wifi.dart';
import 'package:stpvelox/features/wifi/usecases/get_available_networks.dart';

class WifiClientNotifier extends Notifier<WifiClientState> {
  late final GetAvailableNetworks _getAvailableNetworks;
  late final ConnectToWifi _connectToWifi;
  late final ForgetWifi _forgetWifi;
  late final GetDeviceInfo _getDeviceInfo;
  late final ManageSavedNetworks _manageSavedNetworks;

  @override
  WifiClientState build() {
    _getAvailableNetworks = ref.read(getAvailableNetworksProvider);
    _connectToWifi = ref.read(connectToWifiProvider);
    _forgetWifi = ref.read(forgetWifiProvider);
    _getDeviceInfo = ref.read(getDeviceInfoProvider);
    _manageSavedNetworks = ref.read(manageSavedNetworksProvider);
    return WifiClientState();
  }

  Future<void> loadNetworks() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final networks = await _getAvailableNetworks();
      state = state.copyWith(isLoading: false, networks: networks);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _plain(e));
    }
  }

  /// The text of an error without Dart's "Exception: " prefix.
  static String _plain(Object e) => e is TimeoutException
      ? 'Connection timed out'
      : e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');

  /// The error of the last failed operation (null if none since it was
  /// cleared). Readable from a widget that may be gone by the time it is asked.
  String? get lastError => state.errorMessage;

  /// Returns whether the connection succeeded (the state keeps the error
  /// message of a failure; it does not tell a fresh failure from an old one).
  Future<bool> connectToNetwork(String ssid, WifiEncryptionType encryptionType,
      WifiCredentials credentials) async {
    state = state.copyWith(isLoading: true, clearResult: true);
    try {
      // The robot gives up after ~25 s; never wait forever for it.
      await _connectToWifi(ssid, encryptionType, credentials)
          .timeout(const Duration(seconds: 45));

      final savedNetwork = SavedNetwork(
        ssid: ssid,
        encryptionType: encryptionType,
        credentials: credentials,
        lastConnected: DateTime.now(),
      );
      await _manageSavedNetworks.saveNetwork(savedNetwork);

      final networks = await _getAvailableNetworks();
      state = state.copyWith(
        isLoading: false,
        networks: networks,
        connectedSsid: ssid,
      );

      await loadDeviceInfo();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _plain(e));
      return false;
    }
  }

  Future<void> forgetNetwork(String ssid) async {
    state = state.copyWith(isLoading: true, clearResult: true);
    try {
      await _forgetWifi(ssid);

      final networks = await _getAvailableNetworks();
      state = state.copyWith(
        networks: networks,
        isLoading: false,
        forgottenSsid: ssid,
      );

      await loadDeviceInfo();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _plain(e));
    }
  }

  Future<void> loadDeviceInfo() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final deviceInfo = await _getDeviceInfo();
      state = state.copyWith(isLoading: false, deviceInfo: deviceInfo);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _plain(e));
    }
  }
}

final wifiClientProvider =
    NotifierProvider<WifiClientNotifier, WifiClientState>(
  WifiClientNotifier.new,
);
