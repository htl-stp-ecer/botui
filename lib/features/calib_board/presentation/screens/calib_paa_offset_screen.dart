import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:raccoon_transport/messages/types/scalar_f_t.g.dart';

import 'package:stpvelox/core/transport/domain/providers.dart';
import 'package:stpvelox/core/transport/domain/services/transport_service.dart'
    show kUiSensorSampleRate;
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/calib_board/application/calib_board_providers.dart';
import 'package:stpvelox/features/calib_board/domain/calib_channels.dart';
import 'package:stpvelox/features/dynamic_ui/presentation/widgets/numeric_keypad_widget.dart';

/// PAA-Montageoffset konfigurieren.  Der PAA sitzt nicht im Drehzentrum des
/// Roboters; bei Rotation registriert er dadurch einen Schein-Versatz
/// (ω×r).  Hier gibt der Nutzer den X/Y-Offset (mm vom Drehzentrum, Body-
/// Frame) per Bildschirm-Tastatur ein, schreibt ihn ins Flash und prüft
/// anschließend per In-Place-Drehung ob die Odometrie jetzt stehen bleibt.
class CalibPaaOffsetScreen extends ConsumerStatefulWidget {
  const CalibPaaOffsetScreen({super.key});

  @override
  ConsumerState<CalibPaaOffsetScreen> createState() =>
      _CalibPaaOffsetScreenState();
}

enum _Step { edit, saving, verify }

enum _Field { x, y }

class _CalibPaaOffsetScreenState extends ConsumerState<CalibPaaOffsetScreen> {
  static const double _saveMatchTolMm = 0.05;

  // ── Verifikation ──
  // Gilt als bestanden, wenn nach genügend Drehung der Restversatz der
  // Odometrie-Position unter dieser Schwelle bleibt.
  static const double _passToleranceCm = 2.0;
  static const double _targetRotationDeg = 360.0;

  _Step _step = _Step.edit;

  // Eingabe-Puffer.  Text + Vorzeichen je Feld; aktives Feld kriegt die
  // Keypad-Eingaben.
  String _xText = '0';
  String _yText = '0';
  bool _xNeg = false;
  bool _yNeg = false;
  _Field _active = _Field.x;
  bool _prefilled = false;

  // Vom Board zuletzt bestätigte Offsets (mm) — Save wartet darauf.
  double? _pendingX;
  double? _pendingY;

  // ── Verifikations-Live-State ──
  StreamSubscription<dynamic>? _posXSub;
  StreamSubscription<dynamic>? _posYSub;
  StreamSubscription<dynamic>? _headingSub;
  double _posX = 0, _posY = 0;
  double _maxResidualCm = 0;
  double _turnedDeg = 0; // akkumulierte |Δheading|
  double? _lastHeading;
  bool _testRunning = false;

  double get _xValue => (_xNeg ? -1 : 1) * (double.tryParse(_xText) ?? 0);
  double get _yValue => (_yNeg ? -1 : 1) * (double.tryParse(_yText) ?? 0);

  @override
  void dispose() {
    _posXSub?.cancel();
    _posYSub?.cancel();
    _headingSub?.cancel();
    super.dispose();
  }

  void _prefillFromBoard() {
    if (_prefilled) return;
    final ox = ref.read(calibPaaCalOffXProvider).value;
    final oy = ref.read(calibPaaCalOffYProvider).value;
    if (ox == null || oy == null) return;
    _prefilled = true;
    setState(() {
      _xNeg = ox < 0;
      _yNeg = oy < 0;
      _xText = ox.abs().toStringAsFixed(1);
      _yText = oy.abs().toStringAsFixed(1);
    });
  }

  // ── Eingabe ──
  void _onKey(String key) {
    setState(() {
      final cur = _active == _Field.x ? _xText : _yText;
      String next = cur;
      if (key == 'back') {
        next = cur.isNotEmpty ? cur.substring(0, cur.length - 1) : '';
        if (next.isEmpty) next = '0';
      } else if (key == '.') {
        if (!cur.contains('.')) next = (cur == '0' ? '0.' : '$cur.');
      } else {
        // Ziffer.  Führende 0 ersetzen (außer bei "0.").
        if (cur == '0') {
          next = key;
        } else if (cur.length < 6) {
          next = cur + key;
        }
      }
      if (_active == _Field.x) {
        _xText = next;
      } else {
        _yText = next;
      }
    });
  }

  void _toggleSign() {
    setState(() {
      if (_active == _Field.x) {
        _xNeg = !_xNeg;
      } else {
        _yNeg = !_yNeg;
      }
    });
  }

