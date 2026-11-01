import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/application/theme/color_theme_provider.dart';
import 'package:stpvelox/core/theme/app_theme.dart';
import 'package:stpvelox/core/widgets/tile_position.dart';

import 'package:stpvelox/features/calib_board/domain/entities/calib_board_status.dart';

/// Tile-Variante mit Disabled-Status.  Mirrort die Optik von
/// [ResponsiveGridTile] aus dem Wifi-Modul, aber rendert grau wenn nicht
/// verfügbar und schaltet den Tap-Handler ab.
class CalibStatusTile extends ConsumerWidget {
  final String label;
  final IconData icon;
  final TileColor color;
  final CalibSensorState state;
  final VoidCallback onPressed;

  /// Optionaler Detail-Text der unter dem Label angezeigt wird
  /// (z. B. "init_failed:id_or_who_am_i_mismatch").
  final String? detail;

  const CalibStatusTile({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.state,
    required this.onPressed,
    this.detail,
  });

  bool get _enabled => state == CalibSensorState.ok;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(colorThemeProvider);
    final themed = theme.tileColor(color, TilePosition.maybeOf(context));
    final tileColor = _enabled ? themed : Colors.grey.shade800;
    final fg       = _enabled ? theme.textColor : Colors.white60;

    return Opacity(
      opacity: _enabled ? 1.0 : 0.55,
      child: GestureDetector(
        onTap: _enabled ? onPressed : null,
        child: Container(
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: fg, size: 80),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(color: fg, fontSize: 18, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                _statusLabel(),
                style: TextStyle(color: fg, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              if (detail != null && detail!.isNotEmpty && !_enabled) ...[
                const SizedBox(height: 2),
                Text(
                  detail!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: fg, fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel() {
    switch (state) {
      case CalibSensorState.ok:
        return 'available';
      case CalibSensorState.unavailable:
        return 'not connected';
      case CalibSensorState.unknown:
        return 'waiting…';
    }
  }
}
