/// Converts the battery voltage into a rough percentage (linear).
///
/// ASSUMPTION: [emptyVoltage] matches the low-battery warning threshold in
/// `battery_check_service.dart`, and [fullVoltage] assumes a 2S Li-ion/LiPo
/// pack (8.4 V). Adjust if the real pack differs; a real discharge curve is
/// not linear.
class BatteryLevel {
  BatteryLevel._();

  static const double emptyVoltage = 5.75;
  static const double fullVoltage = 8.4;

  static int percentFromVoltage(double voltage) {
    final fraction = (voltage - emptyVoltage) / (fullVoltage - emptyVoltage);
    return (fraction.clamp(0.0, 1.0) * 100).round();
  }
}