  void _save() {
    _pendingX = _xValue;
    _pendingY = _yValue;
    ref.read(calibCommandPublisherProvider).sendSetOffset(
          offXmm: _pendingX!,
          offYmm: _pendingY!,
        );
    setState(() => _step = _Step.saving);
  }

  bool _near(double? a, double? b) =>
      a != null && b != null && (a - b).abs() <= _saveMatchTolMm;

  // ── Verifikation ──
  void _ensureVerifySubs() {
    if (_posXSub != null) return;
    final t = ref.read(transportServiceProvider);
    _posXSub = t
        .subscribeAs<ScalarFT>(CalibChannels.odomPosX, ScalarFT.decode,
            throttle: kUiSensorSampleRate)
        .listen((d) => _onPos(x: d.value.value));
    _posYSub = t
        .subscribeAs<ScalarFT>(CalibChannels.odomPosY, ScalarFT.decode,
            throttle: kUiSensorSampleRate)
        .listen((d) => _onPos(y: d.value.value));
    _headingSub = t
        .subscribeAs<ScalarFT>(CalibChannels.odomHeading, ScalarFT.decode,
            throttle: kUiSensorSampleRate)
        .listen((d) => _onHeading(d.value.value));
  }

  void _onPos({double? x, double? y}) {
    if (!mounted) return;
    setState(() {
      if (x != null) _posX = x;
      if (y != null) _posY = y;
      if (_testRunning) {
        final r = math.sqrt(_posX * _posX + _posY * _posY);
        if (r > _maxResidualCm) _maxResidualCm = r;
      }
    });
  }

  void _onHeading(double headingDeg) {
    if (!mounted) return;
    setState(() {
      if (_testRunning && _lastHeading != null) {
        var d = headingDeg - _lastHeading!;
        while (d > 180) {
          d -= 360;
        }
        while (d < -180) {
          d += 360;
        }
        _turnedDeg += d.abs();
      }
      _lastHeading = headingDeg;
    });
  }

  void _startTest() {
    _ensureVerifySubs();
    ref.read(calibCommandPublisherProvider).sendOdomReset();
    setState(() {
      _testRunning = true;
      _maxResidualCm = 0;
      _turnedDeg = 0;
      _lastHeading = null;
      _posX = 0;
      _posY = 0;
    });
  }

  void _stopTest() => setState(() => _testRunning = false);

  @override
  Widget build(BuildContext context) {
    final cx = ref.watch(calibPaaCalOffXProvider).value;
    final cy = ref.watch(calibPaaCalOffYProvider).value;

    // Beim ersten Mal die Felder mit dem Board-Wert vorbelegen.
    if (!_prefilled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _prefillFromBoard();
      });
    }

    // Flash-Bestätigung abwarten: Board meldet die erwarteten Werte zurück.
    if (_step == _Step.saving && _near(cx, _pendingX) && _near(cy, _pendingY)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _step == _Step.saving) {
          setState(() => _step = _Step.verify);
        }
      });
    }

    return Scaffold(
      appBar: createTopBar(context, 'PAA Offset'),
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: _content(cx, cy),
        ),
      ),
    );
  }

  Widget _content(double? boardX, double? boardY) {
    switch (_step) {
      case _Step.edit:
        return _EditStep(
          xText: _xText,
          yText: _yText,
          xNeg: _xNeg,
          yNeg: _yNeg,
          active: _active,
          boardX: boardX,
          boardY: boardY,
          onSelect: (f) => setState(() => _active = f),
          onKey: _onKey,
          onToggleSign: _toggleSign,
          onSave: _save,
        );
      case _Step.saving:
        return const _SavingStep();
      case _Step.verify:
        return _VerifyStep(
          offX: _pendingX ?? boardX ?? 0,
          offY: _pendingY ?? boardY ?? 0,
          running: _testRunning,
          posX: _posX,
          posY: _posY,
          residualCm: math.sqrt(_posX * _posX + _posY * _posY),
          maxResidualCm: _maxResidualCm,
          turnedDeg: _turnedDeg,
          targetDeg: _targetRotationDeg,
          tolCm: _passToleranceCm,
          onStart: _startTest,
          onStop: _stopTest,
          onBackToEdit: () => setState(() => _step = _Step.edit),
        );
    }
  }
}

// ── Schritt 1: Eingabe ────────────────────────────────────────────────────

class _EditStep extends StatelessWidget {
  const _EditStep({
    required this.xText,
    required this.yText,
    required this.xNeg,
    required this.yNeg,
    required this.active,
    required this.boardX,
    required this.boardY,
    required this.onSelect,
    required this.onKey,
    required this.onToggleSign,
    required this.onSave,
  });

