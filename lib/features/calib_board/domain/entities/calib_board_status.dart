/// Liveness-Status der drei Sensoren auf dem Calibration-Board.  Wird
/// aus den string_t Status-Channels des Host-Brückens aggregiert.
enum CalibSensorState {
  /// Bridge meldet aktiv "ok"/"connected" für diesen Sensor.
  ok,

  /// Bridge meldet Init-Fehler oder "absent" — Sensor antwortet nicht.
  unavailable,

  /// Wir wissen noch nichts (Bridge nicht erreicht, Channel still).
  unknown,
}

class CalibBoardStatus {
  /// True wenn die Bridge "connected" auf dem board-Channel publisht.
  /// False wenn explicit "disconnected" oder noch kein Wert.
  final bool boardConnected;

  /// `/dev/ttyACMn` oder `"(none)"`.  Hilfreich fürs Debugging.
  final String port;

  final CalibSensorState icm;
  final CalibSensorState paa;

  /// BNO ist auf der aktuellen Hardware tot — die Bridge sendet keinen
  /// BNO-Channel.  Hier hart `unavailable`, bis (a) der Chip getauscht
  /// und (b) die Bridge BNO-Daten zu publishen anfängt.
  final CalibSensorState bno;

  /// Rohstring der zuletzt empfangenen ICM-/PAA-Status-Meldung — für
  /// Tooltip / Detail-Anzeige.
  final String icmDetail;
  final String paaDetail;

  const CalibBoardStatus({
    required this.boardConnected,
    required this.port,
    required this.icm,
    required this.paa,
    required this.bno,
    required this.icmDetail,
    required this.paaDetail,
  });

  static const empty = CalibBoardStatus(
    boardConnected: false,
    port: '(unknown)',
    icm: CalibSensorState.unknown,
    paa: CalibSensorState.unknown,
    bno: CalibSensorState.unavailable,  // hardware-known-dead
    icmDetail: '',
    paaDetail: '',
  );

  CalibBoardStatus copyWith({
    bool? boardConnected,
    String? port,
    CalibSensorState? icm,
    CalibSensorState? paa,
    CalibSensorState? bno,
    String? icmDetail,
    String? paaDetail,
  }) {
    return CalibBoardStatus(
      boardConnected: boardConnected ?? this.boardConnected,
      port: port ?? this.port,
      icm: icm ?? this.icm,
      paa: paa ?? this.paa,
      bno: bno ?? this.bno,
      icmDetail: icmDetail ?? this.icmDetail,
      paaDetail: paaDetail ?? this.paaDetail,
    );
  }
}
