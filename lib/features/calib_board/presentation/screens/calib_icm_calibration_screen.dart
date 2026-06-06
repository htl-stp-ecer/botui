import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/calib_board/application/calib_board_providers.dart';

/// ICM Gyro-Bias Calibration.
///
/// Das Firmware-Modul `imu_fusion` detektiert "at rest" automatisch
/// (Gyro-Magnitude < 1.5 dps + |Accel| ≈ 1 g für ≥ 800 ms) und lernt
/// dann den Bias per EMA (Lernrate α=0.001 bei 1 kHz Sample-Rate, also
/// effektive Zeitkonstante ~1 s).  Diese Seite zeigt das live an und
/// erlaubt es, den frischen Bias dauerhaft in den STM32-Flash zu
/// schreiben.
///
/// Workflow:
///   1. Board auf glatter, vibrationsfreier Fläche ablegen
///   2. "AT REST" Indikator wartet bis grün
///   3. 5–10 s warten, Bias-Werte unten zappeln und stabilisieren sich
///   4. "Save to flash" — der aktuelle EMA-Wert wird ins Flash
///      geschrieben und beim nächsten Boot direkt geladen
class CalibIcmCalibrationScreen extends ConsumerWidget {
  const CalibIcmCalibrationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final atRest        = ref.watch(calibIcmAtRestProvider).value ?? false;
    final biasPersisted = ref.watch(calibIcmBiasPersistedProvider).value ?? false;
    final bias          = ref.watch(calibIcmGyroBiasProvider).value;

    return Scaffold(
      appBar: createTopBar(context, 'ICM Gyro Calibration'),
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Place the board on a stable surface.  The firmware will '
                'detect "at rest" automatically and learn the gyro bias.  '
                'Press Save once the values have stabilised.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 14),
              _AtRestBanner(atRest: atRest),
              const SizedBox(height: 10),
              _BiasCard(
                bx: bias?.x ?? 0,
                by: bias?.y ?? 0,
                bz: bias?.z ?? 0,
                persisted: biasPersisted,
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ref.read(calibCommandPublisherProvider).sendResetGyroBias();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Gyro bias reset to 0 (RAM only).')),
                        );
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset (RAM)'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: !atRest
                          ? null
                          : () {
                              ref
                                  .read(calibCommandPublisherProvider)
                                  .sendSaveGyroBias();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Save sent — FW will persist and confirm.')),
                              );
                            },
                      icon: const Icon(Icons.save),
                      label: const Text('Save to flash'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AtRestBanner extends StatelessWidget {
  final bool atRest;
  const _AtRestBanner({required this.atRest});

  @override
  Widget build(BuildContext context) {
    final color = atRest ? const Color(0xFF66BB6A) : const Color(0xFFFFA726);
    final label = atRest ? 'AT REST' : 'MOVING';
    final hint = atRest
        ? 'Bias EMA is converging — wait a few seconds for stability'
        : 'Place the board on a stable surface and wait';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        children: [
          Container(
            width: 14, height: 14,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(hint,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _BiasCard extends StatelessWidget {
  final double bx, by, bz;
  final bool persisted;
  const _BiasCard(
      {required this.bx, required this.by, required this.bz, required this.persisted});

  String _fmt(double v) {
    final s = v.toStringAsFixed(4);
    return v >= 0 ? '+$s' : s;
  }

  @override
  Widget build(BuildContext context) {
    Widget axis(String l, double v, Color color) {
      return Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(6),
            border: Border(left: BorderSide(color: color, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 2),
              Text(_fmt(v),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600)),
              const Text('dps',
                  style: TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 4, bottom: 6),
          child: Row(
            children: [
              const Text('Live gyro bias (EMA)',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const Spacer(),
              Icon(
                persisted ? Icons.check_circle : Icons.warning_amber_rounded,
                size: 14,
                color: persisted
                    ? const Color(0xFF66BB6A)
                    : const Color(0xFFFFA726),
              ),
              const SizedBox(width: 4),
              Text(persisted ? 'persisted in flash' : 'not saved',
                  style: TextStyle(
                      color: persisted
                          ? const Color(0xFF66BB6A)
                          : const Color(0xFFFFA726),
                      fontSize: 11)),
            ],
          ),
        ),
        Row(
          children: [
            axis('X', bx, const Color(0xFFEF5350)),
            axis('Y', by, const Color(0xFF66BB6A)),
            axis('Z', bz, const Color(0xFF42A5F5)),
          ],
        ),
      ],
    );
  }
}
