import 'dart:math' as math;

import 'package:flutter/material.dart';

class NumericKeypadWidget extends StatelessWidget {
  final void Function(String key) onKeyPress;

  const NumericKeypadWidget({
    super.key,
    required this.onKeyPress,
  });

  // 3 columns × 4 rows keypad layout.
  static const int _cols = 3;
  static const int _rows = 4;

  // Fallback cell size used when a dimension is unbounded (e.g. the keypad
  // lives inside a shrink-wrapping Column/Row). Keeps the old look intact.
  static const double _fallbackCellW = 80; // 72 button + 8 gap
  static const double _fallbackCellH = 64; // 56 button + 8 gap

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Grow each cell to fill the available space; fall back to a fixed
        // size along any axis that is unbounded so the layout stays valid.
        final double cellW = constraints.maxWidth.isFinite
            ? constraints.maxWidth / _cols
            : _fallbackCellW;
        final double cellH = constraints.maxHeight.isFinite
            ? constraints.maxHeight / _rows
            : _fallbackCellH;

        Widget cell(_KeypadButton button) => SizedBox(
              width: cellW,
              height: cellH,
              child: button,
            );

        Widget row(List<_KeypadButton> buttons) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: buttons.map(cell).toList(),
            );

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            row([
              _KeypadButton(label: '1', onTap: () => onKeyPress('1')),
              _KeypadButton(label: '2', onTap: () => onKeyPress('2')),
              _KeypadButton(label: '3', onTap: () => onKeyPress('3')),
            ]),
            row([
              _KeypadButton(label: '4', onTap: () => onKeyPress('4')),
              _KeypadButton(label: '5', onTap: () => onKeyPress('5')),
              _KeypadButton(label: '6', onTap: () => onKeyPress('6')),
            ]),
            row([
              _KeypadButton(label: '7', onTap: () => onKeyPress('7')),
              _KeypadButton(label: '8', onTap: () => onKeyPress('8')),
              _KeypadButton(label: '9', onTap: () => onKeyPress('9')),
            ]),
            row([
              _KeypadButton(label: '.', onTap: () => onKeyPress('.')),
              _KeypadButton(label: '0', onTap: () => onKeyPress('0')),
              _KeypadButton(
                icon: Icons.backspace_outlined,
                onTap: () => onKeyPress('back'),
                color: Colors.orange,
              ),
            ]),
          ],
        );
      },
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final Color? color;

  const _KeypadButton({
    this.label,
    this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Scale glyph size to the cell so bigger keypads get bigger labels,
        // while staying sensible when the cell shrinks.
        final double shortest = math.min(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 72,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 56,
        );
        final double glyphSize = (shortest * 0.45).clamp(20.0, 64.0);

        return Padding(
          padding: const EdgeInsets.all(4),
          child: Material(
            color: Colors.grey.shade800,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              splashColor: Colors.white24,
              child: Container(
                alignment: Alignment.center,
                child: icon != null
                    ? Icon(icon, size: glyphSize, color: color ?? Colors.white)
                    : Text(
                        label ?? '',
                        style: TextStyle(
                          fontSize: glyphSize,
                          fontWeight: FontWeight.bold,
                          color: color ?? Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}
