import 'package:stpvelox/core/router/safe_navigation.dart';
import 'package:stpvelox/core/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stpvelox/core/logging/has_logging.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/wifi/application/saved_networks_notifier.dart';
import 'package:stpvelox/features/wifi/application/wifi_client_notifier.dart';
import 'package:stpvelox/features/wifi/domain/application/wifi_client_state.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_encryption_type.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_network.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_credentials.dart';
import 'package:stpvelox/features/wifi/presentation/widgets/wifi_detail_info_section.dart';

class WifiDetailScreen extends ConsumerStatefulWidget {
  const WifiDetailScreen({super.key, required this.network});

  final WifiNetwork network;

  @override
  ConsumerState<WifiDetailScreen> createState() => _WifiDetailScreenState();
}

class _WifiDetailScreenState extends ConsumerState<WifiDetailScreen> with HasLogger {
  final TextEditingController _passwordController = TextEditingController();
  bool _isConnecting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<WifiClientState>(wifiClientProvider, (previous, state) {
      if (state.errorMessage != null) {
        _showSnack(context, 'Error: ${state.errorMessage}', Colors.red);
      } else if (state.connectedSsid != null) {
        _showSnack(
            context, 'Connected to ${state.connectedSsid} successfully!', Colors.green);
        context.pop();
      } else if (state.forgottenSsid != null) {
        _showSnack(context, 'Forgotten network ${state.forgottenSsid}', Colors.green);
        context.pop();
      }
    });

    final state = ref.watch(wifiClientProvider);
    final busy = state.isLoading;

    return Scaffold(
      appBar: createTopBar(context, 'WiFi: ${widget.network.ssid}'),
      body: Column(
        children: [
          Expanded(
            child: WifiDetailInfoSection(
              network: widget.network,
              passwordController: _passwordController,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: _buildBottomButton(widget.network, busy),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton(WifiNetwork network, bool busy) {
    if (network.isConnected) {
      return _styledButton(
        label: 'Forget Network',
        icon: Icons.delete,
        backgroundColor: Colors.red[700]!,
        onPressed: () async {
          await ref.read(wifiClientProvider.notifier).forgetNetwork(network.ssid);
        },
        busy: busy,
      );
    }

    if (network.isKnown) {
      return Row(
        children: [
          Expanded(
            child: _styledButton(
              label: 'Connect',
              icon: Icons.wifi,
              backgroundColor: Colors.green[700]!,
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

                  log.info('Connected to ${network.ssid}!');

                  if (mounted) {
                    context.pop();
                  }
                } catch (e) {
                  log.severe('Failed to connect: $e');
                } finally {
                  if (mounted) {
                    setState(() {
                      _isConnecting = false;
                    });
                  }
                }
              },
              busy: _isConnecting,
              busyLabel: 'Connecting...',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _styledButton(
              label: 'Forget',
              icon: Icons.delete,
              backgroundColor: Colors.red[700]!,
              onPressed: () async {
                await ref.read(wifiClientProvider.notifier).forgetNetwork(network.ssid);
              },
              busy: busy,
            ),
          ),
        ],
      );
    }

    final enc = network.encryptionType;
    if (enc == WifiEncryptionType.wpa2Enterprise ||
        enc == WifiEncryptionType.wpa3Enterprise) {
      return _styledButton(
        label: 'Enter Enterprise Credentials',
        icon: Icons.business,
        backgroundColor: Colors.blue[700]!,
        onPressed: () => _navigateToEnterpriseCredentials(network),
        busy: busy,
      );
    }

    if (enc == WifiEncryptionType.open) {
      return _styledButton(
        label: 'Connect (No Password)',
        icon: Icons.wifi_outlined,
        backgroundColor: Colors.green[700]!,
        onPressed: () async {
          await ref
              .read(wifiClientProvider.notifier)
              .connectToNetwork(network.ssid, enc, PersonalCredentials(''));
        },
        busy: busy,
        busyLabel: 'Connecting...',
      );
    }

    return _styledButton(
      label: 'Connect',
      icon: Icons.lock_open,
      backgroundColor: Colors.blue[700]!,
      onPressed: () async {
        final pwd = _passwordController.text.trim();
        if (pwd.isEmpty) {
          _showSnack(context, 'Password cannot be empty', Colors.red);
          return;
        }
        await ref
            .read(wifiClientProvider.notifier)
            .connectToNetwork(network.ssid, enc, PersonalCredentials(pwd));
      },
      busy: busy,
      busyLabel: 'Connecting...',
    );
  }

  Widget _styledButton({
    required String label,
    required IconData icon,
    required Color backgroundColor,
    required VoidCallback onPressed,
    required bool busy,
    String? busyLabel,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: busy ? null : onPressed,
        icon: busy ? _spinner() : Icon(icon, size: 20),
        label: Text(busy ? (busyLabel ?? 'Processing...') : label),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  void _navigateToEnterpriseCredentials(WifiNetwork network) async {
    final creds = await context.pushOnce<WifiCredentials?>(
      AppRoutes.wifiEnterprise,
      extra: network.ssid,
    );
    if (creds != null) {
      ref
          .read(wifiClientProvider.notifier)
          .connectToNetwork(network.ssid, network.encryptionType, creds);
    }
  }

  void _showSnack(BuildContext context, String msg, Color color) {
    if (color == Colors.red) {
      AppToast.error(msg);
    } else {
      AppToast.success(msg);
    }
  }

  Widget _spinner() => const SizedBox(
    width: 16,
    height: 16,
    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
  );
}
