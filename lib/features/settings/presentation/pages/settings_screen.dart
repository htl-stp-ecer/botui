import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/theme/app_theme.dart';
import 'package:stpvelox/core/widgets/responsive_grid.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/wifi/presentation/widgets/grid_tile.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: createTopBar(context, 'Settings'),
      body: SafeArea(
        child: ResponsiveGrid(
          children: [
            ResponsiveGridTile(
              icon: Icons.wifi,
              label: 'Network',
              color: TileColor.green,
              onPressed: () => context.push(AppRoutes.wifi),
            ),
            ResponsiveGridTile(
              icon: Icons.tune,
              label: 'System',
              color: TileColor.orange,
              onPressed: () => context.push(AppRoutes.systemSettings),
            ),
            ResponsiveGridTile(
              icon: Icons.display_settings,
              label: 'Display',
              color: TileColor.purple,
              onPressed: () => context.push(AppRoutes.displaySettings),
            ),
            ResponsiveGridTile(
              icon: Icons.emoji_emotions,
              label: 'Personality',
              color: TileColor.pink,
              onPressed: () => context.push(AppRoutes.personality),
            ),
            ResponsiveGridTile(
              icon: Icons.info_outline,
              label: 'Versions',
              color: TileColor.teal,
              onPressed: () => context.push(AppRoutes.appStatus),
            ),
            ResponsiveGridTile(
              icon: Icons.analytics_outlined,
              label: 'Services',
              color: TileColor.indigo,
              onPressed: () => context.push(AppRoutes.serviceStatus),
            ),
          ],
        ),
      ),
    );
  }
}
