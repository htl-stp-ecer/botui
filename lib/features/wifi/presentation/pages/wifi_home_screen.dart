import 'package:stpvelox/core/router/safe_navigation.dart';
import 'package:stpvelox/core/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/widgets/tile_position.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/wifi/application/network_mode_notifier.dart';
import 'package:stpvelox/features/wifi/domain/application/network_mode_state.dart';
import 'package:stpvelox/features/wifi/domain/enities/network_mode.dart';
import 'package:stpvelox/features/wifi/presentation/widgets/grid_tile.dart';
import 'package:stpvelox/application/theme/color_theme_provider.dart';
import 'package:stpvelox/core/theme/app_theme.dart';

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

      if (next.errorMessage != null) {
        AppToast.error(next.errorMessage!, duration: const Duration(seconds: 4));
        return;
      }

      if (previous?.mode != next.mode) {
        AppToast.success('Switched to ${_modeTitle(next.mode)}', duration: const Duration(seconds: 2));
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
                    // The tiles of every tab sit in the middle of the free
                    // space, horizontally and vertically.
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const gap = 12.0;
                        const columns = 3;
                        const aspectRatio = 1.28;
                        // Size of a tile in a full row of three; fewer tiles
                        // keep this size and are centered.
                        var width = (constraints.maxWidth - (columns - 1) * gap) /
                            columns;
                        if (width / aspectRatio > constraints.maxHeight) {
                          width = constraints.maxHeight * aspectRatio;
                        }
                        return Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            runAlignment: WrapAlignment.center,
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              for (final (i, action) in actions.indexed)
                                SizedBox(
                                  width: width,
                                  height: width / aspectRatio,
                                  child: TilePosition(
                                    index: i,
                                    child: ResponsiveGridTile(
                                      label: action.title,
                                      icon: action.icon,
                                      color: action.color,
                                      onPressed: () =>
                                          context.pushOnce(action.route),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
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

class _ModeButton extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    // Same slot and position logic as the tiles, so every theme applies.
    final accent = ref
        .watch(colorThemeProvider)
        .tileColor(_modeSlot(mode), NetworkMode.values.indexOf(mode));

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
  final TileColor color;
  final String route;
}

List<_WifiAction> _actionsForMode(NetworkMode mode) {
  switch (mode) {
    case NetworkMode.client:
      return const [
        _WifiAction(
          title: 'Scan Networks',
          icon: Icons.wifi_find,
          color: TileColor.teal,
          route: AppRoutes.wifiScan,
        ),
        _WifiAction(
          title: 'Saved Networks',
          icon: Icons.bookmarks_rounded,
          color: TileColor.green,
          route: AppRoutes.wifiSavedNetworks,
        ),
        _WifiAction(
          title: 'Device Info',
          icon: Icons.info_outline,
          color: TileColor.blueGrey,
          route: AppRoutes.wifiDeviceInfo,
        ),
      ];
    case NetworkMode.accessPoint:
      return const [
        _WifiAction(
          title: 'Hotspot Settings',
          icon: Icons.router_rounded,
          color: TileColor.purple,
          route: AppRoutes.wifiAccessPointConfig,
        ),
        _WifiAction(
          title: 'Device Info',
          icon: Icons.info_outline,
          color: TileColor.blueGrey,
          route: AppRoutes.wifiDeviceInfo,
        ),
      ];
    case NetworkMode.lanOnly:
      return const [
        _WifiAction(
          title: 'Device Info',
          icon: Icons.info_outline,
          color: TileColor.blueGrey,
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
      return 'Ethernet Mode';
  }
}

String _modeButtonLabel(NetworkMode mode) {
  switch (mode) {
    case NetworkMode.client:
      return 'Client';
    case NetworkMode.accessPoint:
      return 'Hotspot';
    case NetworkMode.lanOnly:
      return 'Ethernet';
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

TileColor _modeSlot(NetworkMode mode) {
  switch (mode) {
    case NetworkMode.client:
      return TileColor.teal;
    case NetworkMode.accessPoint:
      return TileColor.purple;
    case NetworkMode.lanOnly:
      return TileColor.brown;
  }
}
