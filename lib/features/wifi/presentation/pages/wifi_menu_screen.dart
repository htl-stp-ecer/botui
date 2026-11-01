import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/widgets/responsive_grid.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/wifi/presentation/widgets/grid_tile.dart';
import 'package:stpvelox/core/theme/app_theme.dart';

class WifiMenuScreen extends StatelessWidget {
  const WifiMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: createTopBar(context, 'Network'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ResponsiveGrid(
            isScrollable: false,
            crossAxisCount: 2,
            maxTileWidth: 260,
            childAspectRatio: 1.12,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            padding: EdgeInsets.zero,
            children: const [
              _WifiMenuTile(
                title: 'Manage Connection',
                icon: Icons.settings_ethernet_rounded,
                color: TileColor.teal,
                route: AppRoutes.wifiManage,
              ),
              _WifiMenuTile(
                title: 'Network Scan',
                icon: Icons.wifi_tethering_rounded,
                color: TileColor.blue,
                route: AppRoutes.wifiChannelScan,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WifiMenuTile extends StatelessWidget {
  const _WifiMenuTile({
    required this.title,
    required this.icon,
    required this.color,
    required this.route,
  });

  final String title;
  final IconData icon;
  final TileColor color;
  final String route;

  @override
  Widget build(BuildContext context) {
    return ResponsiveGridTile(
      label: title,
      icon: icon,
      color: color,
      onPressed: () => context.push(route),
    );
  }
}
