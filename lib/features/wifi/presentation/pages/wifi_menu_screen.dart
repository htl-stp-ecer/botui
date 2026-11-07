import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/widgets/tile_position.dart';
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
          // Two tiles, 0.75x the size they had in the grid, centered on both axes.
          child: LayoutBuilder(
            builder: (context, constraints) {
              const gap = 12.0;
              const aspectRatio = 1.12;
              const scale = 0.75;
              // The size a tile had when the two filled the row.
              var width = (constraints.maxWidth - gap) / 2;
              if (width / aspectRatio > constraints.maxHeight) {
                width = constraints.maxHeight * aspectRatio;
              }
              width *= scale;
              const tiles = [
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
              ];
              return Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  runAlignment: WrapAlignment.center,
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final (i, tile) in tiles.indexed)
                      SizedBox(
                        width: width,
                        height: width / aspectRatio,
                        child: TilePosition(index: i, child: tile),
                      ),
                  ],
                ),
              );
            },
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
