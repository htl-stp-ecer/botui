import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raccoon_transport/messages/types/scalar_f_t.g.dart';
import 'package:raccoon_transport/messages/types/scalar_i32_t.g.dart';
import 'package:raccoon_transport/messages/types/string_t.g.dart';
import 'package:raccoon_transport/messages/types/vector3f_t.g.dart';
// ignore: unused_import — Vector3fT typing flows through Stream providers

import 'package:stpvelox/core/logging/logging.dart';
import 'package:stpvelox/core/transport/domain/providers.dart';
import 'package:stpvelox/core/transport/domain/services/transport_service.dart'
    show kUiSensorSampleRate;
import 'package:stpvelox/features/calib_board/domain/calib_channels.dart';
import 'package:stpvelox/features/calib_board/domain/entities/calib_board_status.dart';

/// Aggregierter Board-Status — subscribt alle vier Status-Channels und
/// fasst sie in einem [CalibBoardStatus] zusammen.  Notifier statt
/// rxdart-combineLatest weil wir Initial-Wert ([CalibBoardStatus.empty])
/// und Mapping/Übersetzung der Strings sauber kapseln wollen.
///
/// Riverpod 3 — wir nutzen die nicht-codegen NotifierProvider-API,
/// damit dieser File ohne build_runner auskommt.
class CalibBoardStatusNotifier extends Notifier<CalibBoardStatus> {
  final List<StreamSubscription<dynamic>> _subs = [];
  final _log = getLogger('CalibBoardStatus');

  @override
  CalibBoardStatus build() {
    _subscribeAll();
    ref.onDispose(() {
      for (final s in _subs) {
        s.cancel();
      }
    });
    return CalibBoardStatus.empty;
  }

  void _subscribeAll() {
    final t = ref.read(transportServiceProvider);

    _subs.add(
      t.subscribeAs<StringT>(CalibChannels.statusBoard, StringT.decode, throttle: kUiSensorSampleRate).listen(
        (d) => state = state.copyWith(
          boardConnected: d.value.value == 'connected',
        ),
        onError: (e) => _log.warning('status/board stream error: $e'),
      ),
    );

    _subs.add(
      t.subscribeAs<StringT>(CalibChannels.statusPort, StringT.decode, throttle: kUiSensorSampleRate).listen(
        (d) => state = state.copyWith(port: d.value.value),
        onError: (e) => _log.warning('status/port stream error: $e'),
      ),
    );

    _subs.add(
      t.subscribeAs<StringT>(CalibChannels.statusIcm, StringT.decode, throttle: kUiSensorSampleRate).listen(
        (d) {
          final v = d.value.value;
          state = state.copyWith(
            icm: _classifyIcm(v),
            icmDetail: v,
          );
        },
        onError: (e) => _log.warning('status/icm stream error: $e'),
      ),
    );

    _subs.add(
      t.subscribeAs<StringT>(CalibChannels.statusPaa, StringT.decode, throttle: kUiSensorSampleRate).listen(
        (d) {
          final v = d.value.value;
          state = state.copyWith(
            paa: _classifyPaa(v),
            paaDetail: v,
          );
        },
        onError: (e) => _log.warning('status/paa stream error: $e'),
      ),
    );
  }

  static CalibSensorState _classifyIcm(String v) {
    if (v == 'ok') return CalibSensorState.ok;
    if (v.startsWith('init_failed') ||
        v == 'board_disconnected' ||
        v == 'no_frames_yet') {
      return CalibSensorState.unavailable;
    }
    return CalibSensorState.unknown;
  }

  static CalibSensorState _classifyPaa(String v) {
    if (v == 'connected') return CalibSensorState.ok;
    if (v == 'absent' ||
        v.startsWith('init_failed') ||
        v == 'board_disconnected') {
      return CalibSensorState.unavailable;
    }
    return CalibSensorState.unknown;
  }
}

final calibBoardStatusProvider =
    NotifierProvider<CalibBoardStatusNotifier, CalibBoardStatus>(
  CalibBoardStatusNotifier.new,
);

// ── Sample-Streams ──────────────────────────────────────────────────
// AsyncValue<T>-Wrapper macht es UI-seitig einfach: erst loading, dann
// kontinuierlich die letzten Werte; bei Disconnect bleibt der letzte
// gesehene Wert hängen — Charts laufen einfach nicht weiter.

