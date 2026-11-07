import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/application/theme/color_theme_provider.dart';
import 'package:stpvelox/core/theme/app_theme.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/wifi/application/network_mode_notifier.dart';
import 'package:stpvelox/features/wifi/application/wifi_client_notifier.dart';
import 'package:stpvelox/features/wifi/application/wifi_provider.dart';
import 'package:stpvelox/features/wifi/domain/application/access_point_state.dart';
import 'package:stpvelox/features/wifi/domain/application/wifi_client_state.dart';
import 'package:stpvelox/features/wifi/domain/enities/access_point_config.dart';
import 'package:stpvelox/features/wifi/domain/enities/network_mode.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_band.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_encryption_type.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_network.dart';
import 'package:stpvelox/shared/domain/entities/device_info.dart';

class DeviceInfoScreen extends ConsumerStatefulWidget {
  const DeviceInfoScreen({super.key});

  @override
  ConsumerState<DeviceInfoScreen> createState() => _DeviceInfoScreenState();
}

class _DeviceInfoScreenState extends ConsumerState<DeviceInfoScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loadingController;
  Timer? _clientsTimer;
  bool _showHotspotPassword = false;
  // False until device info and hotspot state have both loaded, so every card
  // appears at once instead of the hotspot card popping in afterwards.
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    Future.microtask(() async {
      await Future.wait([
        ref.read(wifiClientProvider.notifier).loadDeviceInfo(),
        ref.read(accessPointProvider.notifier).refreshStatus(),
        ref.read(networkModeProvider.notifier).loadNetworkMode(),
      ]);
      if (mounted) setState(() => _ready = true);
    });
    _clientsTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      ref.read(accessPointProvider.notifier).refreshConnectedClients();
    });
  }

  @override
  void dispose() {
    _clientsTimer?.cancel();
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wifiClientProvider);
    final apState = ref.watch(accessPointProvider);

    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: createTopBar(context, 'Device Information'),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _buildBody(state, apState),
        ),
      ),
    );
  }

  Widget _buildBody(WifiClientState state, AccessPointState apState) {
    if (!_ready || state.isLoading) {
      return Center(
        key: const ValueKey('loading'),
        child: _LoadingPanel(controller: _loadingController),
      );
    }

    if (state.errorMessage != null) {
      return Center(
        key: const ValueKey('error'),
        child: _ErrorPanel(message: state.errorMessage!),
      );
    }

    if (state.deviceInfo == null) {
      return Center(
        key: const ValueKey('empty'),
        child: _EmptyPanel(
          onRetry: () => ref.read(wifiClientProvider.notifier).loadDeviceInfo(),
        ),
      );
    }

    final deviceInfo = state.deviceInfo!;
    final network = deviceInfo.connectedNetwork;
    final hotspot = apState.isStarted ? apState.config : null;
    final ethernetMode =
        ref.watch(networkModeProvider).mode == NetworkMode.lanOnly;

    // Two sections: the one of the current tab (hotspot, Ethernet or Wi-Fi
    // details) and the "Connection" card with the address and status that
    // every tab shares.
    final theme = ref.watch(colorThemeProvider);
    final specific = hotspot != null
        ? _buildHotspotCard(hotspot, apState.connectedClients,
            theme.tileColor(TileColor.purple, 0))
        : ethernetMode
            ? _buildEthernetCard(deviceInfo, theme.tileColor(TileColor.brown, 0))
            : network != null
                ? _buildWifiCard(network, theme.tileColor(TileColor.teal, 0))
                : null;

    // Column in a SingleChildScrollView (not a lazy ListView) so all cards are
    // built up front and none pops in or out while scrolling.
    return SingleChildScrollView(
      key: const ValueKey('content'),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (specific != null) ...[
            specific,
            const SizedBox(height: 14),
          ],
          _buildConnectionCard(
            deviceInfo,
            theme: theme,
            position: specific != null ? 1 : 0,
            ethernetMode: ethernetMode,
            hotspotActive: hotspot != null,
            wifiConnected: network != null,
          ),
        ],
      ),
    );
  }

  /// The "Connection" card: address and status, the same in every mode. Always the
  /// last card, below the one of the current tab.
  Widget _buildConnectionCard(
    DeviceInfo deviceInfo, {
    required AppTheme theme,
    required int position,
    required bool ethernetMode,
    required bool hotspotActive,
    required bool wifiConnected,
  }) {
    final IconData statusIcon;
    final String status;
    final bool up;
    if (ethernetMode) {
      up = deviceInfo.ethernetCableConnected;
      statusIcon = up ? Icons.lan_rounded : Icons.lan_outlined;
      status = up ? 'Connected' : 'Not connected';
    } else if (hotspotActive) {
      up = true;
      statusIcon = Icons.router_rounded;
      status = 'Hotspot active';
    } else {
      up = wifiConnected;
      statusIcon = up ? Icons.wifi_rounded : Icons.wifi_off_rounded;
      status = up ? 'Connected' : 'Offline';
    }

    return _InfoCard(
      title: 'Connection',
      // The theme's blue while the connection is up, the neutral grey if not.
      accent: theme.tileColor(up ? TileColor.blue : TileColor.grey, position),
      children: [
        _InfoRow(
          icon: Icons.lan_rounded,
          label: 'IP Address',
          value: deviceInfo.ipAddress,
        ),
        _InfoRow(
          icon: Icons.memory_rounded,
          label: 'MAC Address',
          value: deviceInfo.macAddress ?? 'Unavailable',
        ),
        _InfoRow(icon: statusIcon, label: 'Status', value: status),
      ],
    );
  }

  /// Ethernet tab. First row is the mode: "Client" when the network gave the
  /// robot an address, "Host" when none answered and the robot serves DHCP.
  /// Null (no card) until the robot reports the mode.
  Widget? _buildEthernetCard(DeviceInfo deviceInfo, Color accent) {
    final role = deviceInfo.ethernetRole;
    if (role == null) return null;
    final host = role == 'host';

    return _InfoCard(
      title: 'Ethernet',
      accent: accent,
      children: [
        _InfoRow(
          icon: host ? Icons.dns_rounded : Icons.lan_rounded,
          label: 'Mode',
          value: host ? 'Host' : 'Client',
        ),
        if (host) ...[
          // Only the current number: the cable has no device limit.
          if (deviceInfo.ethernetConnectedDevices != null)
            _InfoRow(
              icon: Icons.devices_rounded,
              label: 'Connected devices',
              value: '${deviceInfo.ethernetConnectedDevices}',
            ),
        ],
      ],
    );
  }

  /// Details of the Wi-Fi network the robot is connected to (Client tab).
  Widget _buildWifiCard(WifiNetwork network, Color accent) {
    return _InfoCard(
      title: 'Wi-Fi',
      accent: accent,
      children: [
        _InfoRow(
          icon: Icons.router_rounded,
          label: 'SSID',
          value: network.ssid,
        ),
        _InfoRow(
          icon: Icons.lock_outline_rounded,
          label: 'Security',
          value: network.encryptionType.formatted,
        ),
      ],
    );
  }

  Widget _buildHotspotCard(
      AccessPointConfig config, int connectedClients, Color accent) {
    final hasPassword = config.encryptionType != WifiEncryptionType.open &&
        config.password.isNotEmpty;
    final band = config.channel > 0
        ? '${config.band.displayName} (channel ${config.channel})'
        : config.band.displayName;

    return _InfoCard(
      title: 'Hotspot',
      accent: accent,
      children: [
        _InfoRow(
          icon: Icons.router_rounded,
          label: 'Network name',
          value: config.ssid,
        ),
        _InfoRow(
          icon: Icons.key_rounded,
          label: 'Password',
          value: !hasPassword
              ? 'None'
              : _showHotspotPassword
                  ? config.password
                  : '\u2022' * 8,
          trailing: hasPassword
              ? IconButton(
                  tooltip:
                      _showHotspotPassword ? 'Hide password' : 'Show password',
                  icon: Icon(
                    _showHotspotPassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: Colors.white70,
                  ),
                  onPressed: () => setState(
                      () => _showHotspotPassword = !_showHotspotPassword),
                )
              : null,
        ),
        _InfoRow(
          icon: Icons.lock_outline_rounded,
          label: 'Security',
          value: config.encryptionType.formatted,
        ),
        _InfoRow(
          icon: Icons.network_wifi_rounded,
          label: 'Band',
          value: band,
        ),
        _InfoRow(
          icon: Icons.devices_rounded,
          label: 'Connected devices',
          // current/max: the hotspot has a configured limit.
          value: '$connectedClients/${config.maxClients}',
        ),
      ],
    );
  }
}

