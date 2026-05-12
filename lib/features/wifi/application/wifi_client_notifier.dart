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
    state = state.copyWith(isLoading: true);
    try {
      final networks = await _getAvailableNetworks();
      state = state.copyWith(isLoading: false, networks: networks);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> connectToNetwork(String ssid, WifiEncryptionType encryptionType,
      WifiCredentials credentials) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _connectToWifi(ssid, encryptionType, credentials);

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
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> forgetNetwork(String ssid) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
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
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> loadDeviceInfo() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final deviceInfo = await _getDeviceInfo();
      state = state.copyWith(
        isLoading: false,
        deviceInfo: deviceInfo,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}

final wifiClientProvider =
    NotifierProvider<WifiClientNotifier, WifiClientState>(
  WifiClientNotifier.new,
);
