import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stpvelox/core/router/app_router.dart';
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
              color: Colors.green[600]!,
              onPressed: () => context.push(AppRoutes.wifi),
            ),
            ResponsiveGridTile(
              icon: Icons.videocam,
              label: 'Camera',
              color: Colors.blue[600]!,
              onPressed: () => context.push(AppRoutes.camera),
            ),
            ResponsiveGridTile(
              icon: Icons.display_settings,
              label: 'Display',
              color: Colors.purple[600]!,
              onPressed: () => context.push(AppRoutes.displaySettings),
            ),
            ResponsiveGridTile(
              icon: Icons.tune,
              label: 'System',
              color: Colors.orange[600]!,
              onPressed: () => context.push(AppRoutes.systemSettings),
            ),
            ResponsiveGridTile(
              icon: Icons.info_outline,
              label: 'App Status',
              color: Colors.teal[600]!,
              onPressed: () => context.push(AppRoutes.appStatus),
            ),
            ResponsiveGridTile(
              icon: Icons.emoji_emotions,
              label: 'Robot',
              color: Colors.pink[600]!,
              onPressed: () => context.push(AppRoutes.personality),
            ),
          ],
        ),
      ),
    );
  }
}
