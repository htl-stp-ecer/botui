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

class CalibPaaCalibrationScreen extends ConsumerStatefulWidget {
  const CalibPaaCalibrationScreen({super.key});

  @override
  ConsumerState<CalibPaaCalibrationScreen> createState() =>
      _CalibPaaCalibrationScreenState();
}

enum _WizardStep {
  distance,
  captureX,
  confirmX,
  captureY,
  confirmY,
  review,
  saving,
  done,
}

enum _RobotAxis { x, y }

enum _SensorAxis { dx, dy }

class _AxisCapture {
  const _AxisCapture({
    required this.robotAxis,
    required this.sensorAxis,
    required this.signedCounts,
    required this.absoluteCounts,
    required this.countsPerCm,
  });

  final _RobotAxis robotAxis;
  final _SensorAxis sensorAxis;
  final int signedCounts;
  final int absoluteCounts;
  final double countsPerCm;

  String get robotAxisLabel => robotAxis == _RobotAxis.x ? 'X' : 'Y';
  String get sensorAxisLabel => sensorAxis == _SensorAxis.dx ? 'dX' : 'dY';
}

class _AxisAggregate {
  const _AxisAggregate({
    required this.robotAxis,
    required this.sensorAxis,
    required this.samples,
  });

  final _RobotAxis robotAxis;
  final _SensorAxis sensorAxis;
  final List<_AxisCapture> samples;

  String get robotAxisLabel => robotAxis == _RobotAxis.x ? 'X' : 'Y';
  String get sensorAxisLabel => sensorAxis == _SensorAxis.dx ? 'dX' : 'dY';

  double get averageCountsPerCm =>
      samples.fold<double>(0, (sum, sample) => sum + sample.countsPerCm) /
      samples.length;
}

