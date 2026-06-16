import 'package:flutter/material.dart';

import 'package:stpvelox/core/widgets/top_bar.dart';

/// Platzhalter für die BNO-Fusion-Anzeige.  Wird der Tile auf dem
/// Hauptscreen sowieso als "not connected" gerendert; falls der User
/// trotzdem hier landet, bekommt er eine klare Erklärung.
class CalibBnoScreen extends StatelessWidget {
  const CalibBnoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: createTopBar(context, 'BNO08x — Sensor Fusion'),
      backgroundColor: Colors.black87,
      body: const SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.orangeAccent, size: 96),
                SizedBox(height: 16),
                Text('BNO08x not available',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600)),
                SizedBox(height: 12),
                Text(
                  'Chip is dead, firmware module disabled.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
