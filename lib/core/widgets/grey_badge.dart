import 'package:flutter/material.dart';

/// Small grey monospace badge (e.g. the `~/screenshots/` path in a top bar).
class GreyBadge extends StatelessWidget {
  final String text;

  const GreyBadge(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white60,
          fontSize: 14,
          fontFamily: 'DejaVu Sans Mono',
        ),
      ),
    );
  }
}