class _CalibPaaCalibrationScreenState
    extends ConsumerState<CalibPaaCalibrationScreen> {
  static const double _matchTolerance = 0.02;

  final double _defaultDistanceCm = 30;
  final int _dominanceThresholdCounts = 20;
  final int _defaultTrialCount = 5;

  StreamSubscription<dynamic>? _dxSub;
  StreamSubscription<dynamic>? _dySub;

  _WizardStep _step = _WizardStep.distance;

  double _distanceCm = 30;
  double _heightMm = 19;
  int _trialCount = 5;

  int? _lastDx;
  int? _lastDy;
  int _sumDx = 0;
  int _sumDy = 0;
  int _sumAbsDx = 0;
  int _sumAbsDy = 0;

  _AxisCapture? _capturedX;
  _AxisCapture? _capturedY;
  final List<_AxisCapture> _xSamples = [];
  final List<_AxisCapture> _ySamples = [];

  double? _pendingSaveCx;
  double? _pendingSaveCy;
  double? _pendingSaveHeight;

  @override
  void initState() {
    super.initState();
    _distanceCm = _defaultDistanceCm;
    _trialCount = _defaultTrialCount;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _heightMm = ref.read(calibPaaCalHeightProvider).value ?? 19;
      _subscribeToDeltas(ref.read(transportServiceProvider));
      setState(() {});
    });
  }

  @override
  void dispose() {
    _dxSub?.cancel();
    _dySub?.cancel();
    super.dispose();
  }

  void _subscribeToDeltas(TransportService transport) {
    _dxSub?.cancel();
    _dySub?.cancel();

    _dxSub = transport
        .subscribeAs<ScalarI32T>(CalibChannels.paaDeltaX, ScalarI32T.decode)
        .listen((d) => _onDelta(_SensorAxis.dx, d.value.value));
    _dySub = transport
        .subscribeAs<ScalarI32T>(CalibChannels.paaDeltaY, ScalarI32T.decode)
        .listen((d) => _onDelta(_SensorAxis.dy, d.value.value));
  }

  void _onDelta(_SensorAxis axis, int value) {
    if (!mounted) return;

    setState(() {
      if (axis == _SensorAxis.dx) {
        _lastDx = value;
        if (_isCapturing) {
          _sumDx += value;
          _sumAbsDx += value.abs();
        }
      } else {
        _lastDy = value;
        if (_isCapturing) {
          _sumDy += value;
          _sumAbsDy += value.abs();
        }
      }
    });
  }

  bool get _isCapturing =>
      _step == _WizardStep.captureX || _step == _WizardStep.captureY;

  bool _matches(double? actual, double? expected) {
    if (actual == null || expected == null) return false;
    return (actual - expected).abs() <= _matchTolerance;
  }

  void _resetAccumulation() {
    setState(() {
      _sumDx = 0;
      _sumDy = 0;
      _sumAbsDx = 0;
      _sumAbsDy = 0;
    });
  }

  void _startCapture(_RobotAxis axis) {
    _resetAccumulation();
    setState(() {
      _step =
          axis == _RobotAxis.x ? _WizardStep.captureX : _WizardStep.captureY;
    });
  }

  _AxisCapture? _buildCapture(_RobotAxis axis) {
    final primaryAbs = math.max(_sumAbsDx, _sumAbsDy);
    final secondaryAbs = math.min(_sumAbsDx, _sumAbsDy);

    if (primaryAbs < _dominanceThresholdCounts) {
      return null;
    }

    final dominantAxis =
        _sumAbsDx >= _sumAbsDy ? _SensorAxis.dx : _SensorAxis.dy;
    final signedCounts = dominantAxis == _SensorAxis.dx ? _sumDx : _sumDy;
    final absoluteCounts =
        dominantAxis == _SensorAxis.dx ? _sumAbsDx : _sumAbsDy;

    if (absoluteCounts <= 0 || _distanceCm <= 0) {
      return null;
    }

    if (secondaryAbs > absoluteCounts * 0.75) {
      return null;
    }

    return _AxisCapture(
      robotAxis: axis,
      sensorAxis: dominantAxis,
      signedCounts: signedCounts,
      absoluteCounts: absoluteCounts,
      countsPerCm: absoluteCounts / _distanceCm,
    );
  }

  void _finishCapture(_RobotAxis axis) {
    final capture = _buildCapture(axis);
    if (capture == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Movement was too small or ambiguous. Move in one clean axis and try again.',
          ),
        ),
      );
      return;
    }

    final xSensorAxis = _capturedX?.sensorAxis ??
        (_xSamples.isNotEmpty ? _xSamples.first.sensorAxis : null);
    if (axis == _RobotAxis.y &&
        xSensorAxis != null &&
        xSensorAxis == capture.sensorAxis) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Y resolved to the same sensor channel as X. Retry with a cleaner Y-only move.',
          ),
        ),
      );
      return;
    }

    setState(() {
      if (axis == _RobotAxis.x) {
        _capturedX = capture;
        _step = _WizardStep.confirmX;
      } else {
        _capturedY = capture;
        _step = _WizardStep.confirmY;
      }
    });
  }

  void _confirmCapture(_RobotAxis axis) {
    setState(() {
      if (axis == _RobotAxis.x) {
        _xSamples.add(_capturedX!);
        _capturedX = null;
        _step = _xSamples.length >= _trialCount
            ? _WizardStep.captureY
            : _WizardStep.captureX;
      } else {
        _ySamples.add(_capturedY!);
        _capturedY = null;
        _step = _ySamples.length >= _trialCount
            ? _WizardStep.review
            : _WizardStep.captureY;
      }
    });
    _resetAccumulation();
  }

  void _retryCapture(_RobotAxis axis) {
    _resetAccumulation();
    setState(() {
      if (axis == _RobotAxis.x) {
        _capturedX = null;
        _xSamples.clear();
        _capturedY = null;
        _ySamples.clear();
        _step = _WizardStep.captureX;
      } else {
        _capturedY = null;
        _ySamples.clear();
        _step = _WizardStep.captureY;
      }
    });
  }

  void _saveCalibration() {
    final aggregateX = _aggregateFor(_RobotAxis.x);
    final aggregateY = _aggregateFor(_RobotAxis.y);
    if (aggregateX == null || aggregateY == null) return;

    _pendingSaveCx = aggregateX.averageCountsPerCm;
    _pendingSaveCy = aggregateY.averageCountsPerCm;
    _pendingSaveHeight = _heightMm;

    ref.read(calibCommandPublisherProvider).sendSetCalibration(
          cxPerCm: aggregateX.averageCountsPerCm,
          cyPerCm: aggregateY.averageCountsPerCm,
          heightMm: _heightMm,
        );

    setState(() {
      _step = _WizardStep.saving;
    });
  }

  _AxisAggregate? _aggregateFor(_RobotAxis axis) {
    final samples = axis == _RobotAxis.x ? _xSamples : _ySamples;
    if (samples.length < _trialCount) return null;
    final sensorAxis = samples.first.sensorAxis;
    final sameAxis = samples.every((sample) => sample.sensorAxis == sensorAxis);
    if (!sameAxis) return null;
    return _AxisAggregate(
      robotAxis: axis,
      sensorAxis: sensorAxis,
      samples: List.unmodifiable(samples),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cxCurrent = ref.watch(calibPaaCalCxProvider).value;
    final cyCurrent = ref.watch(calibPaaCalCyProvider).value;
    final hCurrent = ref.watch(calibPaaCalHeightProvider).value;
    final valid = ref.watch(calibPaaCalValidProvider).value ?? false;

    if (_step == _WizardStep.saving &&
        valid &&
        _matches(cxCurrent, _pendingSaveCx) &&
        _matches(cyCurrent, _pendingSaveCy) &&
        _matches(hCurrent, _pendingSaveHeight)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _step != _WizardStep.saving) return;
        setState(() {
          _step = _WizardStep.done;
        });
      });
    }

    return Scaffold(
      appBar: createTopBar(context, 'PAA Calibration Wizard'),
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CurrentCalCard(
                cx: cxCurrent,
                cy: cyCurrent,
                h: hCurrent,
                valid: valid,
              ),
              const SizedBox(height: 12),
              _WizardStatusCard(
                step: _step,
                distanceCm: _distanceCm,
                trialCount: _trialCount,
                xProgress: _xSamples.length,
                yProgress: _ySamples.length,
                xAggregate: _aggregateFor(_RobotAxis.x),
                yAggregate: _aggregateFor(_RobotAxis.y),
              ),
              const SizedBox(height: 12),
              _buildStepContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case _WizardStep.distance:
        return _DistanceStepCard(
          distanceCm: _distanceCm,
          heightMm: _heightMm,
          trialCount: _trialCount,
          onDistanceChanged: (value) => setState(() => _distanceCm = value),
          onHeightChanged: (value) => setState(() => _heightMm = value),
          onTrialCountChanged: (value) => setState(() => _trialCount = value),
          onContinue: () => _startCapture(_RobotAxis.x),
        );
      case _WizardStep.captureX:
        return _CaptureStepCard(
          robotAxisLabel: 'X',
          trialCount: _trialCount,
          completedTrials: _xSamples.length,
          distanceCm: _distanceCm,
          lastDx: _lastDx,
          lastDy: _lastDy,
          sumDx: _sumDx,
          sumDy: _sumDy,
          sumAbsDx: _sumAbsDx,
          sumAbsDy: _sumAbsDy,
          primaryActionLabel: 'Use this X capture',
          onPrimaryAction: () => _finishCapture(_RobotAxis.x),
          onReset: _resetAccumulation,
          instructions:
              'Move the robot straight along its X axis for the selected distance. '
              'The wizard will determine whether that motion lands on sensor dX or dY.',
        );
      case _WizardStep.confirmX:
        return _ConfirmStepCard(
          capture: _capturedX!,
          distanceCm: _distanceCm,
          completedTrials: _xSamples.length,
          trialCount: _trialCount,
          onConfirm: () => _confirmCapture(_RobotAxis.x),
          onRetry: () => _retryCapture(_RobotAxis.x),
        );
      case _WizardStep.captureY:
        return _CaptureStepCard(
          robotAxisLabel: 'Y',
          trialCount: _trialCount,
          completedTrials: _ySamples.length,
          distanceCm: _distanceCm,
          lastDx: _lastDx,
          lastDy: _lastDy,
          sumDx: _sumDx,
          sumDy: _sumDy,
          sumAbsDx: _sumAbsDx,
          sumAbsDy: _sumAbsDy,
          primaryActionLabel: 'Use this Y capture',
          onPrimaryAction: () => _finishCapture(_RobotAxis.y),
          onReset: _resetAccumulation,
          instructions:
              'Move the robot straight along its Y axis for the same distance. '
              'Keep the motion isolated so the second sensor channel becomes dominant.',
        );
      case _WizardStep.confirmY:
        return _ConfirmStepCard(
          capture: _capturedY!,
          distanceCm: _distanceCm,
          completedTrials: _ySamples.length,
          trialCount: _trialCount,
          onConfirm: () => _confirmCapture(_RobotAxis.y),
          onRetry: () => _retryCapture(_RobotAxis.y),
        );
      case _WizardStep.review:
        final aggregateX = _aggregateFor(_RobotAxis.x)!;
        final aggregateY = _aggregateFor(_RobotAxis.y)!;
        return _ReviewStepCard(
          xAggregate: aggregateX,
          yAggregate: aggregateY,
          heightMm: _heightMm,
          onHeightChanged: (value) => setState(() => _heightMm = value),
          onBackToX: () => _retryCapture(_RobotAxis.x),
          onBackToY: () => _retryCapture(_RobotAxis.y),
          onSave: _saveCalibration,
        );
      case _WizardStep.saving:
        return _SavingStepCard(
          expectedCx: _pendingSaveCx!,
          expectedCy: _pendingSaveCy!,
          expectedHeight: _pendingSaveHeight!,
        );
      case _WizardStep.done:
        final aggregateX = _aggregateFor(_RobotAxis.x)!;
        final aggregateY = _aggregateFor(_RobotAxis.y)!;
        return _DoneStepCard(
          xAggregate: aggregateX,
          yAggregate: aggregateY,
          onRestart: () {
            _resetAccumulation();
            setState(() {
              _capturedX = null;
              _capturedY = null;
              _xSamples.clear();
              _ySamples.clear();
              _pendingSaveCx = null;
              _pendingSaveCy = null;
              _pendingSaveHeight = null;
              _step = _WizardStep.distance;
            });
          },
        );
    }
  }
}

