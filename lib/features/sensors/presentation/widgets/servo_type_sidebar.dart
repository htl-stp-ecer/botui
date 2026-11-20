import 'package:flutter/material.dart';

/// Which kind of servo sits on the port: a classic PWM servo or a Feetech
/// STS serial bus servo (e.g. STS3215, servo mode 3).
enum ServoType { pwm, bus }

class ServoTypeSidebar extends StatelessWidget {
  final ServoType selected;
  final ValueChanged<ServoType> onSelect;

  const ServoTypeSidebar({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  static const _types = [
    (ServoType.pwm, Icons.settings_input_component, 'PWM'),
    (ServoType.bus, Icons.cable, 'BUS'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: Column(
        children: _types.map((t) => _buildBtn(t.$1, t.$2, t.$3)).toList(),
      ),
    );
  }

  Widget _buildBtn(ServoType type, IconData icon, String label) {
    final active = selected == type;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(type),
        child: Container(
          width: 100,
          color: active ? Colors.blue : Colors.grey[900],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 28, color: active ? Colors.white : Colors.grey[600]),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: active ? Colors.white : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
