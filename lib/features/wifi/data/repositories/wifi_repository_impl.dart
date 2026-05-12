import 'package:stpvelox/features/wifi/data/datasource/raccoon_network_api.dart';
import 'package:stpvelox/features/wifi/domain/enities/access_point_config.dart';
import 'package:stpvelox/features/wifi/domain/enities/network_mode.dart';
import 'package:stpvelox/features/wifi/domain/enities/saved_network.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_band.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_channel_scan.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_credentials.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_encryption_type.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_network.dart';
import 'package:stpvelox/features/wifi/domain/repositories/i_wifi_repository.dart';
import 'package:stpvelox/shared/domain/entities/device_info.dart';

class WifiRepositoryImpl implements IWifiRepository {
  WifiRepositoryImpl({required this.api});

  final RaccoonNetworkApi api;

  @override
  Future<List<WifiNetwork>> getAvailableNetworks() async {
    final response = await api.getNetworks();
    return response
        .map((item) => _wifiNetworkFromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> connectToWifi(
    String ssid,
    WifiEncryptionType encryptionType,
    WifiCredentials credentials,
  ) async {
    await api.connect({
      'ssid': ssid,
      'encryptionType': _wifiEncryptionTypeToApi(encryptionType),
      'credentials': _credentialsToJson(credentials),
    });
  }

  @override
  Future<void> forgetWifi(String ssid) async {
    await api.forget(ssid);
  }

  @override
  Future<DeviceInfo> getDeviceInfo() async {
    final json = await api.getDeviceInfo();
    return _deviceInfoFromJson(json);
  }

  @override
  Future<NetworkMode> getCurrentNetworkMode() async {
    return _networkModeFromApi(await api.getNetworkMode());
  }

  @override
  Future<void> setNetworkMode(NetworkMode mode) async {
    await api.setNetworkMode(_networkModeToApi(mode));
  }

  @override
  Future<void> initializeNetworkMode() async {}

  @override
  Future<void> startAccessPoint(AccessPointConfig config) async {
    await api.startAccessPoint(_accessPointConfigToJson(config));
  }

  @override
  Future<void> stopAccessPoint() async {
    await api.stopAccessPoint();
  }

  @override
  Future<bool> isAccessPointActive() async {
    final status = await api.getAccessPointStatus();
    return status['isStarted'] as bool? ?? false;
  }

  @override
  Future<AccessPointConfig?> getAccessPointConfig() async {
    final json = await api.getAccessPointConfig();
    if (json == null || json.isEmpty) {
      return null;
    }
    return _accessPointConfigFromJson(json);
  }

  @override
  Future<WifiBand> findBestWifiBand() async {
    return _wifiBandFromApi(await api.findBestWifiBand());
  }

  @override
  Future<int> findBestChannel(WifiBand band) async {
    return await api.findBestChannel(_wifiBandToApi(band));
  }

  @override
  Future<WifiChannelScan> scanAccessPointChannels(WifiBand band) async {
    final json = await api.scanAccessPointChannels(_wifiBandToApi(band));
    return _wifiChannelScanFromJson(json);
  }

  @override
  Future<List<SavedNetwork>> getSavedNetworks() async {
    final response = await api.getSavedNetworks();
    return response
        .map((item) => _savedNetworkFromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveNetwork(SavedNetwork network) async {
    await api.saveNetwork(_savedNetworkToJson(network));
  }

  @override
  Future<void> removeSavedNetwork(String ssid) async {
    await api.removeSavedNetwork(ssid);
  }

  @override
  Future<SavedNetwork?> getSavedNetwork(String ssid) async {
    final json = await api.getSavedNetwork(ssid);
    if (json == null || json.isEmpty) {
      return null;
    }
    return _savedNetworkFromJson(json);
  }

  @override
  Future<void> enableLanOnlyMode() async {
    await api.enableLanOnlyMode();
  }

  @override
  Future<void> disableLanOnlyMode() async {
    await api.disableLanOnlyMode();
  }

  @override
  Future<bool> isLanOnlyModeActive() async {
    final mode = await api.getNetworkMode();
    return mode == 'lan_only';
  }

  @override
  Future<bool> isEthernetCableConnected() async {
    final status = await api.getLanStatus();
    return status['isCableConnected'] as bool? ?? false;
  }

  WifiNetwork _wifiNetworkFromJson(Map<String, dynamic> json) {
    return WifiNetwork(
      ssid: json['ssid'] as String,
      encryptionType:
          _wifiEncryptionTypeFromApi(json['encryptionType'] as String),
      isKnown: json['isKnown'] as bool? ?? false,
      isConnected: json['isConnected'] as bool? ?? false,
    );
  }

  DeviceInfo _deviceInfoFromJson(Map<String, dynamic> json) {
    final connectedNetworkJson =
        json['connectedNetwork'] as Map<String, dynamic>?;
    return DeviceInfo(
      ipAddress: json['ipAddress'] as String? ?? '127.0.0.1',
      macAddress: json['macAddress'] as String?,
      ethernetCableConnected: json['ethernetCableConnected'] as bool? ?? false,
      ethernetIpAddress: json['ethernetIpAddress'] as String?,
      ethernetMacAddress: json['ethernetMacAddress'] as String?,
      wifiIpAddress: json['wifiIpAddress'] as String?,
      wifiMacAddress: json['wifiMacAddress'] as String?,
      connectedNetwork: connectedNetworkJson == null
          ? null
          : _wifiNetworkFromJson(connectedNetworkJson),
    );
  }

  SavedNetwork _savedNetworkFromJson(Map<String, dynamic> json) {
    final credentialsJson = json['credentials'] as Map<String, dynamic>;
    return SavedNetwork(
      ssid: json['ssid'] as String,
      encryptionType:
          _wifiEncryptionTypeFromApi(json['encryptionType'] as String),
      credentials: _credentialsFromJson(credentialsJson),
      lastConnected: DateTime.parse(json['lastConnected'] as String),
      autoConnect: json['autoConnect'] as bool? ?? true,
    );
  }

  Map<String, dynamic> _savedNetworkToJson(SavedNetwork network) {
    return {
      'ssid': network.ssid,
      'encryptionType': _wifiEncryptionTypeToApi(network.encryptionType),
      'credentials': _credentialsToJson(network.credentials),
      'lastConnected': network.lastConnected.toIso8601String(),
      'autoConnect': network.autoConnect,
    };
  }

  WifiCredentials _credentialsFromJson(Map<String, dynamic> json) {
    if ((json['credentialsType'] as String?) == 'enterprise') {
      return EnterpriseCredentials(
        username: json['username'] as String? ?? '',
        password: json['password'] as String? ?? '',
        caCertificatePath: json['caCertificatePath'] as String?,
      );
    }
    return PersonalCredentials(json['password'] as String? ?? '');
  }

  Map<String, dynamic> _credentialsToJson(WifiCredentials credentials) {
    if (credentials is EnterpriseCredentials) {
      return {
        'credentialsType': 'enterprise',
        'username': credentials.username,
        'password': credentials.password,
        'caCertificatePath': credentials.caCertificatePath,
      };
    }
    final personal = credentials as PersonalCredentials;
    return {
      'credentialsType': 'personal',
      'password': personal.password,
    };
  }

  AccessPointConfig _accessPointConfigFromJson(Map<String, dynamic> json) {
    return AccessPointConfig(
      ssid: json['ssid'] as String,
      password: json['password'] as String? ?? '',
      band: _wifiBandFromApi(json['band'] as String? ?? 'bandAuto'),
      channel: json['channel'] as int? ?? 0,
      encryptionType: _wifiEncryptionTypeFromApi(
          json['encryptionType'] as String? ?? 'wpa3Personal'),
      hidden: json['hidden'] as bool? ?? false,
      maxClients: json['maxClients'] as int? ?? 8,
    );
  }

  Map<String, dynamic> _accessPointConfigToJson(AccessPointConfig config) {
    return {
      'ssid': config.ssid,
      'password': config.password,
      'band': _wifiBandToApi(config.band),
      'channel': config.channel,
      'encryptionType': _wifiEncryptionTypeToApi(config.encryptionType),
      'hidden': config.hidden,
      'maxClients': config.maxClients,
    };
  }

  NetworkMode _networkModeFromApi(String value) {
    switch (value) {
      case 'access_point':
        return NetworkMode.accessPoint;
      case 'lan_only':
        return NetworkMode.lanOnly;
      default:
        return NetworkMode.client;
    }
  }

  String _networkModeToApi(NetworkMode mode) {
    switch (mode) {
      case NetworkMode.accessPoint:
        return 'access_point';
      case NetworkMode.lanOnly:
        return 'lan_only';
      case NetworkMode.client:
        return 'client';
    }
  }

  WifiEncryptionType _wifiEncryptionTypeFromApi(String value) {
    switch (value) {
      case 'wpa2Personal':
        return WifiEncryptionType.wpa2Personal;
      case 'wpa3Personal':
        return WifiEncryptionType.wpa3Personal;
      case 'wpa2Enterprise':
        return WifiEncryptionType.wpa2Enterprise;
      case 'wpa3Enterprise':
        return WifiEncryptionType.wpa3Enterprise;
      default:
        return WifiEncryptionType.open;
    }
  }

  String _wifiEncryptionTypeToApi(WifiEncryptionType value) {
    switch (value) {
      case WifiEncryptionType.open:
        return 'open';
      case WifiEncryptionType.wpa2Personal:
        return 'wpa2Personal';
      case WifiEncryptionType.wpa3Personal:
        return 'wpa3Personal';
      case WifiEncryptionType.wpa2Enterprise:
        return 'wpa2Enterprise';
      case WifiEncryptionType.wpa3Enterprise:
        return 'wpa3Enterprise';
    }
  }

  WifiBand _wifiBandFromApi(String value) {
    switch (value) {
      case 'band2_4GHz':
        return WifiBand.band2_4GHz;
      case 'band5GHz':
        return WifiBand.band5GHz;
      default:
        return WifiBand.bandAuto;
    }
  }

  String _wifiBandToApi(WifiBand band) {
    switch (band) {
      case WifiBand.band2_4GHz:
        return 'band2_4GHz';
      case WifiBand.band5GHz:
        return 'band5GHz';
      case WifiBand.bandAuto:
        return 'bandAuto';
    }
  }

  WifiChannelScan _wifiChannelScanFromJson(Map<String, dynamic> json) {
    final channelsJson = json['channels'] as List<dynamic>? ?? const [];
    final networksJson = json['networks'] as List<dynamic>? ?? const [];
    return WifiChannelScan(
      band: _wifiBandFromApi(json['band'] as String? ?? 'bandAuto'),
      recommendedChannel: json['recommendedChannel'] as int? ?? 0,
      detectedNetworks: json['detectedNetworks'] as int? ?? 0,
      channels: channelsJson
          .map((item) => _wifiChannelInfoFromJson(item as Map<String, dynamic>))
          .toList(),
      networks: networksJson
          .map((item) =>
              _wifiDetectedNetworkFromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  WifiChannelInfo _wifiChannelInfoFromJson(Map<String, dynamic> json) {
    final ssids = json['ssids'] as List<dynamic>? ?? const [];
    return WifiChannelInfo(
      channel: json['channel'] as int? ?? 0,
      networkCount: json['networkCount'] as int? ?? 0,
      ssids: ssids.map((item) => item as String).toList(),
      isRecommended: json['isRecommended'] as bool? ?? false,
    );
  }

  WifiDetectedNetwork _wifiDetectedNetworkFromJson(Map<String, dynamic> json) {
    final affectedChannels =
        json['affectedChannels'] as List<dynamic>? ?? const [];
    return WifiDetectedNetwork(
      ssid: json['ssid'] as String? ?? '<Hidden>',
      channel: json['channel'] as int? ?? 0,
      frequencyMHz: json['frequencyMHz'] as int?,
      centerFrequencyMHz: json['centerFrequencyMHz'] as int?,
      channelWidthMHz: json['channelWidthMHz'] as int?,
      signalDbm: json['signalDbm'] as int?,
      qualityPercent: json['qualityPercent'] as int?,
      overlapStartChannel: json['overlapStartChannel'] as int? ?? 0,
      overlapEndChannel: json['overlapEndChannel'] as int? ?? 0,
      affectedChannels: affectedChannels.map((item) => item as int).toList(),
    );
  }
}
