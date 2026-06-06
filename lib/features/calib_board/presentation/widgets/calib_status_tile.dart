import 'package:flutter/material.dart';

import 'package:stpvelox/features/calib_board/domain/entities/calib_board_status.dart';

/// Tile-Variante mit Disabled-Status.  Mirrort die Optik von
/// [ResponsiveGridTile] aus dem Wifi-Modul, aber rendert grau wenn nicht
/// verfügbar und schaltet den Tap-Handler ab.
class CalibStatusTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
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
  Widget build(BuildContext context) {
    final tileColor = _enabled ? color : Colors.grey.shade800;
    final fg       = _enabled ? Colors.white : Colors.white60;

    return Opacity(
      opacity: _enabled ? 1.0 : 0.55,
      child: GestureDetector(
        onTap: _enabled ? onPressed : null,
        child: Container(
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(8.0),
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
