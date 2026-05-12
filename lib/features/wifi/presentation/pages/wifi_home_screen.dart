import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/widgets/responsive_grid.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/wifi/application/network_mode_notifier.dart';
import 'package:stpvelox/features/wifi/domain/application/network_mode_state.dart';
import 'package:stpvelox/features/wifi/domain/enities/network_mode.dart';
import 'package:stpvelox/features/wifi/presentation/widgets/grid_tile.dart';

class WifiHomeScreen extends ConsumerStatefulWidget {
  const WifiHomeScreen({super.key});

  @override
  ConsumerState<WifiHomeScreen> createState() => _WifiHomeScreenState();
}

class _WifiHomeScreenState extends ConsumerState<WifiHomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(networkModeProvider.notifier).loadNetworkMode();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<NetworkModeState>(networkModeProvider, (previous, next) {
      if (previous?.isLoading != true || next.isLoading) {
        return;
      }

      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();

      if (next.errorMessage != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.red[700],
          ),
        );
        return;
      }

      if (previous?.mode != next.mode) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Switched to ${_modeTitle(next.mode)}'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green[700],
          ),
        );
      }
    });

    final state = ref.watch(networkModeProvider);
    final currentMode = state.mode;
    final actions = _actionsForMode(currentMode);

    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: createTopBar(context, 'Network'),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 134,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF11161C),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _modeTitle(currentMode),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: _ModeStrip(
                              currentMode: currentMode,
                              isLoading: state.isLoading,
                              onModeSelected:
                                  _onModeSelected(state, currentMode),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ResponsiveGrid(
                      isScrollable: false,
                      crossAxisCount: 3,
                      maxTileWidth: 220,
                      childAspectRatio: 1.28,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      padding: EdgeInsets.zero,
                      children: [
                        for (final action in actions)
                          ResponsiveGridTile(
                            label: action.title,
                            icon: action.icon,
                            color: action.color,
                            onPressed: () => context.push(action.route),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (state.isLoading)
              const Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Color(0x66000000)),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  ValueChanged<NetworkMode> _onModeSelected(
    NetworkModeState state,
    NetworkMode currentMode,
  ) {
    return (mode) {
      if (mode == currentMode || state.isLoading) {
        return;
      }
      ref.read(networkModeProvider.notifier).updateNetworkMode(mode);
    };
  }
}

class _ModeStrip extends StatelessWidget {
  const _ModeStrip({
    required this.currentMode,
    required this.isLoading,
    required this.onModeSelected,
  });

  final NetworkMode currentMode;
  final bool isLoading;
  final ValueChanged<NetworkMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final mode in NetworkMode.values) ...[
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: mode == NetworkMode.values.last ? 0 : 10,
              ),
              child: _ModeButton(
                mode: mode,
                isSelected: mode == currentMode,
                isEnabled: !isLoading,
                onTap: () => onModeSelected(mode),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.mode,
    required this.isSelected,
    required this.isEnabled,
    required this.onTap,
  });

  final NetworkMode mode;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _modeAccent(mode);

    return Opacity(
      opacity: isEnabled ? 1 : 0.65,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              color: isSelected
                  ? accent.withValues(alpha: 0.22)
                  : const Color(0xFF1A212A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color:
                    isSelected ? accent : Colors.white.withValues(alpha: 0.08),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_modeIcon(mode), color: accent, size: 28),
                  const SizedBox(height: 6),
                  Text(
                    _modeButtonLabel(mode),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WifiAction {
  const _WifiAction({
    required this.title,
    required this.icon,
    required this.color,
    required this.route,
  });

  final String title;
  final IconData icon;
  final Color color;
  final String route;
}

List<_WifiAction> _actionsForMode(NetworkMode mode) {
  switch (mode) {
    case NetworkMode.client:
      return const [
        _WifiAction(
          title: 'Scan Networks',
          icon: Icons.wifi_find,
          color: Color(0xFF00897B),
          route: AppRoutes.wifiScan,
        ),
        _WifiAction(
          title: 'Saved Networks',
          icon: Icons.bookmarks_rounded,
          color: Color(0xFF43A047),
          route: AppRoutes.wifiSavedNetworks,
        ),
        _WifiAction(
          title: 'Device Info',
          icon: Icons.info_outline,
          color: Color(0xFF546E7A),
          route: AppRoutes.wifiDeviceInfo,
        ),
      ];
    case NetworkMode.accessPoint:
      return const [
        _WifiAction(
          title: 'Hotspot Settings',
          icon: Icons.router_rounded,
          color: Color(0xFF8E24AA),
          route: AppRoutes.wifiAccessPointConfig,
        ),
        _WifiAction(
          title: 'Network Status',
          icon: Icons.network_check_rounded,
          color: Color(0xFFFB8C00),
          route: AppRoutes.wifiAccessPointStatus,
        ),
        _WifiAction(
          title: 'Device Info',
          icon: Icons.info_outline,
          color: Color(0xFF546E7A),
          route: AppRoutes.wifiDeviceInfo,
        ),
      ];
    case NetworkMode.lanOnly:
      return const [
        _WifiAction(
          title: 'LAN Status',
          icon: Icons.cable_rounded,
          color: Color(0xFF6D4C41),
          route: AppRoutes.wifiLanStatus,
        ),
        _WifiAction(
          title: 'Device Info',
          icon: Icons.info_outline,
          color: Color(0xFF546E7A),
          route: AppRoutes.wifiDeviceInfo,
        ),
      ];
  }
}

String _modeTitle(NetworkMode mode) {
  switch (mode) {
    case NetworkMode.client:
      return 'Wi-Fi Client Mode';
    case NetworkMode.accessPoint:
      return 'Hotspot Mode';
    case NetworkMode.lanOnly:
      return 'LAN Only Mode';
  }
}

String _modeButtonLabel(NetworkMode mode) {
  switch (mode) {
    case NetworkMode.client:
      return 'Client';
    case NetworkMode.accessPoint:
      return 'Hotspot';
    case NetworkMode.lanOnly:
      return 'LAN Only';
  }
}

IconData _modeIcon(NetworkMode mode) {
  switch (mode) {
    case NetworkMode.client:
      return Icons.wifi_rounded;
    case NetworkMode.accessPoint:
      return Icons.router_rounded;
    case NetworkMode.lanOnly:
      return Icons.cable_rounded;
  }
}

Color _modeAccent(NetworkMode mode) {
  switch (mode) {
    case NetworkMode.client:
      return const Color(0xFF26A69A);
    case NetworkMode.accessPoint:
      return const Color(0xFFAB47BC);
    case NetworkMode.lanOnly:
      return const Color(0xFF8D6E63);
  }
}
