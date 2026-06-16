import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:raccoon_transport/messages/types/scalar_i32_t.g.dart';

import 'package:stpvelox/core/transport/domain/providers.dart';
import 'package:stpvelox/core/transport/domain/services/transport_service.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/calib_board/application/calib_board_providers.dart';
import 'package:stpvelox/features/calib_board/domain/calib_channels.dart';

/// PAA-Kalibrier-Wizard.  Ein Schritt = ein Vollbild, kein Scrollen, wenig
/// Text.  Der Nutzer wählt eine Strecke, schiebt den Roboter sauber je
/// einmal (oder mehrmals gemittelt) in X und Y, der Wizard erkennt selbst
/// welcher Sensor-Kanal anspricht und schreibt counts/cm ins Flash.
class CalibPaaCalibrationScreen extends ConsumerStatefulWidget {
  const CalibPaaCalibrationScreen({super.key});

  @override
  ConsumerState<CalibPaaCalibrationScreen> createState() =>
      _CalibPaaCalibrationScreenState();
}

enum _Step { setup, moveX, moveY, save, saving, done }

enum _RobotAxis { x, y }

enum _SensorAxis { dx, dy }

class _Capture {
  const _Capture({
    required this.sensorAxis,
    required this.absoluteCounts,
    required this.countsPerCm,
  });

  final _SensorAxis sensorAxis;
  final int absoluteCounts;
  final double countsPerCm;

  String get sensorLabel => sensorAxis == _SensorAxis.dx ? 'dX' : 'dY';
}

