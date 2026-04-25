import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: createTopBar(context, 'Settings'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _CategoryTile(
                icon: Icons.wifi,
                label: 'Network',
                subtitle: 'Wi-Fi',
                color: Colors.green,
                onTap: () => context.push(AppRoutes.wifi),
              ),
              _CategoryTile(
                icon: Icons.videocam,
                label: 'Camera',
                subtitle: 'Live view',
                color: Colors.blue,
                onTap: () => context.push(AppRoutes.camera),
              ),
              _CategoryTile(
                icon: Icons.display_settings,
                label: 'Display',
                subtitle: 'Rotate, Calibrate, Screensaver',
                color: Colors.purple,
                onTap: () => context.push(AppRoutes.displaySettings),
              ),
              _CategoryTile(
                icon: Icons.tune,
                label: 'System',
                subtitle: 'Shutdown, Reboot, Services',
                color: Colors.orange,
                onTap: () => context.push(AppRoutes.systemSettings),
              ),
              _CategoryTile(
                icon: Icons.info_outline,
                label: 'App Status',
                subtitle: 'Versions',
                color: Colors.tealAccent,
                onTap: () => context.push(AppRoutes.appStatus),
              ),
              _CategoryTile(
                icon: Icons.emoji_emotions,
                label: 'Robot',
                subtitle: 'Personality',
                color: Colors.pinkAccent,
                onTap: () => context.push(AppRoutes.personality),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey[850],
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[600], size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