  final String xText;
  final String yText;
  final bool xNeg;
  final bool yNeg;
  final _Field active;
  final double? boardX;
  final double? boardY;
  final ValueChanged<_Field> onSelect;
  final ValueChanged<String> onKey;
  final VoidCallback onToggleSign;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Linke Spalte: Felder + Save.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Offset of the PAA sensor from the rotation centre',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 10),
              _FieldTile(
                label: 'X offset',
                value: (xNeg ? '-' : '') + xText,
                unit: 'mm',
                selected: active == _Field.x,
                onTap: () => onSelect(_Field.x),
              ),
              const SizedBox(height: 8),
              _FieldTile(
                label: 'Y offset',
                value: (yNeg ? '-' : '') + yText,
                unit: 'mm',
                selected: active == _Field.y,
                onTap: () => onSelect(_Field.y),
              ),
              const Spacer(),
              if (boardX != null && boardY != null)
                Text(
                  'On board: ${boardX!.toStringAsFixed(1)} · ${boardY!.toStringAsFixed(1)} mm',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12, fontFamily: 'monospace'),
                ),
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.save),
                  label: const Text('Save to flash', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Rechte Spalte: Keypad + Vorzeichen.
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            NumericKeypadWidget(onKeyPress: onKey),
            const SizedBox(height: 4),
            SizedBox(
              width: 232,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: onToggleSign,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                ),
                icon: const Icon(Icons.swap_vert),
                label: const Text('±  toggle sign'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FieldTile extends StatelessWidget {
  const _FieldTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final String unit;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = selected ? const Color(0xFF42A5F5) : Colors.white24;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border, width: selected ? 2.5 : 1),
        ),
        child: Row(
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 15)),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Text(unit,
                style: const TextStyle(color: Colors.white38, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ── Schritt 2: Saving ──────────────────────────────────────────────────────

class _SavingStep extends StatelessWidget {
  const _SavingStep();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
              width: 40, height: 40,
              child: CircularProgressIndicator(strokeWidth: 3)),
          SizedBox(height: 20),
          Text('Writing to flash…',
              style: TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
    );
  }
}

// ── Schritt 3: Verifikation (In-Place-Drehung) ─────────────────────────────

class _VerifyStep extends StatelessWidget {
  const _VerifyStep({
    required this.offX,
    required this.offY,
    required this.running,
    required this.posX,
    required this.posY,
    required this.residualCm,
    required this.maxResidualCm,
    required this.turnedDeg,
    required this.targetDeg,
    required this.tolCm,
    required this.onStart,
    required this.onStop,
    required this.onBackToEdit,
  });

  final double offX;
  final double offY;
  final bool running;
  final double posX;
  final double posY;
  final double residualCm;
  final double maxResidualCm;
  final double turnedDeg;
  final double targetDeg;
  final double tolCm;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onBackToEdit;

  @override
  Widget build(BuildContext context) {
    final enoughRotation = turnedDeg >= targetDeg;
    final pass = enoughRotation && maxResidualCm <= tolCm;
    final fail = enoughRotation && maxResidualCm > tolCm;

    final Color verdictColor = pass
        ? const Color(0xFF66BB6A)
        : fail
            ? const Color(0xFFEF5350)
            : Colors.white54;
    final String verdictText = pass
        ? 'PASS — odometry holds during rotation'
        : fail
            ? 'FAIL — odometry drifts; adjust the offset'
            : running
                ? 'Rotate the robot in place…'
                : 'Saved. Verify by rotating the robot.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Offset ${offX.toStringAsFixed(1)} · ${offY.toStringAsFixed(1)} mm saved',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Drift now',
                  value: residualCm.toStringAsFixed(2),
                  unit: 'cm',
                  color: residualCm <= tolCm
                      ? const Color(0xFF66BB6A)
                      : const Color(0xFFFFA726),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Metric(
                  label: 'Worst drift',
                  value: maxResidualCm.toStringAsFixed(2),
                  unit: 'cm',
                  color: verdictColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Metric(
                  label: 'Rotated',
                  value: turnedDeg.toStringAsFixed(0),
                  unit: '°/${targetDeg.toStringAsFixed(0)}',
                  color: enoughRotation
                      ? const Color(0xFF66BB6A)
                      : Colors.white70,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: verdictColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: verdictColor),
          ),
          child: Text(
            verdictText,
            style: TextStyle(
                color: verdictColor, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onBackToEdit,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Edit offset'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: running ? onStop : onStart,
                style: FilledButton.styleFrom(
                  backgroundColor: running ? const Color(0xFFEF5350) : null,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: Icon(running ? Icons.stop : Icons.replay),
                label: Text(running ? 'Stop' : 'Start rotation test',
                    style: const TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 34,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(unit, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }
}
