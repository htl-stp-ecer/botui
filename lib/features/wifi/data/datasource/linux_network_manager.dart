import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:stpvelox/core/utils/sudo_process.dart';
import 'package:stpvelox/features/wifi/domain/enities/access_point_config.dart';
import 'package:stpvelox/features/wifi/domain/enities/network_mode.dart';
import 'package:stpvelox/features/wifi/domain/enities/saved_network.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_band.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_credentials.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_encryption_type.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_network.dart';
import 'package:stpvelox/shared/domain/entities/device_info.dart';

class LinuxNetworkManager {
  Future<List<WifiNetwork>> scanNetworks() async {
    await _ensureWifiEnabled();

    await SudoProcess.run('nmcli', ['device', 'wifi', 'rescan']);

    await Future.delayed(const Duration(milliseconds: 1000));

    final result = await SudoProcess.run(
        'nmcli', ['-f', 'SSID,SECURITY,IN-USE', 'dev', 'wifi']);
    if (result.exitCode != 0) {
      throw Exception('Failed to scan WiFi networks: ${result.stderr}');
    }

    final savedNetworks = await getSavedNetworks();
    final savedSSIDs = savedNetworks.map((n) => n.ssid).toSet();

    final lines = (result.stdout as String).split('\n').skip(1);
    final networksMap = <String, WifiNetwork>{}; // Use map to handle duplicates

    for (var line in lines) {
      if (line.trim().isEmpty) continue;

      final trimmedLine = line.trimRight();
      if (trimmedLine.isEmpty) continue;

      bool inUse = trimmedLine.endsWith('*');
      String workingLine = inUse
          ? trimmedLine.substring(0, trimmedLine.length - 1).trimRight()
          : trimmedLine;

      final parts =
          workingLine.split(RegExp(r'\s\s+')).where((p) => p.isNotEmpty).toList();
      if (parts.isEmpty) continue;

      String security = parts.last;
      parts.removeLast();
      String ssid = parts.join(" ");

      WifiEncryptionType encType = WifiEncryptionType.open;
      if (security.contains('WPA3')) {
        encType = security.contains('EAP')
            ? WifiEncryptionType.wpa3Enterprise
            : WifiEncryptionType.wpa3Personal;
      } else if (security.contains('WPA2')) {
        encType = security.contains('EAP')
            ? WifiEncryptionType.wpa2Enterprise
            : WifiEncryptionType.wpa2Personal;
      }

      WifiNetwork network = WifiNetwork(
        ssid: ssid,
        encryptionType: encType,
        isConnected: inUse,
        isKnown: savedSSIDs.contains(ssid),
      );

      // Handle duplicates: prefer connected, then known, then first occurrence
      if (networksMap.containsKey(ssid)) {
        final existing = networksMap[ssid]!;
        // Only replace if new one has higher priority
        if (network.isConnected && !existing.isConnected) {
          networksMap[ssid] = network;
        } else if (!existing.isConnected && !existing.isKnown && network.isKnown) {
          networksMap[ssid] = network;
        }
      } else {
        networksMap[ssid] = network;
      }
    }

    // Convert map to list and sort by priority
    final networksList = networksMap.values.toList();
    networksList.sort((a, b) => a.compareTo(b));
    networksList.removeWhere((n) => n.ssid == "--" || n.ssid.isEmpty);

    return networksList;
  }