class _LoadingPanel extends ConsumerWidget {
  const _LoadingPanel({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(colorThemeProvider).tileColor(TileColor.blue, 0);

    return Container(
      width: 320,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF11161C),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, child) {
                return Transform.rotate(
                  angle: controller.value * 6.28318,
                  child: child,
                );
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accent.withValues(alpha: 0.16),
                        width: 4,
                      ),
                    ),
                  ),
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          accent.withValues(alpha: 0),
                          accent,
                          accent.withValues(alpha: 0),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                  const Icon(Icons.router_rounded,
                      color: Colors.white, size: 30),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Collecting network details',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Reading adapter state, IP information, and connection status.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.accent,
    required this.children,
  });

  final String title;
  final Color accent;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return _CardAccent(
      accent: accent,
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF11161C),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.32), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
      ),
    );
  }
}

/// Hands a card's accent color down to its rows.
class _CardAccent extends InheritedWidget {
  const _CardAccent({required this.accent, required super.child});

  final Color accent;

  static Color of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_CardAccent>()?.accent ??
      Colors.white;

  @override
  bool updateShouldNotify(_CardAccent old) => accent != old.accent;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final accent = _CardAccent.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF191215),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 42),
          const SizedBox(height: 14),
          const Text(
            'Could not load device information',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF11161C),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.devices_rounded, color: Colors.white, size: 40),
          const SizedBox(height: 14),
          const Text(
            'No device information yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
