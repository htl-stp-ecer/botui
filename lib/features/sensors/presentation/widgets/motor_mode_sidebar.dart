import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/application/theme/color_theme_provider.dart';
import 'package:stpvelox/core/theme/app_theme.dart';

enum MotorMode { power, velocity, position, graph }

class MotorModeSidebar extends ConsumerWidget {
  final MotorMode selected;
  final ValueChanged<MotorMode> onSelect;

  const MotorModeSidebar({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  static const _modes = [
    (MotorMode.power, Icons.flash_on, 'POWER'),
    (MotorMode.velocity, Icons.speed, 'VEL'),
    (MotorMode.position, Icons.pin_drop, 'POS'),
    (MotorMode.graph, Icons.show_chart, 'GRAPH'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(colorThemeProvider);
    return SizedBox(
      width: 100,
      child: Column(
        children: _modes
            .map((m) => _buildBtn(theme, m.$1, m.$2, m.$3))
            .toList(),
      ),
    );
  }

  Widget _buildBtn(AppTheme theme, MotorMode mode, IconData icon, String label) {
    final active = selected == mode;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(mode),
        child: Container(
          width: 100,
          color: active
              ? theme.tileColor(TileColor.blue, null)
              : Colors.grey[900],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 28,
                  color: active ? theme.textColor : Colors.grey[600]),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: active ? theme.textColor : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