final calibIcmAccelProvider = StreamProvider.autoDispose<Vector3fT>((ref) {
  final t = ref.watch(transportServiceProvider);
  return t
      .subscribeAs<Vector3fT>(CalibChannels.icmAccel, Vector3fT.decode, throttle: kUiSensorSampleRate)
      .map((d) => d.value);
});

final calibIcmGyroProvider = StreamProvider.autoDispose<Vector3fT>((ref) {
  final t = ref.watch(transportServiceProvider);
  return t
      .subscribeAs<Vector3fT>(CalibChannels.icmGyro, Vector3fT.decode, throttle: kUiSensorSampleRate)
      .map((d) => d.value);
});

final calibIcmTempProvider = StreamProvider.autoDispose<ScalarFT>((ref) {
  final t = ref.watch(transportServiceProvider);
  return t
      .subscribeAs<ScalarFT>(CalibChannels.icmTemperature, ScalarFT.decode, throttle: kUiSensorSampleRate)
      .map((d) => d.value);
});

final calibPaaDxProvider = StreamProvider.autoDispose<ScalarI32T>((ref) {
  final t = ref.watch(transportServiceProvider);
  return t
      .subscribeAs<ScalarI32T>(CalibChannels.paaDeltaX, ScalarI32T.decode, throttle: kUiSensorSampleRate)
      .map((d) => d.value);
});

final calibPaaDyProvider = StreamProvider.autoDispose<ScalarI32T>((ref) {
  final t = ref.watch(transportServiceProvider);
  return t
      .subscribeAs<ScalarI32T>(CalibChannels.paaDeltaY, ScalarI32T.decode, throttle: kUiSensorSampleRate)
      .map((d) => d.value);
});

final calibPaaSqualProvider = StreamProvider.autoDispose<ScalarI32T>((ref) {
  final t = ref.watch(transportServiceProvider);
  return t
      .subscribeAs<ScalarI32T>(CalibChannels.paaSqual, ScalarI32T.decode, throttle: kUiSensorSampleRate)
      .map((d) => d.value);
});

final calibPaaShutterProvider = StreamProvider.autoDispose<ScalarI32T>((ref) {
  final t = ref.watch(transportServiceProvider);
  return t
      .subscribeAs<ScalarI32T>(CalibChannels.paaShutter, ScalarI32T.decode, throttle: kUiSensorSampleRate)
      .map((d) => d.value);
});

// ── PAA Kalibrierung ───────────────────────────────────────────────
// Bridge republisht die Werte aus dem FW PAA_CAL frame als scalar_f_t.

final calibPaaCalCxProvider = StreamProvider.autoDispose<double>((ref) {
  final t = ref.watch(transportServiceProvider);
  return t
      .subscribeAs<ScalarFT>(CalibChannels.paaCalCx, ScalarFT.decode, throttle: kUiSensorSampleRate)
      .map((d) => d.value.value);
});

final calibPaaCalCyProvider = StreamProvider.autoDispose<double>((ref) {
  final t = ref.watch(transportServiceProvider);
  return t
      .subscribeAs<ScalarFT>(CalibChannels.paaCalCy, ScalarFT.decode, throttle: kUiSensorSampleRate)
      .map((d) => d.value.value);
});

final calibPaaCalHeightProvider = StreamProvider.autoDispose<double>((ref) {
  final t = ref.watch(transportServiceProvider);
  return t
      .subscribeAs<ScalarFT>(CalibChannels.paaCalHeight, ScalarFT.decode, throttle: kUiSensorSampleRate)
      .map((d) => d.value.value);
});

final calibPaaCalValidProvider = StreamProvider.autoDispose<bool>((ref) {
  final t = ref.watch(transportServiceProvider);
  return t
      .subscribeAs<ScalarI32T>(CalibChannels.paaCalValid, ScalarI32T.decode, throttle: kUiSensorSampleRate)
      .map((d) => d.value.value != 0);
});

// PAA-Montageoffset vom Drehzentrum (mm) — vom FW-Flash republisht.
final calibPaaCalOffXProvider = StreamProvider.autoDispose<double>((ref) {
  final t = ref.watch(transportServiceProvider);
  return t
      .subscribeAs<ScalarFT>(CalibChannels.paaCalOffX, ScalarFT.decode, throttle: kUiSensorSampleRate)
      .map((d) => d.value.value);
});

final calibPaaCalOffYProvider = StreamProvider.autoDispose<double>((ref) {
  final t = ref.watch(transportServiceProvider);
  return t
      .subscribeAs<ScalarFT>(CalibChannels.paaCalOffY, ScalarFT.decode, throttle: kUiSensorSampleRate)
      .map((d) => d.value.value);
});

