import 'package:stpvelox/features/wifi/domain/enities/wifi_network.dart';

class DeviceInfo {
  final String ipAddress;
  final String? macAddress;
  final bool ethernetCableConnected;
  final String? ethernetIpAddress;
  final String? ethernetMacAddress;
  final String? wifiIpAddress;
  final String? wifiMacAddress;
  final WifiNetwork? connectedNetwork;

  /// Name of the active wired connection (e.g. "Wired connection 1").
  final String? ethernetConnectionName;

  /// Ethernet Mode only: "client" (address from the network) or "host" (the
  /// robot serves DHCP itself).
  final String? ethernetRole;

  /// Host only: devices currently on the cable.
  final int? ethernetConnectedDevices;

  DeviceInfo({
    required this.ipAddress,
    this.macAddress,
    this.ethernetCableConnected = false,
    this.ethernetIpAddress,
    this.ethernetMacAddress,
    this.wifiIpAddress,
    this.wifiMacAddress,
    this.connectedNetwork,
    this.ethernetConnectionName,
    this.ethernetRole,
    this.ethernetConnectedDevices,
  });
}
