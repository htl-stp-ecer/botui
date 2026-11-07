import 'package:stpvelox/features/wifi/domain/enities/access_point_config.dart';
import 'package:stpvelox/features/wifi/domain/enities/network_mode.dart';
import 'package:stpvelox/features/wifi/domain/enities/saved_network.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_band.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_channel_scan.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_credentials.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_encryption_type.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_network.dart';
import 'package:stpvelox/shared/domain/entities/device_info.dart';

abstract class IWifiRepository {
  Future<List<WifiNetwork>> getAvailableNetworks();

  Future<void> connectToWifi(
    String ssid,
    WifiEncryptionType encryptionType,
    WifiCredentials credentials,
  );

  Future<void> forgetWifi(String ssid);

  Future<DeviceInfo> getDeviceInfo();

  Future<NetworkMode> getCurrentNetworkMode();
  Future<void> setNetworkMode(NetworkMode mode);
  Future<void> initializeNetworkMode();

  Future<void> startAccessPoint(AccessPointConfig config);
  Future<void> stopAccessPoint();
  Future<bool> isAccessPointActive();
  Future<int> getAccessPointClientCount();
  Future<AccessPointConfig?> getAccessPointConfig();
  Future<WifiBand> findBestWifiBand();
  Future<int> findBestChannel(WifiBand band);
  Future<WifiChannelScan> scanAccessPointChannels(WifiBand band);

  Future<List<SavedNetwork>> getSavedNetworks();
  Future<void> saveNetwork(SavedNetwork network);
  Future<void> removeSavedNetwork(String ssid);
  Future<SavedNetwork?> getSavedNetwork(String ssid);

  /// The stored password of a saved network (fetched on demand).
  Future<String?> getSavedPassword(String ssid);

  /// Returns "client" or "host" (see the API), null from an older server.
  Future<String?> enableLanOnlyMode();
  Future<void> disableLanOnlyMode();
  Future<bool> isLanOnlyModeActive();
  Future<bool> isEthernetCableConnected();

  /// Waits for a change of the ethernet cable or of Ethernet Mode (long poll).
  /// Pass the `version` of the previous answer, or -1 for the current state.
  Future<LanEvent> waitLanEvent(int since);
}

/// Ethernet cable and Ethernet Mode state with the version it was read at.
class LanEvent {
  final int version;
  final bool cableConnected;
  final bool ethernetModeActive;

  const LanEvent({
    required this.version,
    required this.cableConnected,
    required this.ethernetModeActive,
  });
}
