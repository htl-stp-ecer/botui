import 'package:flutter/material.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_encryption_type.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_network.dart';

class WifiDetailInfoSection extends StatefulWidget {
  final WifiNetwork network;
  final TextEditingController passwordController;

  const WifiDetailInfoSection({
    super.key,
    required this.network,
    required this.passwordController,
  });

  @override
  State<WifiDetailInfoSection> createState() => _WifiDetailInfoSectionState();
}

class _WifiDetailInfoSectionState extends State<WifiDetailInfoSection> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final network = widget.network;
    final enc = network.encryptionType;
    final needsPwd =
        _needsPassword(enc) && !network.isKnown && !network.isConnected;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('SSID: ${network.ssid}', style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text('Encryption: ${enc.formatted}',
              style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          _statusWidget(network),
          if (needsPwd) ...[
            const SizedBox(height: 24),
            const Text('Password:'),
            TextField(
              controller: widget.passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'Enter password',
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusWidget(WifiNetwork network) {
    if (network.isConnected) {
      return const Text('Status: Connected',
          style: TextStyle(color: Colors.green, fontSize: 24));
    }
    if (network.isKnown) {
      return const Text('Status: Known (not connected)',
          style: TextStyle(color: Colors.orange, fontSize: 24));
    }
    return const Text('Status: Unknown (not connected)',
        style: TextStyle(color: Colors.orange, fontSize: 24));
  }

  bool _needsPassword(WifiEncryptionType enc) =>
      enc != WifiEncryptionType.open &&
      enc != WifiEncryptionType.wpa2Enterprise &&
      enc != WifiEncryptionType.wpa3Enterprise;
}
