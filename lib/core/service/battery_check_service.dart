///
/// Created by Tobias on 25,September,2025}
///
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stpvelox/core/service/sensors/battery_voltage_sensor.dart';
import 'package:stpvelox/core/widgets/raccoon_dialog.dart';

part 'battery_check_service.g.dart';

const _lowBatteryThreshold = 6.0;

/// The warning only closes after the voltage stayed above the threshold this
/// long, so it doesn't flicker when the voltage hovers around the threshold.
const _recoveryHoldTime = Duration(seconds: 30);

@riverpod
class BatteryCheckService extends _$BatteryCheckService {
  bool _warningVisible = false;
  BuildContext? _context;
  Timer? _dismissTimer;

  @override
  double? build() {
    ref.onDispose(_disposeAll);

    ref.listen(batteryVoltageSensorProvider, (previous, next) {
      if (next != null && _context != null) {
        _handleVoltageChange(_context!, next);
        state = next;
      }
    });

    return ref.read(batteryVoltageSensorProvider);
  }

  void start(BuildContext context) {
    _context = context;
    final currentVoltage = ref.read(batteryVoltageSensorProvider);
    if (currentVoltage != null) {
      _handleVoltageChange(context, currentVoltage);
    }
  }

  void stop() {
    _context = null;
    _disposeAll();
  }

  void _handleVoltageChange(BuildContext context, double voltage) {
    if (voltage > 0 && voltage < _lowBatteryThreshold) {
      _dismissTimer?.cancel();
      _dismissTimer = null;
      _maybeShowBatteryWarning(context, voltage);
    } else if (_warningVisible) {
      _dismissTimer ??= Timer(_recoveryHoldTime, () {
        _dismissTimer = null;
        final ctx = _context;
        if (ctx != null && ctx.mounted) _dismissWarningIfAny(ctx);
      });
    }
  }

  void _maybeShowBatteryWarning(BuildContext context, double voltage) {
    if (_warningVisible) return;

    _warningVisible = true;

    // No button: it closes itself when the voltage recovers.
    showRaccoonDialog<void>(
      context,
      dismissible: false,
      builder: (_) => RaccoonDialog(
        icon: Icons.battery_alert_rounded,
        iconColor: Colors.orange,
        title: 'Low Battery',
        message: 'Battery voltage is ${voltage.toStringAsFixed(2)}V.\n'
            'The robot may restart at any time.\n'
            'Please switch the battery now.',
      ),
    ).whenComplete(() {
      _warningVisible = false;
    });
  }

  void _dismissWarningIfAny(BuildContext context) {
    if (!_warningVisible) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    _warningVisible = false;
  }

  void _disposeAll() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _context = null;
  }
}