// ── Skalierte Position (cm) ────────────────────────────────────────

final calibPaaPosXProvider = StreamProvider.autoDispose<double>((ref) {
  final t = ref.watch(transportServiceProvider);
  return t
      .subscribeAs<ScalarFT>(CalibChannels.paaPosCmX, ScalarFT.decode, throttle: kUiSensorSampleRate)
      .map((d) => d.value.value);
});

final calibPaaPosYProvider = StreamProvider.autoDispose<double>((ref) {
  final t = ref.watch(transportServiceProvider);
  return t
      .subscribeAs<ScalarFT>(CalibChannels.paaPosCmY, ScalarFT.decode, throttle: kUiSensorSampleRate)
      .map((d) => d.value.value);
});

// ── Command-Publisher Helper ───────────────────────────────────────
// Konkret: Calibration setzen + Position-Reset.

class CalibCommandPublisher {
  CalibCommandPublisher(this._ref);
  final Ref _ref;

  /// Schickt set_calibration als JSON.  Bridge parsed, sendet als CRC-
  /// geschütztes USB-Frame ans Board, Board schreibt in Flash.
  void sendSetCalibration({
    required double cxPerCm,
    required double cyPerCm,
    required double heightMm,
  }) {
    final t = _ref.read(transportServiceProvider);
    final json =
        '{"cx_per_cm":${cxPerCm.toStringAsFixed(4)},'
        '"cy_per_cm":${cyPerCm.toStringAsFixed(4)},'
        '"height_mm":${heightMm.toStringAsFixed(2)}}';
    t.publish(
      CalibChannels.cmdPaaSetCal,
      StringT(timestamp: DateTime.now().microsecondsSinceEpoch, value: json),
    );
  }

  /// Schickt den PAA-Montageoffset (mm vom Drehzentrum) als JSON.  Bridge
  /// parsed, sendet als CRC-Frame ans Board, Board schreibt in Flash.
  void sendSetOffset({
    required double offXmm,
    required double offYmm,
  }) {
    final t = _ref.read(transportServiceProvider);
    final json =
        '{"off_x_mm":${offXmm.toStringAsFixed(2)},'
        '"off_y_mm":${offYmm.toStringAsFixed(2)}}';
    t.publish(
      CalibChannels.cmdPaaSetOffset,
      StringT(timestamp: DateTime.now().microsecondsSinceEpoch, value: json),
    );
  }

  void sendResetPosition() {
    final t = _ref.read(transportServiceProvider);
    t.publish(
      CalibChannels.cmdPaaResetPos,
      ScalarI32T(timestamp: DateTime.now().microsecondsSinceEpoch, value: 1),
    );
  }

  void sendSaveGyroBias() {
    final t = _ref.read(transportServiceProvider);
    t.publish(
      CalibChannels.cmdIcmSaveBias,
      ScalarI32T(timestamp: DateTime.now().microsecondsSinceEpoch, value: 1),
    );
  }

  void sendResetGyroBias() {
    final t = _ref.read(transportServiceProvider);
    t.publish(
      CalibChannels.cmdIcmResetBias,
      ScalarI32T(timestamp: DateTime.now().microsecondsSinceEpoch, value: 1),
    );
  }

  void sendOdomReset() {
    final t = _ref.read(transportServiceProvider);
    t.publish(
      CalibChannels.cmdOdomReset,
      ScalarI32T(timestamp: DateTime.now().microsecondsSinceEpoch, value: 1),
    );
  }
}

final calibCommandPublisherProvider = Provider<CalibCommandPublisher>(
  (ref) => CalibCommandPublisher(ref),
);

// ── ICM Fusion / Orientation Streams ────────────────────────────────

class IcmEuler {
  final double roll, pitch, yaw;
  const IcmEuler({required this.roll, required this.pitch, required this.yaw});
}

class IcmQuat {
  final double w, x, y, z;
  const IcmQuat({required this.w, required this.x, required this.y, required this.z});
}