class _CurrentCalCard extends StatelessWidget {
  const _CurrentCalCard({
    required this.cx,
    required this.cy,
    required this.h,
    required this.valid,
  });

  final double? cx;
  final double? cy;
  final double? h;
  final bool valid;

  @override
  Widget build(BuildContext context) {
    final color = valid ? const Color(0xFF66BB6A) : const Color(0xFFFFA726);
    final source = valid ? 'flash (calibrated)' : 'defaults (never calibrated)';
    String fmt(double? v) => v == null ? '—' : v.toStringAsFixed(3);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Current calibration',
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                source,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'cx = ${fmt(cx)} counts/cm    cy = ${fmt(cy)} counts/cm    h = ${fmt(h)} mm',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _WizardStatusCard extends StatelessWidget {
  const _WizardStatusCard({
    required this.step,
    required this.distanceCm,
    required this.trialCount,
    required this.xProgress,
    required this.yProgress,
    required this.xAggregate,
    required this.yAggregate,
  });

  final _WizardStep step;
  final double distanceCm;
  final int trialCount;
  final int xProgress;
  final int yProgress;
  final _AxisAggregate? xAggregate;
  final _AxisAggregate? yAggregate;

  @override
  Widget build(BuildContext context) {
    final title = switch (step) {
      _WizardStep.distance => 'Step 1: Select calibration distance',
      _WizardStep.captureX => 'Step 2: Capture robot X movement',
      _WizardStep.confirmX => 'Step 3: Confirm robot X mapping',
      _WizardStep.captureY => 'Step 4: Capture robot Y movement',
      _WizardStep.confirmY => 'Step 5: Confirm robot Y mapping',
      _WizardStep.review => 'Step 6: Review and save',
      _WizardStep.saving => 'Step 7: Waiting for flash write',
      _WizardStep.done => 'Calibration written to flash',
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Distance: ${distanceCm.toStringAsFixed(1)} cm  •  Trials: $trialCount',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SummaryPill(
                  label: 'X',
                  progress: xProgress,
                  trialCount: trialCount,
                  aggregate: xAggregate,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryPill(
                  label: 'Y',
                  progress: yProgress,
                  trialCount: trialCount,
                  aggregate: yAggregate,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.progress,
    required this.trialCount,
    required this.aggregate,
  });

  final String label;
  final int progress;
  final int trialCount;
  final _AxisAggregate? aggregate;

  @override
  Widget build(BuildContext context) {
    final complete = aggregate != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: complete ? const Color(0xFF66BB6A) : Colors.white24,
        ),
      ),
      child: Text(
        complete
            ? '$label -> ${aggregate!.sensorAxisLabel} (${aggregate!.averageCountsPerCm.toStringAsFixed(3)})'
            : '$label $progress/$trialCount',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: complete ? const Color(0xFF66BB6A) : Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DistanceStepCard extends StatelessWidget {
  const _DistanceStepCard({
    required this.distanceCm,
    required this.heightMm,
    required this.trialCount,
    required this.onDistanceChanged,
    required this.onHeightChanged,
    required this.onTrialCountChanged,
    required this.onContinue,
  });

  final double distanceCm;
  final double heightMm;
  final int trialCount;
  final ValueChanged<double> onDistanceChanged;
  final ValueChanged<double> onHeightChanged;
  final ValueChanged<int> onTrialCountChanged;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Choose the known travel distance first. The wizard will use the same distance for X and Y.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _NumberStepper(
                  label: 'Distance',
                  value: distanceCm,
                  unit: 'cm',
                  step: 5,
                  min: 5,
                  max: 200,
                  onChanged: onDistanceChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NumberStepper(
                  label: 'Sensor height',
                  value: heightMm,
                  unit: 'mm',
                  step: 0.5,
                  min: 5,
                  max: 50,
                  onChanged: onHeightChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 220,
            child: _IntStepper(
              label: 'Tries per axis',
              value: trialCount,
              min: 2,
              max: 8,
              onChanged: onTrialCountChanged,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: onContinue,
              child: const Text('Continue to X axis'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureStepCard extends StatelessWidget {
  const _CaptureStepCard({
    required this.robotAxisLabel,
    required this.trialCount,
    required this.completedTrials,
    required this.distanceCm,
    required this.lastDx,
    required this.lastDy,
    required this.sumDx,
    required this.sumDy,
    required this.sumAbsDx,
    required this.sumAbsDy,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    required this.onReset,
    required this.instructions,
  });

  final String robotAxisLabel;
  final int trialCount;
  final int completedTrials;
  final double distanceCm;
  final int? lastDx;
  final int? lastDy;
  final int sumDx;
  final int sumDy;
  final int sumAbsDx;
  final int sumAbsDy;
  final String primaryActionLabel;
  final VoidCallback onPrimaryAction;
  final VoidCallback onReset;
  final String instructions;

  @override
  Widget build(BuildContext context) {
    final dxCountsPerCm = distanceCm > 0 ? sumAbsDx / distanceCm : 0.0;
    final dyCountsPerCm = distanceCm > 0 ? sumAbsDy / distanceCm : 0.0;
    final dominantIsDx = sumAbsDx >= sumAbsDy;

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Trial ${completedTrials + 1} of $trialCount. $instructions',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _LiveAxisTile(
                  label: 'dX',
                  lastValue: lastDx,
                  signedSum: sumDx,
                  absoluteSum: sumAbsDx,
                  countsPerCm: dxCountsPerCm,
                  highlighted: dominantIsDx,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LiveAxisTile(
                  label: 'dY',
                  lastValue: lastDy,
                  signedSum: sumDy,
                  absoluteSum: sumAbsDy,
                  countsPerCm: dyCountsPerCm,
                  highlighted: !dominantIsDx,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'When the move is complete, confirm the dominant channel for robot $robotAxisLabel.',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset accumulation'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: onPrimaryAction,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(primaryActionLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveAxisTile extends StatelessWidget {
  const _LiveAxisTile({
    required this.label,
    required this.lastValue,
    required this.signedSum,
    required this.absoluteSum,
    required this.countsPerCm,
    required this.highlighted,
  });

  final String label;
  final int? lastValue;
  final int signedSum;
  final int absoluteSum;
  final double countsPerCm;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final borderColor = highlighted ? const Color(0xFF66BB6A) : Colors.white24;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: highlighted ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: highlighted ? const Color(0xFF66BB6A) : Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'live: ${lastValue ?? "—"}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'signed sum: $signedSum',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'absolute sum: $absoluteSum',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${countsPerCm.toStringAsFixed(3)} counts/cm',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmStepCard extends StatelessWidget {
  const _ConfirmStepCard({
    required this.capture,
    required this.distanceCm,
    required this.completedTrials,
    required this.trialCount,
    required this.onConfirm,
    required this.onRetry,
  });

  final _AxisCapture capture;
  final double distanceCm;
  final int completedTrials;
  final int trialCount;
  final VoidCallback onConfirm;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final signLabel = capture.signedCounts >= 0 ? 'positive' : 'negative';

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Robot ${capture.robotAxisLabel} motion resolved to sensor ${capture.sensorAxisLabel}.',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'Accept this as sample ${completedTrials + 1} of $trialCount.',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Text(
            '${capture.absoluteCounts} counts over ${distanceCm.toStringAsFixed(1)} cm '
            '= ${capture.countsPerCm.toStringAsFixed(3)} counts/cm',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Signed motion on ${capture.sensorAxisLabel}: ${capture.signedCounts} ($signLabel). '
            'Only the magnitude is stored for calibration.',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onRetry,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Retry capture'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: onConfirm,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Confirm'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewStepCard extends StatelessWidget {
  const _ReviewStepCard({
    required this.xAggregate,
    required this.yAggregate,
    required this.heightMm,
    required this.onHeightChanged,
    required this.onBackToX,
    required this.onBackToY,
    required this.onSave,
  });

  final _AxisAggregate xAggregate;
  final _AxisAggregate yAggregate;
  final double heightMm;
  final ValueChanged<double> onHeightChanged;
  final VoidCallback onBackToX;
  final VoidCallback onBackToY;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Both axes are resolved. Review the mapping and then store the calibration.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          _ReviewRow(aggregate: xAggregate),
          const SizedBox(height: 10),
          _ReviewRow(aggregate: yAggregate),
          const SizedBox(height: 16),
          _NumberStepper(
            label: 'Sensor height',
            value: heightMm,
            unit: 'mm',
            step: 0.5,
            min: 5,
            max: 50,
            onChanged: onHeightChanged,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onBackToX,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Redo X'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: onBackToY,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Redo Y'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.save),
              label: const Text('Save to flash'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.aggregate});

  final _AxisAggregate aggregate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              aggregate.robotAxisLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${aggregate.sensorAxisLabel}  •  avg ${aggregate.averageCountsPerCm.toStringAsFixed(3)} counts/cm  •  ${aggregate.samples.length} tries',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavingStepCard extends StatelessWidget {
  const _SavingStepCard({
    required this.expectedCx,
    required this.expectedCy,
    required this.expectedHeight,
  });

  final double expectedCx;
  final double expectedCy;
  final double expectedHeight;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Waiting until the board reports the new calibration from flash.',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Expected values: cx=${expectedCx.toStringAsFixed(3)}  '
            'cy=${expectedCy.toStringAsFixed(3)}  '
            'h=${expectedHeight.toStringAsFixed(2)} mm',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _DoneStepCard extends StatelessWidget {
  const _DoneStepCard({
    required this.xAggregate,
    required this.yAggregate,
    required this.onRestart,
  });

  final _AxisAggregate xAggregate;
  final _AxisAggregate yAggregate;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'The board confirmed the new calibration values. Flash write is complete.',
            style: TextStyle(
              color: Color(0xFF66BB6A),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _ReviewRow(aggregate: xAggregate),
          const SizedBox(height: 10),
          _ReviewRow(aggregate: yAggregate),
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            child: OutlinedButton(
              onPressed: onRestart,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
              ),
              child: const Text('Run wizard again'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberStepper extends StatelessWidget {
  const _NumberStepper({
    required this.label,
    required this.value,
    required this.unit,
    required this.step,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final String unit;
  final double step;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              IconButton(
                onPressed: () => onChanged((value - step).clamp(min, max)),
                icon: const Icon(Icons.remove, color: Colors.white70),
              ),
              Expanded(
                child: Text(
                  '${value.toStringAsFixed(1)} $unit',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => onChanged((value + step).clamp(min, max)),
                icon: const Icon(Icons.add, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IntStepper extends StatelessWidget {
  const _IntStepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  '$value',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => onChanged((value - 1).clamp(min, max)),
            icon: const Icon(Icons.remove, color: Colors.white70),
          ),
          IconButton(
            onPressed: () => onChanged((value + 1).clamp(min, max)),
            icon: const Icon(Icons.add, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}