class _CalibPaaCalibrationScreenState
    extends ConsumerState<CalibPaaCalibrationScreen> {
  static const double _matchTolerance = 0.02;
  static const int _dominanceThreshold = 100;  // counts netto — klarer Move
  static const double _secondaryRatio = 0.75;  // secondary/primary max

  StreamSubscription<dynamic>? _accXSub;
  StreamSubscription<dynamic>? _accYSub;

  _Step _step = _Step.setup;

  double _distanceCm = 30;
  double _heightMm = 19;
  int _trialCount = 3;

  // Board-seitig integrierter Zählerstand (frei laufend) + Snapshot zu
  // Beginn des aktuellen Moves.  Netto-Verschiebung = aktuell − Snapshot.
  int? _accX;
  int? _accY;
  int _baseX = 0;
  int _baseY = 0;

  final List<_Capture> _xSamples = [];
  final List<_Capture> _ySamples = [];

  double? _pendingCx;
  double? _pendingCy;
  double? _pendingHeight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _heightMm = ref.read(calibPaaCalHeightProvider).value ?? 19;
      });
      _subscribe(ref.read(transportServiceProvider));
    });
  }

  @override
  void dispose() {
    _accXSub?.cancel();
    _accYSub?.cancel();
    super.dispose();
  }

  void _subscribe(TransportService transport) {
    _accXSub = transport
        .subscribeAs<ScalarI32T>(CalibChannels.paaAccX, ScalarI32T.decode,
            throttle: kUiSensorSampleRate)
        .listen((d) => _onAcc(_SensorAxis.dx, d.value.value));
    _accYSub = transport
        .subscribeAs<ScalarI32T>(CalibChannels.paaAccY, ScalarI32T.decode,
            throttle: kUiSensorSampleRate)
        .listen((d) => _onAcc(_SensorAxis.dy, d.value.value));
  }

  void _onAcc(_SensorAxis axis, int value) {
    if (!mounted) return;
    setState(() {
      if (axis == _SensorAxis.dx) {
        _accX = value;
      } else {
        _accY = value;
      }
    });
  }

  // Netto-Verschiebung des aktuellen Moves = Board-Zähler − Snapshot.
  int get _netX => (_accX ?? _baseX) - _baseX;
  int get _netY => (_accY ?? _baseY) - _baseY;

  /// Snapshot setzen — markiert den Start eines (neuen) Moves.  Verwirft
  /// damit zugleich die bisherige Bewegung (Reset).
  void _rebase() {
    setState(() {
      _baseX = _accX ?? _baseX;
      _baseY = _accY ?? _baseY;
    });
  }

  _SensorAxis get _dominantSensor =>
      _netX.abs() >= _netY.abs() ? _SensorAxis.dx : _SensorAxis.dy;

  /// Live-Bewertung der aktuellen Netto-Bewegung: sauber genug zum Aufnehmen?
  String? _moveProblem(_RobotAxis axis) {
    final primary = math.max(_netX.abs(), _netY.abs());
    final secondary = math.min(_netX.abs(), _netY.abs());
    if (primary < _dominanceThreshold) return 'Move further along one axis';
    if (secondary > primary * _secondaryRatio) return 'Keep the move straight';
    if (axis == _RobotAxis.y &&
        _xSamples.isNotEmpty &&
        _dominantSensor == _xSamples.first.sensorAxis) {
      return 'Same channel as X — turn the robot 90°';
    }
    return null;
  }

  void _record(_RobotAxis axis) {
    if (_moveProblem(axis) != null || _distanceCm <= 0) return;
    final sensor = _dominantSensor;
    final net = sensor == _SensorAxis.dx ? _netX : _netY;
    final abs = net.abs();
    final capture = _Capture(
      sensorAxis: sensor,
      absoluteCounts: abs,
      countsPerCm: abs / _distanceCm,
    );
    final samples = axis == _RobotAxis.x ? _xSamples : _ySamples;
    samples.add(capture);
    _rebase();  // nächsten Trial / nächste Achse bei aktuellem Stand starten

    if (samples.length >= _trialCount) {
      setState(() => _step = axis == _RobotAxis.x ? _Step.moveY : _Step.save);
    } else {
      setState(() {});
    }
  }

  double _avg(List<_Capture> s) =>
      s.fold<double>(0, (a, c) => a + c.countsPerCm) / s.length;

  void _save() {
    if (_xSamples.isEmpty || _ySamples.isEmpty) return;
    _pendingCx = _avg(_xSamples);
    _pendingCy = _avg(_ySamples);
    _pendingHeight = _heightMm;
    ref.read(calibCommandPublisherProvider).sendSetCalibration(
          cxPerCm: _pendingCx!,
          cyPerCm: _pendingCy!,
          heightMm: _heightMm,
        );
    setState(() => _step = _Step.saving);
  }

  bool _near(double? a, double? b) =>
      a != null && b != null && (a - b).abs() <= _matchTolerance;

  void _restart() {
    _rebase();
    setState(() {
      _xSamples.clear();
      _ySamples.clear();
      _pendingCx = null;
      _pendingCy = null;
      _pendingHeight = null;
      _step = _Step.setup;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cx = ref.watch(calibPaaCalCxProvider).value;
    final cy = ref.watch(calibPaaCalCyProvider).value;
    final h = ref.watch(calibPaaCalHeightProvider).value;
    final valid = ref.watch(calibPaaCalValidProvider).value ?? false;

    // Flash-Bestätigung abwarten: sobald das Board die erwarteten Werte
    // zurückmeldet, sind wir fertig.
    if (_step == _Step.saving &&
        valid &&
        _near(cx, _pendingCx) &&
        _near(cy, _pendingCy) &&
        _near(h, _pendingHeight)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _step == _Step.saving) {
          setState(() => _step = _Step.done);
        }
      });
    }

    return Scaffold(
      appBar: createTopBar(context, 'PAA Calibration'),
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _StepDots(current: _step.index, total: _Step.values.length - 1),
              const SizedBox(height: 12),
              Expanded(child: _content(cx, cy, h, valid)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(double? cx, double? cy, double? h, bool valid) {
    switch (_step) {
      case _Step.setup:
        return _SetupStep(
          distanceCm: _distanceCm,
          heightMm: _heightMm,
          trialCount: _trialCount,
          currentCx: cx,
          currentCy: cy,
          calibrated: valid,
          onDistance: (v) => setState(() => _distanceCm = v),
          onHeight: (v) => setState(() => _heightMm = v),
          onTrials: (v) => setState(() => _trialCount = v),
          onStart: () {
            _rebase();
            setState(() => _step = _Step.moveX);
          },
        );
      case _Step.moveX:
        return _MoveStep(
          axisLabel: 'X',
          distanceCm: _distanceCm,
          trial: _xSamples.length,
          trialCount: _trialCount,
          countsDx: _netX.abs(),
          countsDy: _netY.abs(),
          dominant: _dominantSensor,
          problem: _moveProblem(_RobotAxis.x),
          onReset: _rebase,
          onRecord: () => _record(_RobotAxis.x),
        );
      case _Step.moveY:
        return _MoveStep(
          axisLabel: 'Y',
          distanceCm: _distanceCm,
          trial: _ySamples.length,
          trialCount: _trialCount,
          countsDx: _netX.abs(),
          countsDy: _netY.abs(),
          dominant: _dominantSensor,
          problem: _moveProblem(_RobotAxis.y),
          onReset: _rebase,
          onRecord: () => _record(_RobotAxis.y),
        );
      case _Step.save:
        return _SaveStep(
          cx: _avg(_xSamples),
          cy: _avg(_ySamples),
          xSensor: _xSamples.first.sensorLabel,
          ySensor: _ySamples.first.sensorLabel,
          heightMm: _heightMm,
          onRedo: _restart,
          onSave: _save,
        );
      case _Step.saving:
        return const _SavingStep();
      case _Step.done:
        return _DoneStep(
          cx: _pendingCx!,
          cy: _pendingCy!,
          heightMm: _pendingHeight!,
          onRestart: _restart,
        );
    }
  }
}

// ── Schritt-Fortschritt ────────────────────────────────────────────────

class _StepDots extends StatelessWidget {
  const _StepDots({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final done = i <= current;
        return Expanded(
          child: Container(
            height: 5,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: done ? const Color(0xFF42A5F5) : Colors.white24,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }
}

// ── Schritt 1: Setup ────────────────────────────────────────────────────

class _SetupStep extends StatelessWidget {
  const _SetupStep({
    required this.distanceCm,
    required this.heightMm,
    required this.trialCount,
    required this.currentCx,
    required this.currentCy,
    required this.calibrated,
    required this.onDistance,
    required this.onHeight,
    required this.onTrials,
    required this.onStart,
  });

  final double distanceCm;
  final double heightMm;
  final int trialCount;
  final double? currentCx;
  final double? currentCy;
  final bool calibrated;
  final ValueChanged<double> onDistance;
  final ValueChanged<double> onHeight;
  final ValueChanged<int> onTrials;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          calibrated
              ? 'Calibrated: cx ${currentCx?.toStringAsFixed(2)} · cy ${currentCy?.toStringAsFixed(2)} counts/cm'
              : 'Not calibrated yet — using defaults',
          style: TextStyle(
            color: calibrated ? const Color(0xFF66BB6A) : const Color(0xFFFFA726),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _Stepper(
                label: 'Distance',
                text: '${distanceCm.toStringAsFixed(0)} cm',
                onMinus: () => onDistance((distanceCm - 5).clamp(5, 200)),
                onPlus: () => onDistance((distanceCm + 5).clamp(5, 200)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Stepper(
                label: 'Sensor height',
                text: '${heightMm.toStringAsFixed(1)} mm',
                onMinus: () => onHeight((heightMm - 0.5).clamp(5, 50)),
                onPlus: () => onHeight((heightMm + 0.5).clamp(5, 50)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Stepper(
                label: 'Tries / axis',
                text: '$trialCount',
                onMinus: () => onTrials((trialCount - 1).clamp(1, 5)),
                onPlus: () => onTrials((trialCount + 1).clamp(1, 5)),
              ),
            ),
          ],
        ),
        const Spacer(),
        SizedBox(
          height: 60,
          child: FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start', style: TextStyle(fontSize: 18)),
          ),
        ),
      ],
    );
  }
}

// ── Schritt 2/3: Move ───────────────────────────────────────────────────

class _MoveStep extends StatelessWidget {
  const _MoveStep({
    required this.axisLabel,
    required this.distanceCm,
    required this.trial,
    required this.trialCount,
    required this.countsDx,
    required this.countsDy,
    required this.dominant,
    required this.problem,
    required this.onReset,
    required this.onRecord,
  });

  final String axisLabel;
  final double distanceCm;
  final int trial;
  final int trialCount;
  final int countsDx;
  final int countsDy;
  final _SensorAxis dominant;
  final String? problem;
  final VoidCallback onReset;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final ready = problem == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Push robot along $axisLabel',
              style: const TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            _Badge('${distanceCm.toStringAsFixed(0)} cm'),
            if (trialCount > 1) ...[
              const SizedBox(width: 8),
              _Badge('${trial + 1}/$trialCount'),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _ChannelTile(
                  label: 'dX',
                  counts: countsDx,
                  active: dominant == _SensorAxis.dx && countsDx > 0,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ChannelTile(
                  label: 'dY',
                  counts: countsDy,
                  active: dominant == _SensorAxis.dy && countsDy > 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 22,
          child: Center(
            child: Text(
              problem ?? 'Ready — record this move',
              style: TextStyle(
                color: ready ? const Color(0xFF66BB6A) : Colors.white54,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onReset,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                child: const Text('Reset'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: ready ? onRecord : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                child: const Text('Record move', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile(
      {required this.label, required this.counts, required this.active});
  final String label;
  final int counts;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF66BB6A) : Colors.white38;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: active ? 2.5 : 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            '$counts',
            style: TextStyle(
              color: active ? Colors.white : Colors.white60,
              fontSize: 46,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
            ),
          ),
          const Text('counts',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }
}

// ── Schritt 4: Save ─────────────────────────────────────────────────────

class _SaveStep extends StatelessWidget {
  const _SaveStep({
    required this.cx,
    required this.cy,
    required this.xSensor,
    required this.ySensor,
    required this.heightMm,
    required this.onRedo,
    required this.onSave,
  });

  final double cx;
  final double cy;
  final String xSensor;
  final String ySensor;
  final double heightMm;
  final VoidCallback onRedo;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _ResultTile('X → $xSensor', cx)),
              const SizedBox(width: 12),
              Expanded(child: _ResultTile('Y → $ySensor', cy)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('Sensor height ${heightMm.toStringAsFixed(1)} mm',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onRedo,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                child: const Text('Redo'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: onSave,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                icon: const Icon(Icons.save),
                label: const Text('Save to flash', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile(this.label, this.value);
  final String label;
  final double value;

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
              style: const TextStyle(
                  color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            value.toStringAsFixed(2),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
            ),
          ),
          const Text('counts/cm',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }
}

// ── Schritt 5/6: Saving + Done ──────────────────────────────────────────

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

class _DoneStep extends StatelessWidget {
  const _DoneStep({
    required this.cx,
    required this.cy,
    required this.heightMm,
    required this.onRestart,
  });

  final double cx;
  final double cy;
  final double heightMm;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        const Icon(Icons.check_circle, color: Color(0xFF66BB6A), size: 72),
        const SizedBox(height: 12),
        const Text('Saved to flash',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          'cx ${cx.toStringAsFixed(2)} · cy ${cy.toStringAsFixed(2)} counts/cm · h ${heightMm.toStringAsFixed(1)} mm',
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white70, fontSize: 13, fontFamily: 'monospace'),
        ),
        const Spacer(),
        SizedBox(
          height: 56,
          child: OutlinedButton(
            onPressed: onRestart,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
            ),
            child: const Text('Run again'),
          ),
        ),
      ],
    );
  }
}

// ── Bausteine ───────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  const _Badge(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.text,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final String text;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 2),
          Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _RoundBtn(icon: Icons.remove, onTap: onMinus),
              _RoundBtn(icon: Icons.add, onTap: onPlus),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: const BoxDecoration(
          color: Colors.white12,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
