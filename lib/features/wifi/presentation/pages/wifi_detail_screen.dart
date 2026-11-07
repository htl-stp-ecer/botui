import 'package:stpvelox/core/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stpvelox/application/theme/color_theme_provider.dart';
import 'package:stpvelox/core/logging/has_logging.dart';
import 'package:stpvelox/core/theme/app_theme.dart';
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
      // Only a new result counts: the state still carries the last one while a
      // new operation starts.
      if (state.errorMessage != null &&
          state.errorMessage != previous?.errorMessage) {
        _showSnack(context, state.errorMessage!, Colors.red);
      } else if (state.connectedSsid != null &&
          state.connectedSsid != previous?.connectedSsid) {
        _showSnack(
            context, 'Connected to ${state.connectedSsid}', Colors.green);
        context.pop();
      } else if (state.forgottenSsid != null &&
          state.forgottenSsid != previous?.forgottenSsid) {
        _showSnack(context, 'Forgotten network ${state.forgottenSsid}', Colors.green);
        context.pop();
      }
    });

    final state = ref.watch(wifiClientProvider);
    final busy = state.isLoading;

    return Scaffold(
      backgroundColor: Colors.black87,
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
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
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
        color: TileColor.red,
        position: 0,
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
              color: TileColor.green,
              position: 0,
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
              color: TileColor.red,
              position: 1,
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
        color: TileColor.blue,
        position: 0,
        onPressed: () => _navigateToEnterpriseCredentials(network),
        busy: busy,
      );
    }

    if (enc == WifiEncryptionType.open) {
      return _styledButton(
        label: 'Connect (No Password)',
        icon: Icons.wifi_outlined,
        color: TileColor.green,
        position: 0,
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
      color: TileColor.blue,
      position: 0,
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
    required TileColor color,
    required int position,
    required VoidCallback onPressed,
    required bool busy,
    String? busyLabel,
  }) {
    final theme = ref.watch(colorThemeProvider);
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: busy ? null : onPressed,
        icon: busy ? _spinner(theme.textColor) : Icon(icon, size: 22),
        label: Text(busy ? (busyLabel ?? 'Processing...') : label),
        // Same button as on the manual connect screen.
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.tileColor(color, position),
          foregroundColor: theme.textColor,
          disabledBackgroundColor:
              theme.tileColor(color, position).withValues(alpha: 0.6),
          disabledForegroundColor: theme.textColor.withValues(alpha: 0.8),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  void _navigateToEnterpriseCredentials(WifiNetwork network) async {
    final creds = await context.push<WifiCredentials?>(
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

  Widget _spinner(Color color) => SizedBox(
    width: 16,
    height: 16,
    child: CircularProgressIndicator(strokeWidth: 2, color: color),
  );
}
