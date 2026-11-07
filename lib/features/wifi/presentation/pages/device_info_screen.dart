import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/wifi/application/wifi_client_notifier.dart';
import 'package:stpvelox/features/wifi/application/wifi_provider.dart';
import 'package:stpvelox/features/wifi/domain/application/access_point_state.dart';
import 'package:stpvelox/features/wifi/domain/application/wifi_client_state.dart';
import 'package:stpvelox/features/wifi/domain/enities/access_point_config.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_band.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_encryption_type.dart';

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

    // Column in a SingleChildScrollView (not a lazy ListView) so all cards are
    // built up front and none pops in or out while scrolling.
    return SingleChildScrollView(
      key: const ValueKey('content'),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // In hotspot mode the hotspot is what matters, so it comes first.
          if (hotspot != null) ...[
            _buildHotspotCard(hotspot, apState.connectedClients),
            const SizedBox(height: 14),
          ],
          _InfoCard(
            title: 'Addressing',
            accent: const Color(0xFF4FC3F7),
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
            ],
          ),
          const SizedBox(height: 14),
          _InfoCard(
            title: 'Connection',
            accent: network != null
                ? const Color(0xFF81C784)
                : const Color(0xFFFFB74D),
            children: [
              _InfoRow(
                icon: network != null
                    ? Icons.wifi_rounded
                    : hotspot != null
                        ? Icons.router_rounded
                        : Icons.wifi_off_rounded,
                label: 'Status',
                value: network != null
                    ? 'Connected'
                    : hotspot != null
                        ? 'Hotspot active'
                        : 'Offline',
              ),
              if (network != null) ...[
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
              ] else if (hotspot == null)
                const _InfoHint(
                  text: 'No wireless network is currently connected.',
                ),
              if (deviceInfo.ethernetIpAddress != null)
                _InfoRow(
                  icon: Icons.cable_rounded,
                  label: 'Ethernet IP',
                  value: deviceInfo.ethernetIpAddress!,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHotspotCard(AccessPointConfig config, int connectedClients) {
    final hasPassword = config.encryptionType != WifiEncryptionType.open &&
        config.password.isNotEmpty;
    final band = config.channel > 0
        ? '${config.band.displayName} (channel ${config.channel})'
        : config.band.displayName;

    return _InfoCard(
      title: 'Hotspot',
      accent: const Color(0xFFBA68C8),
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
          value: '$connectedClients',
        ),
      ],
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF4FC3F7);

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
    return Container(
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
    );
  }
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
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

class _InfoHint extends StatelessWidget {
  const _InfoHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey[300],
          fontSize: 13,
          height: 1.35,
        ),
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
