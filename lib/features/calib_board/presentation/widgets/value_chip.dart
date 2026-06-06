import 'package:flutter/material.dart';

/// Kleiner Status-Chip — Label oben, Wert mittig (monospace), optionaler
/// Sub-Text unten.  Wird in den Calib-Detail-Screens als Live-Anzeige
/// für Skalar/Achsenwerte verwendet.
class ValueChip extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color? accent;

  const ValueChip({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(6),
          border: accent != null
              ? Border(left: BorderSide(color: accent!, width: 3))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600)),
            if (sub != null) ...[
              const SizedBox(height: 2),
              Text(sub!,
                  style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ],
        ),
      ),
    );
  }
}