final calibIcmEulerRollProvider = StreamProvider.autoDispose<double>((ref) {
  final t = ref.watch(transportServiceProvider);
  return t.subscribeAs<ScalarFT>(CalibChannels.icmEulerRoll, ScalarFT.decode, throttle: kUiSensorSampleRate)
      .map((d) => d.value.value);
});
final calibIcmEulerPitchProvider = StreamProvider.autoDispose<double>((ref) {
  final t = ref.watch(transportServiceProvider);
  return t.subscribeAs<ScalarFT>(CalibChannels.icmEulerPitch, ScalarFT.decode, throttle: kUiSensorSampleRate)
      .map((d) => d.value.value);
});
final calibIcmEulerYawProvider = StreamProvider.autoDispose<double>((ref) {
  final t = ref.watch(transportServiceProvider);
  return t.subscribeAs<ScalarFT>(CalibChannels.icmEulerYaw, ScalarFT.decode, throttle: kUiSensorSampleRate)
      .map((d) => d.value.value);
});

final calibIcmQuatWProvider = StreamProvider.autoDispose<double>((ref) {
  final t = ref.watch(transportServiceProvider);
  return t.subscribeAs<ScalarFT>(CalibChannels.icmQuatW, ScalarFT.decode, throttle: kUiSensorSampleRate)
      .map((d) => d.value.value);
});
final calibIcmQuatXProvider = StreamProvider.autoDispose<double>((ref) {
  final t = ref.watch(transportServiceProvider);
  return t.subscribeAs<ScalarFT>(CalibChannels.icmQuatX, ScalarFT.decode, throttle: kUiSensorSampleRate)
      .map((d) => d.value.value);
});
final calibIcmQuatYProvider = StreamProvider.autoDispose<double>((ref) {
  final t = ref.watch(transportServiceProvider);
  return t.subscribeAs<ScalarFT>(CalibChannels.icmQuatY, ScalarFT.decode, throttle: kUiSensorSampleRate)
      .map((d) => d.value.value);
});
final calibIcmQuatZProvider = StreamProvider.autoDispose<double>((ref) {
  final t = ref.watch(transportServiceProvider);
  return t.subscribeAs<ScalarFT>(CalibChannels.icmQuatZ, ScalarFT.decode, throttle: kUiSensorSampleRate)
      .map((d) => d.value.value);
});

final calibIcmGyroCorrProvider = StreamProvider.autoDispose<Vector3fT>((ref) {
  final t = ref.watch(transportServiceProvider);
  return t.subscribeAs<Vector3fT>(CalibChannels.icmGyroCorr, Vector3fT.decode, throttle: kUiSensorSampleRate)
      .map((d) => d.value);
});

final calibIcmGyroBiasProvider = StreamProvider.autoDispose<Vector3fT>((ref) {
  final t = ref.watch(transportServiceProvider);
  return t.subscribeAs<Vector3fT>(CalibChannels.icmGyroBias, Vector3fT.decode, throttle: kUiSensorSampleRate)
      .map((d) => d.value);
});

final calibIcmAtRestProvider = StreamProvider.autoDispose<bool>((ref) {
  final t = ref.watch(transportServiceProvider);
  return t.subscribeAs<ScalarI32T>(CalibChannels.icmAtRest, ScalarI32T.decode, throttle: kUiSensorSampleRate)
      .map((d) => d.value.value != 0);
});

final calibIcmBiasPersistedProvider = StreamProvider.autoDispose<bool>((ref) {
  final t = ref.watch(transportServiceProvider);
  return t.subscribeAs<ScalarI32T>(CalibChannels.icmBiasValid, ScalarI32T.decode, throttle: kUiSensorSampleRate)
      .map((d) => d.value.value != 0);
});

// ── Odometrie ───────────────────────────────────────────────────────

final calibOdomPosXProvider = StreamProvider.autoDispose<double>((ref) {
  final t = ref.watch(transportServiceProvider);
  return t.subscribeAs<ScalarFT>(CalibChannels.odomPosX, ScalarFT.decode, throttle: kUiSensorSampleRate)
      .map((d) => d.value.value);
});
final calibOdomPosYProvider = StreamProvider.autoDispose<double>((ref) {
  final t = ref.watch(transportServiceProvider);
  return t.subscribeAs<ScalarFT>(CalibChannels.odomPosY, ScalarFT.decode, throttle: kUiSensorSampleRate)
      .map((d) => d.value.value);
});
final calibOdomHeadingProvider = StreamProvider.autoDispose<double>((ref) {
  final t = ref.watch(transportServiceProvider);
  return t.subscribeAs<ScalarFT>(CalibChannels.odomHeading, ScalarFT.decode, throttle: kUiSensorSampleRate)
      .map((d) => d.value.value);
});