  Future<void> connect(String ssid, WifiEncryptionType encType,
      WifiCredentials credentials) async {
    // Remove any existing connection for this SSID first to avoid
    // key-mgmt property conflicts when reconnecting or changing settings.
    await _deleteExistingConnection(ssid);

    final wifiInterface = await _getWifiInterface();
    if (wifiInterface == null) {
      throw Exception('No WiFi interface found');
    }

    switch (encType) {
      case WifiEncryptionType.open:
        final result = await SudoProcess.run(
            'nmcli', ['device', 'wifi', 'connect', ssid]);
        if (result.exitCode != 0) {
          throw Exception('Failed to connect: ${result.stderr}');
        }
        break;
      case WifiEncryptionType.wpa2Personal:
      case WifiEncryptionType.wpa3Personal:
        final passCred = credentials as PersonalCredentials;
        final result = await SudoProcess.run('nmcli',
            ['device', 'wifi', 'connect', ssid, 'password', passCred.password]);
        if (result.exitCode != 0) {
          throw Exception('Failed to connect: ${result.stderr}');
        }
        break;
      case WifiEncryptionType.wpa2Enterprise:
      case WifiEncryptionType.wpa3Enterprise:
        final entCred = credentials as EnterpriseCredentials;

        final addArgs = [
          'connection',
          'add',
          'type',
          'wifi',
          'con-name',
          ssid,
          'ifname',
          wifiInterface,
          'ssid',
          ssid,
          'wifi-sec.key-mgmt',
          'wpa-eap',
          '802-1x.eap',
          'peap',
          '802-1x.identity',
          entCred.username,
          '802-1x.password',
          entCred.password,
        ];

        if (entCred.caCertificatePath != null) {
          addArgs.addAll(['802-1x.ca-cert', entCred.caCertificatePath!]);
        }

        final addResult = await SudoProcess.run('nmcli', addArgs);
        if (addResult.exitCode != 0) {
          throw Exception(
              'Failed to create connection: ${addResult.stderr}');
        }

        final upResult =
            await SudoProcess.run('nmcli', ['connection', 'up', ssid]);
        if (upResult.exitCode != 0) {
          // Clean up the connection we just created
          await SudoProcess.run('nmcli', ['connection', 'delete', ssid]);
          throw Exception('Failed to connect: ${upResult.stderr}');
        }
        break;
    }
  }

  /// Delete any existing nmcli connection profile for [ssid].
  /// Silently ignores errors (e.g. if no connection exists).
  Future<void> _deleteExistingConnection(String ssid) async {
    // Try direct delete by connection name first
    final result =
        await SudoProcess.run('nmcli', ['connection', 'delete', ssid]);
    if (result.exitCode == 0) return;

    // Fallback: find by SSID property in case the con-name differs
    final listResult = await SudoProcess.run(
        'nmcli', ['-t', '-f', 'UUID,TYPE', 'connection', 'show']);
    if (listResult.exitCode != 0) return;

    final lines = (listResult.stdout as String).split('\n');
    for (final line in lines) {
      final parts = line.split(':');
      if (parts.length < 2) continue;
      final uuid = parts[0].trim();
      if (uuid.isEmpty) continue;
      // Only check wifi connections
      if (!parts[1].contains('wireless') && !parts[1].contains('wifi')) {
        continue;
      }

      final showResult = await SudoProcess.run(
        'nmcli',
        ['-t', '-f', '802-11-wireless.ssid', 'connection', 'show', uuid],
      );
      if (showResult.exitCode != 0) continue;
      final connSsid =
          (showResult.stdout as String).split(':').last.trim();
      if (connSsid == ssid) {
        await SudoProcess.run(
            'nmcli', ['connection', 'delete', 'uuid', uuid]);
      }
    }
  }

  String _normalizeSsid(String ssid) {
    return ssid.split(':').first.trim();
  }

