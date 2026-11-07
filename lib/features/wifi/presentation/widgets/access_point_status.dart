import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/application/theme/color_theme_provider.dart';
import 'package:stpvelox/core/theme/app_theme.dart';
import 'package:stpvelox/features/wifi/domain/enities/access_point_config.dart';

/// Compact hotspot state card for the settings screen. The full details
/// (password, security, band, devices) are on the Device Information page.
class AccessPointStatus extends ConsumerWidget {
  final bool isStarted;
  final AccessPointConfig? config;
  final String? ipAddress;
  final int connectedClients;

  const AccessPointStatus({
    super.key,
    required this.isStarted,
    this.config,
    this.ipAddress,
    this.connectedClients = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The theme's purple while the hotspot runs, the neutral grey otherwise.
    final theme = ref.watch(colorThemeProvider);
    final accent = theme.tileColor(isStarted ? TileColor.purple : TileColor.grey, 0);
    final details = <String>[
      if (isStarted && config != null) config!.ssid,
      if (isStarted && ipAddress != null) ipAddress!,
      if (isStarted)
        '$connectedClients device${connectedClients == 1 ? '' : 's'}',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF11161C),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.32), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isStarted ? Icons.router_rounded : Icons.router_outlined,
              color: accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isStarted ? 'Hotspot active' : 'Hotspot inactive',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    details.join('  ·  '),
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
