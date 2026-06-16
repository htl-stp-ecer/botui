/// Channel names published by the host-side `raccoon-calib-bridge`
/// (siehe `calibration-board/host/src/calib_bridge/Channels.h` — Single
/// source of truth dort).  Wir spiegeln sie hier statt sie in das
/// raccoon-transport Submodule zu schieben, damit der UI-Patch eigen-
/// ständig deploybar bleibt.
class CalibChannels {
  CalibChannels._();

  // ICM-42688-P — 6-axis IMU
  static const icmAccel       = 'raccoon/calib_board/icm/accel';        // vector3f_t [g]
  static const icmGyro        = 'raccoon/calib_board/icm/gyro';         // vector3f_t [dps]
  static const icmTemperature = 'raccoon/calib_board/icm/temperature';  // scalar_f_t [°C]

  // PAA5100 — optical flow
  static const paaDeltaX  = 'raccoon/calib_board/paa/delta_x';   // scalar_i32_t
  static const paaDeltaY  = 'raccoon/calib_board/paa/delta_y';   // scalar_i32_t
  static const paaSqual   = 'raccoon/calib_board/paa/squal';     // scalar_i32_t
  static const paaShutter = 'raccoon/calib_board/paa/shutter';   // scalar_i32_t
  static const paaMotion  = 'raccoon/calib_board/paa/motion';    // scalar_i32_t

  // Board-seitig integrierter signed Counts-Akkumulator (frei laufend).
  // Der Host akkumuliert NICHT — der Kalibrier-Wizard nimmt Differenzen.
  static const paaAccX    = 'raccoon/calib_board/paa/acc_x';     // scalar_i32_t (counts)
  static const paaAccY    = 'raccoon/calib_board/paa/acc_y';     // scalar_i32_t (counts)

  // Status (string_t)
  //   board: "connected" / "disconnected"
  //   port : "/dev/ttyACMn" / "(none)"
  //   icm  : "ok" / "init_failed:<reason>" / "no_frames_yet" / "board_disconnected"
  //   paa  : "connected" / "absent" / "init_failed:<reason>" / "board_disconnected"
  //   stats: JSON-Zeile (Counter)
  static const statusBoard = 'raccoon/calib_board/status/board';
  static const statusPort  = 'raccoon/calib_board/status/port';
  static const statusIcm   = 'raccoon/calib_board/status/icm';
  static const statusPaa   = 'raccoon/calib_board/status/paa';
  static const statusStats = 'raccoon/calib_board/status/stats';

  // PAA-Kalibrierung (Telemetry vom FW, vom Bridge republisht)
  static const paaCalCx     = 'raccoon/calib_board/paa/cal/cx_per_cm';   // scalar_f_t
  static const paaCalCy     = 'raccoon/calib_board/paa/cal/cy_per_cm';   // scalar_f_t
  static const paaCalHeight = 'raccoon/calib_board/paa/cal/height_mm';   // scalar_f_t
  static const paaCalValid  = 'raccoon/calib_board/paa/cal/valid';       // scalar_i32_t (0/1)
  // PAA-Montageoffset vom Drehzentrum (mm, Body-Frame)
  static const paaCalOffX   = 'raccoon/calib_board/paa/cal/off_x_mm';    // scalar_f_t
  static const paaCalOffY   = 'raccoon/calib_board/paa/cal/off_y_mm';    // scalar_f_t

  // Skalierte PAA-Werte (Bridge wendet Kalibrierung an)
  static const paaCmX     = 'raccoon/calib_board/paa/cm/dx';     // scalar_f_t [cm/sample]
  static const paaCmY     = 'raccoon/calib_board/paa/cm/dy';     // scalar_f_t [cm/sample]
  static const paaPosCmX  = 'raccoon/calib_board/paa/cm/pos_x';  // scalar_f_t [cm]
  static const paaPosCmY  = 'raccoon/calib_board/paa/cm/pos_y';  // scalar_f_t [cm]

  // ── ICM Fusion / Orientation (100 Hz Madgwick @ FW) ──────────────
  static const icmQuatW       = 'raccoon/calib_board/icm/quat/w';        // scalar_f_t
  static const icmQuatX       = 'raccoon/calib_board/icm/quat/x';
  static const icmQuatY       = 'raccoon/calib_board/icm/quat/y';
  static const icmQuatZ       = 'raccoon/calib_board/icm/quat/z';
  static const icmEulerRoll   = 'raccoon/calib_board/icm/euler/roll';    // scalar_f_t deg
  static const icmEulerPitch  = 'raccoon/calib_board/icm/euler/pitch';
  static const icmEulerYaw    = 'raccoon/calib_board/icm/euler/yaw';
  static const icmGyroCorr    = 'raccoon/calib_board/icm/gyro_corrected'; // vector3f_t dps
  static const icmGyroBias    = 'raccoon/calib_board/icm/gyro_bias';      // vector3f_t dps
  static const icmAtRest      = 'raccoon/calib_board/icm/at_rest';        // scalar_i32_t 0/1
  static const icmBiasValid   = 'raccoon/calib_board/icm/bias_persisted'; // scalar_i32_t 0/1

  // ── Odometrie (Bridge: PAA + Quaternion fusion) ──────────────────
  static const odomPosX    = 'raccoon/calib_board/odom/pos_x';   // scalar_f_t cm world
  static const odomPosY    = 'raccoon/calib_board/odom/pos_y';   // scalar_f_t cm world
  static const odomHeading = 'raccoon/calib_board/odom/heading'; // scalar_f_t deg

  // Command-Channels (UI → Bridge → FW)
  static const cmdPaaSetCal       = 'raccoon/calib_board/cmd/paa/set_calibration'; // string_t JSON
  static const cmdPaaSetOffset    = 'raccoon/calib_board/cmd/paa/set_offset';      // string_t JSON
  static const cmdPaaResetPos     = 'raccoon/calib_board/cmd/paa/reset_position';  // scalar_i32_t
  static const cmdIcmSaveBias     = 'raccoon/calib_board/cmd/icm/save_gyro_bias';  // trigger
  static const cmdIcmResetBias    = 'raccoon/calib_board/cmd/icm/reset_gyro_bias'; // trigger
  static const cmdOdomReset       = 'raccoon/calib_board/cmd/odom/reset';          // trigger
}