  Future<void> forget(String ssid) async {
    final normalizedSsid = _normalizeSsid(ssid);

    // Try deleting by given name first (fast path)
    final result =
        await SudoProcess.run('nmcli', ['connection', 'delete', ssid]);
    if (result.exitCode == 0) {
      try {
        await removeSavedNetwork(normalizedSsid);
      } catch (_) {}
      return;
    }

    // Fallback: enumerate connections and match 802-11-wireless.ssid
    try {
      final listResult =
          await SudoProcess.run('nmcli', ['-t', '-f', 'UUID', 'connection', 'show']);
      if (listResult.exitCode != 0) {
        try {
          await removeSavedNetwork(normalizedSsid);
        } catch (_) {}
        throw Exception('Failed to list connections: ${listResult.stderr}');
      }

      final uuids = (listResult.stdout as String)
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty);

      String? foundUuid;
      for (final uuid in uuids) {
        final showResult = await SudoProcess.run(
          'nmcli',
          ['-t', '-f', '802-11-wireless.ssid', 'connection', 'show', uuid],
        );
        if (showResult.exitCode != 0) continue;
        final connSsid = (showResult.stdout as String).trim();
        if (connSsid == normalizedSsid) {
          foundUuid = uuid;
          break;
        }
      }

      if (foundUuid != null) {
        final delResult = await SudoProcess.run(
            'nmcli', ['connection', 'delete', 'uuid', foundUuid]);
        if (delResult.exitCode != 0) {
          throw Exception('Failed to forget network by UUID: ${delResult.stderr}');
        }
      } else {
        // No matching connection found — treat as already-removed
      }

      try {
        await removeSavedNetwork(normalizedSsid);
      } catch (_) {}
    } catch (e) {
      throw Exception('Failed to forget network: $e');
    }
  }

  Future<DeviceInfo> getDeviceInfo() async {
    try {
      final ipResult = await SudoProcess.run('hostname', ['-I']);
      if (ipResult.exitCode != 0) {
        throw Exception('Failed to retrieve IP address: ${ipResult.stderr}');
      }
      final ipAddress = (ipResult.stdout as String).trim().split(' ').first;

      final connResult = await SudoProcess.run(
          'nmcli', ['-t', '-f', 'SSID,SECURITY,IN-USE', 'dev', 'wifi']);
      if (connResult.exitCode != 0) {
        throw Exception(
            'Failed to retrieve connected network: ${connResult.stderr}');
      }

      final lines = (connResult.stdout as String).split('\n');
      WifiNetwork? connectedNetwork;
      for (var line in lines) {
        if (line.contains('*')) {
          final parts = line.split(':');
          if (parts.isNotEmpty) {
            final ssid = parts[0];
            final security = parts.length > 1 ? parts[1] : '';
            WifiEncryptionType encType = WifiEncryptionType.open;
            if (security.contains('WPA3')) {
              encType = security.contains('EAP')
                  ? WifiEncryptionType.wpa3Enterprise
                  : WifiEncryptionType.wpa3Personal;
            } else if (security.contains('WPA2')) {
              encType = security.contains('EAP')
                  ? WifiEncryptionType.wpa2Enterprise
                  : WifiEncryptionType.wpa2Personal;
            }

            connectedNetwork = WifiNetwork(
              ssid: ssid,
              encryptionType: encType,
              isConnected: true,
              isKnown: true,
            );
            break;
          }
        }
      }

      return DeviceInfo(
          ipAddress: ipAddress, connectedNetwork: connectedNetwork);
    } catch (e) {
      throw Exception('Error retrieving device info: $e');
    }
  }

  Future<NetworkMode> getCurrentNetworkMode() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('network_mode') ?? 'client';

    switch (mode) {
      case 'access_point':
        return NetworkMode.accessPoint;
      case 'lan_only':
        return NetworkMode.lanOnly;
      default:
        return NetworkMode.client;
    }
  }

  Future<void> setNetworkMode(NetworkMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    String modeString;

    switch (mode) {
      case NetworkMode.accessPoint:
        modeString = 'access_point';
        break;
      case NetworkMode.lanOnly:
        modeString = 'lan_only';
        break;
      default:
        modeString = 'client';
    }

    await prefs.setString('network_mode', modeString);
  }

  Future<void> startAccessPoint(AccessPointConfig config) async {
    try {
      await stopAccessPoint();

      // Get the actual WiFi interface name
      final wifiInterface = await _getWifiInterface();
      if (wifiInterface == null) {
        throw Exception('No WiFi interface found');
      }

      if (config.channel == 0) {
        final bestChannel = await findBestChannel(config.band);
        config = config.copyWith(
          ssid: config.ssid,
          password: config.password,
          band: config.band,
          channel: bestChannel,
          encryptionType: config.encryptionType,
          hidden: config.hidden,
          maxClients: config.maxClients,
        );
      }

      // Use the simpler 'nmcli device wifi hotspot' command
      final args = [
        'device',
        'wifi',
        'hotspot',
        'ifname',
        wifiInterface,
        'con-name',
        'STP-Velox-AP',
        'ssid',
        config.ssid,
      ];

      // Add password if provided
      if (config.password.isNotEmpty) {
        args.addAll(['password', config.password]);
      }

      // Add band and channel together (nmcli requires band when channel is specified)
      if (config.channel > 0 && config.band != WifiBand.bandAuto) {
        args.addAll([
          'band',
          config.band.nmcliValue,
          'channel',
          config.channel.toString()
        ]);
      } else if (config.band != WifiBand.bandAuto) {
        // Band only, no specific channel
        args.addAll(['band', config.band.nmcliValue]);
      }

      print('Creating AP with command: nmcli ${args.join(' ')}');

      final result = await SudoProcess.run('nmcli', args);
      if (result.exitCode != 0) {
        throw Exception('Failed to create AP: ${result.stderr}');
      }

      print('AP created successfully, stdout: ${result.stdout}');
      print('AP created successfully, stderr: ${result.stderr}');

      await _saveAccessPointConfig(config);
      await setNetworkMode(NetworkMode.accessPoint);
    } catch (e) {
      throw Exception('Failed to start access point: $e');
    }
  }

  Future<void> stopAccessPoint() async {
    try {
      final connectionName = 'STP-Velox-AP';

      await SudoProcess.run('nmcli', ['connection', 'down', connectionName]);

      await SudoProcess.run('nmcli', ['connection', 'delete', connectionName]);

      await _resetWifiInterface();
    } catch (e) {
      try {
        await _resetWifiInterface();
      } catch (resetError) {}
    }
  }

  Future<bool> isAccessPointActive() async {
    try {
      final result = await SudoProcess.run('nmcli',
          ['-t', '-f', 'NAME,TYPE,DEVICE', 'connection', 'show', '--active']);
      if (result.exitCode != 0) return false;

      final lines = (result.stdout as String).split('\n');
      for (var line in lines) {
        if (line.contains('STP-Velox-AP') && line.contains('wifi')) {
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<AccessPointConfig?> getAccessPointConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final configJson = prefs.getString('ap_config');
    if (configJson == null) return null;

    try {
      final config = json.decode(configJson) as Map<String, dynamic>;
      return AccessPointConfig(
        ssid: config['ssid'] as String,
        password: config['password'] as String,
        band: WifiBand.values.firstWhere(
          (b) => b.toString() == config['band'],
          orElse: () => WifiBand.bandAuto,
        ),
        channel: config['channel'] as int? ?? 0,
        encryptionType: WifiEncryptionType.values.firstWhere(
          (e) => e.toString() == config['encryptionType'],
          orElse: () => WifiEncryptionType.wpa3Personal,
        ),
        hidden: config['hidden'] as bool? ?? false,
        maxClients: config['maxClients'] as int? ?? 8,
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveAccessPointConfig(AccessPointConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final configJson = json.encode({
      'ssid': config.ssid,
      'password': config.password,
      'band': config.band.toString(),
      'channel': config.channel,
      'encryptionType': config.encryptionType.toString(),
      'hidden': config.hidden,
      'maxClients': config.maxClients,
    });
    await prefs.setString('ap_config', configJson);
  }

  Future<WifiBand> findBestWifiBand() async {
    try {
      final result = await SudoProcess.run('iw', ['phy', 'phy0', 'info']);
      if (result.exitCode == 0 && (result.stdout as String).contains('5180')) {
        return WifiBand.band5GHz;
      } else {
        return WifiBand.band2_4GHz;
      }
    } catch (e) {
      return WifiBand.band2_4GHz;
    }
  }

  Future<int> findBestChannel(WifiBand band) async {
    try {
      final wifiInterface = await _getWifiInterface();
      if (wifiInterface == null) {
        return band.channels.first;
      }

      final channels = band.channels;
      final interference = <int, int>{};

      for (int channel in channels) {
        interference[channel] = 0;
      }

      final scanResult = await SudoProcess.run('iwlist', [wifiInterface, 'scan']);
      if (scanResult.exitCode == 0) {
        final output = scanResult.stdout as String;
        final lines = output.split('\n');

        for (var line in lines) {
          if (line.contains('Channel:')) {
            final match = RegExp(r'Channel:(\d+)').firstMatch(line);
            if (match != null) {
              final channel = int.tryParse(match.group(1)!);
              if (channel != null && interference.containsKey(channel)) {
                interference[channel] = interference[channel]! + 1;
              }
            }
          }
        }
      }

      int bestChannel = channels.first;
      int minInterference = interference[bestChannel] ?? 0;

      for (var channel in channels) {
        final channelInterference = interference[channel] ?? 0;
        if (channelInterference < minInterference) {
          minInterference = channelInterference;
          bestChannel = channel;
        }
      }

      return bestChannel;
    } catch (e) {
      return band.channels.first;
    }
  }

  Future<List<SavedNetwork>> getSavedNetworks() async {
    final prefs = await SharedPreferences.getInstance();
    final savedNetworksJson = prefs.getStringList('saved_networks') ?? [];

    return savedNetworksJson.map((networkJson) {
      final network = json.decode(networkJson) as Map<String, dynamic>;

      WifiCredentials credentials;
      final credType = network['credentialsType'] as String;
      if (credType == 'personal') {
        credentials = PersonalCredentials(network['password'] as String);
      } else {
        credentials = EnterpriseCredentials(
          username: network['username'] as String,
          password: network['password'] as String,
          caCertificatePath: network['caCertificatePath'] as String?,
        );
      }

      return SavedNetwork(
        ssid: network['ssid'] as String,
        encryptionType: WifiEncryptionType.values.firstWhere(
          (e) => e.toString() == network['encryptionType'],
          orElse: () => WifiEncryptionType.wpa2Personal,
        ),
        credentials: credentials,
        lastConnected: DateTime.parse(network['lastConnected'] as String),
        autoConnect: network['autoConnect'] as bool? ?? true,
      );
    }).toList();
  }

  Future<void> saveNetwork(SavedNetwork network) async {
    final prefs = await SharedPreferences.getInstance();
    final savedNetworks = await getSavedNetworks();

    savedNetworks.removeWhere((n) => n.ssid == network.ssid);

    savedNetworks.add(network);

    final networksJson = savedNetworks.map((n) {
      final Map<String, dynamic> networkMap = {
        'ssid': n.ssid,
        'encryptionType': n.encryptionType.toString(),
        'lastConnected': n.lastConnected.toIso8601String(),
        'autoConnect': n.autoConnect,
      };

      if (n.credentials is PersonalCredentials) {
        final creds = n.credentials as PersonalCredentials;
        networkMap['credentialsType'] = 'personal';
        networkMap['password'] = creds.password;
      } else if (n.credentials is EnterpriseCredentials) {
        final creds = n.credentials as EnterpriseCredentials;
        networkMap['credentialsType'] = 'enterprise';
        networkMap['username'] = creds.username;
        networkMap['password'] = creds.password;
        networkMap['caCertificatePath'] = creds.caCertificatePath;
      }

      return json.encode(networkMap);
    }).toList();

    await prefs.setStringList('saved_networks', networksJson);
  }

  Future<void> removeSavedNetwork(String ssid) async {
    final prefs = await SharedPreferences.getInstance();
    final savedNetworks = await getSavedNetworks();

    final target = _normalizeSsid(ssid);

    savedNetworks.removeWhere((n) {
      final nNorm = _normalizeSsid(n.ssid);
      return nNorm == target || n.ssid.trim() == ssid.trim();
    });

    final networksJson = savedNetworks.map((n) {
      final Map<String, dynamic> networkMap = {
        'ssid': n.ssid,
        'encryptionType': n.encryptionType.toString(),
        'lastConnected': n.lastConnected.toIso8601String(),
        'autoConnect': n.autoConnect,
      };

      if (n.credentials is PersonalCredentials) {
        final creds = n.credentials as PersonalCredentials;
        networkMap['credentialsType'] = 'personal';
        networkMap['password'] = creds.password;
      } else if (n.credentials is EnterpriseCredentials) {
        final creds = n.credentials as EnterpriseCredentials;
        networkMap['credentialsType'] = 'enterprise';
        networkMap['username'] = creds.username;
        networkMap['password'] = creds.password;
        networkMap['caCertificatePath'] = creds.caCertificatePath;
      }

      return json.encode(networkMap);
    }).toList();

    await prefs.setStringList('saved_networks', networksJson);
  }

  Future<SavedNetwork?> getSavedNetwork(String ssid) async {
    final savedNetworks = await getSavedNetworks();
    try {
      return savedNetworks.firstWhere((n) => n.ssid == ssid);
    } catch (e) {
      return null;
    }
  }

  Future<void> enableLanOnlyMode() async {
    try {
      await SudoProcess.run('nmcli', ['radio', 'wifi', 'off']);

      await SudoProcess.run(
          'nmcli', ['connection', 'up', 'Wired connection 1']);

      await setNetworkMode(NetworkMode.lanOnly);
    } catch (e) {
      throw Exception('Failed to enable LAN only mode: $e');
    }
  }

  Future<void> disableLanOnlyMode() async {
    try {
      await SudoProcess.run('nmcli', ['radio', 'wifi', 'on']);

      await setNetworkMode(NetworkMode.client);
    } catch (e) {
      throw Exception('Failed to disable LAN only mode: $e');
    }
  }

  Future<bool> isLanOnlyModeActive() async {
    try {
      final result = await SudoProcess.run('nmcli', ['radio', 'wifi']);
      if (result.exitCode != 0) return false;

      final output = (result.stdout as String).trim();
      return output.contains('disabled');
    } catch (e) {
      return false;
    }
  }

  /// Check if an ethernet cable is physically connected
  Future<bool> isEthernetCableConnected() async {
    try {
      // Get all ethernet devices and their carrier status
      final result = await SudoProcess.run(
          'nmcli', ['-t', '-f', 'DEVICE,TYPE,STATE', 'device', 'status']);
      if (result.exitCode != 0) return false;

      final lines = (result.stdout as String).split('\n');
      for (var line in lines) {
        final parts = line.split(':');
        if (parts.length >= 3 && parts[1] == 'ethernet') {
          // Check if device state is connected or connecting
          final state = parts[2].toLowerCase();
          if (state.contains('connected') || state.contains('connecting')) {
            return true;
          }

          // Also check carrier status via sysfs (more reliable for cable detection)
          final device = parts[0];
          try {
            final carrierResult = await SudoProcess.run(
                'cat', ['/sys/class/net/$device/carrier']);
            if (carrierResult.exitCode == 0) {
              final carrier = (carrierResult.stdout as String).trim();
              if (carrier == '1') return true;
            }
          } catch (_) {
            // Continue checking other methods
          }
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _ensureWifiEnabled() async {
    try {
      final radioResult = await SudoProcess.run('nmcli', ['radio', 'wifi']);
      if (radioResult.exitCode == 0) {
        final output = (radioResult.stdout as String).trim();
        if (output.contains('disabled')) {
          await SudoProcess.run('nmcli', ['radio', 'wifi', 'on']);

          await Future.delayed(const Duration(milliseconds: 2000));
        }
      }

      final wifiInterface = await _getWifiInterface();
      if (wifiInterface != null) {
        await SudoProcess.run(
            'nmcli', ['device', 'set', wifiInterface, 'managed', 'yes']);
      }
    } catch (e) {
      print('Warning: Could not ensure WiFi enabled: $e');
    }
  }

  Future<void> _resetWifiInterface() async {
    try {
      final wifiInterface = await _getWifiInterface();
      if (wifiInterface == null) {
        print('Warning: No WiFi interface found');
        return;
      }

      await SudoProcess.run('ip', ['link', 'set', wifiInterface, 'down']);
      await Future.delayed(const Duration(milliseconds: 500));
      await SudoProcess.run('ip', ['link', 'set', wifiInterface, 'up']);
      await Future.delayed(const Duration(milliseconds: 500));

      await SudoProcess.run(
          'nmcli', ['device', 'set', wifiInterface, 'managed', 'yes']);

      await SudoProcess.run('nmcli', ['device', 'wifi', 'rescan']);
    } catch (e) {
      print('Warning: Could not reset WiFi interface: $e');
    }
  }

  Future<String?> _getWifiInterface() async {
    try {
      final result = await SudoProcess.run(
          'nmcli', ['-t', '-f', 'DEVICE,TYPE', 'device', 'status']);
      if (result.exitCode != 0) return null;

      final lines = (result.stdout as String).split('\n');
      for (var line in lines) {
        final parts = line.split(':');
        if (parts.length >= 2 && parts[1] == 'wifi') {
          final device = parts[0];
          // Skip p2p-dev interfaces, they can't be used for connections
          if (device.startsWith('p2p-dev-')) continue;
          return device;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
