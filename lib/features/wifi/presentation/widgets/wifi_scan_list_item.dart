// dart
import 'package:stpvelox/core/router/safe_navigation.dart';
import 'package:stpvelox/core/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/features/wifi/application/saved_networks_notifier.dart';
import 'package:stpvelox/features/wifi/application/wifi_client_notifier.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_encryption_type.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_network.dart';
import 'package:stpvelox/core/logging/has_logging.dart';

class WifiScanListItem extends ConsumerStatefulWidget {
  final WifiNetwork network;

  const WifiScanListItem({super.key, required this.network});

  @override
  ConsumerState<WifiScanListItem> createState() => _WifiScanListItemState();
}

class _WifiScanListItemState extends ConsumerState<WifiScanListItem>
    with HasLogger {
  bool _isConnecting = false;

  @override
  Widget build(BuildContext context) {
    final network = widget.network;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        tileColor: Colors.grey[900],
        title: Text(
          network.ssid,
          style: TextStyle(
            fontSize: 16,
            fontWeight:
            network.isConnected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              network.isConnected
                  ? 'Connected'
                  : network.isKnown
                  ? 'Saved Network - Tap to connect'
                  : 'Tap to configure',
              style: TextStyle(
                color: network.isConnected
                    ? Colors.green
                    : network.isKnown
                    ? Colors.blue
                    : Colors.grey,
              ),
            ),
            if (network.encryptionType != WifiEncryptionType.open)
              Text(
                _getEncryptionLabel(network.encryptionType),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
          ],
        ),
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              network.isKnown ? Icons.bookmark : Icons.wifi,
              color: network.isConnected
                  ? Colors.green
                  : network.isKnown
                  ? Colors.blue
                  : Colors.grey,
            ),
            if (network.encryptionType != WifiEncryptionType.open)
              const Icon(
                Icons.lock,
                size: 12,
                color: Colors.grey,
              ),
          ],
        ),
        trailing: network.isKnown && !network.isConnected
            ? (_isConnecting
            ? const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green),
        )
            : IconButton(
          onPressed: () async {
            setState(() {
              _isConnecting = true;
            });
            try {
              await ref
                  .read(savedNetworksProvider.notifier)
                  .connectToSavedNetwork(network.ssid);

              await ref
                  .read(wifiClientProvider.notifier)
                  .loadNetworks();

              if (mounted) {
                AppToast.success('Connected — list refreshed');
              }
            } catch (e) {
              log.severe('Quick connect failed for ${network.ssid}: $e');
              if (mounted) {
                AppToast.error('Quick connect failed: $e');
              }
            } finally {
              if (mounted) {
                setState(() {
                  _isConnecting = false;
                });
                log.info("Quick connected to ${network.ssid}");
              }
            }
          },
          icon: const Icon(Icons.play_arrow, color: Colors.green),
          tooltip: 'Quick Connect',
        ))
            : Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey.shade400,
        ),
        onTap: () => context.pushOnce(AppRoutes.wifiDetail, extra: network),
      ),
    );
  }

  String _getEncryptionLabel(WifiEncryptionType encryptionType) {
    switch (encryptionType) {
      case WifiEncryptionType.wpa3Personal:
        return 'WPA3';
      case WifiEncryptionType.wpa2Personal:
        return 'WPA2';
      case WifiEncryptionType.wpa3Enterprise:
        return 'WPA3 Enterprise';
      case WifiEncryptionType.wpa2Enterprise:
        return 'WPA2 Enterprise';
      case WifiEncryptionType.open:
        return 'Open';
    }
  }
}
