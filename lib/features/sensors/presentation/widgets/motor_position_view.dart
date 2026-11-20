import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/application/theme/color_theme_provider.dart';
import 'package:stpvelox/core/theme/app_theme.dart';

class MotorPositionView extends ConsumerWidget {
  final String posDisplay;
  final int velocity;
  final bool isRelative;
  final int? motorPosition;
  final bool? motorDone;
  final void Function(String) onKeyPress;
  final VoidCallback onToggleSign, onClear, onVelocityUp, onVelocityDown;
  final ValueChanged<bool> onToggleRelative;
  final VoidCallback onSubmit;

  const MotorPositionView({
    super.key,
    required this.posDisplay,
    required this.velocity,
    required this.isRelative,
    required this.motorPosition,
    required this.motorDone,
    required this.onKeyPress,
    required this.onToggleSign,
    required this.onClear,
    required this.onVelocityUp,
    required this.onVelocityDown,
    required this.onToggleRelative,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(colorThemeProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: [
          // ── Position display ──
          _PositionDisplay(
            posDisplay: posDisplay,
            isRelative: isRelative,
            onClear: onClear,
          ),
          const SizedBox(height: 6),

          // ── Settings row: ABS/REL + Velocity + GO ──
          SizedBox(
            height: 52,
            child: Row(
              children: [
                // ABS / REL toggle
                _ModeToggle(
                  isRelative: isRelative,
                  onToggle: onToggleRelative,
                ),
                const SizedBox(width: 8),
                // Velocity stepper
                _VelocityStepper(
                  velocity: velocity,
                  onUp: onVelocityUp,
                  onDown: onVelocityDown,
                ),
                const SizedBox(width: 8),
                // GO button
                Expanded(
                  flex: 2,
                  child: SizedBox.expand(
                    child: ElevatedButton.icon(
                      onPressed: onSubmit,
                      icon: const Icon(Icons.play_arrow_rounded, size: 28),
                      label: const Text(
                        'GO',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.tileColor(TileColor.green, null),
                        foregroundColor: theme.textColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // ── Numpad ──
          Expanded(
            child: _Numpad(
              onKeyPress: onKeyPress,
              onToggleSign: onToggleSign,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Position display bar ────────────────────────────────────

class _PositionDisplay extends ConsumerWidget {
  final String posDisplay;
  final bool isRelative;
  final VoidCallback onClear;

  const _PositionDisplay({
    required this.posDisplay,
    required this.isRelative,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(colorThemeProvider);
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Mode indicator chip
          Container(
            width: 48,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(9),
                bottomLeft: Radius.circular(9),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              isRelative ? 'REL' : 'ABS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: isRelative
                    ? theme.tileColor(TileColor.orange, null)
                    : theme.tileColor(TileColor.blue, null),
              ),
            ),
          ),
          // Display value
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                posDisplay,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  color: Colors.white,
                ),
              ),
            ),
          ),
          // Clear button
          GestureDetector(
            onTap: onClear,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 52,
              height: double.infinity,
              decoration: BoxDecoration(
                color: theme.tileColor(TileColor.orange, null).withValues(alpha: 0.2),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(9),
                  bottomRight: Radius.circular(9),
                ),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.clear_rounded,
                  size: 22, color: theme.tileColor(TileColor.orange, null)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ABS / REL toggle ────────────────────────────────────────

class _ModeToggle extends ConsumerWidget {
  final bool isRelative;
  final ValueChanged<bool> onToggle;

  const _ModeToggle({required this.isRelative, required this.onToggle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(colorThemeProvider);
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeBtn(
            label: 'ABS',
            active: !isRelative,
            color: theme.tileColor(TileColor.blue, null),
            onTap: () => onToggle(false),
            isLeft: true,
          ),
          _ModeBtn(
            label: 'REL',
            active: isRelative,
            color: theme.tileColor(TileColor.orange, null),
            onTap: () => onToggle(true),
            isLeft: false,
          ),
        ],
      ),
    );
  }
}

class _ModeBtn extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  final bool isLeft;

  const _ModeBtn({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 56,
        height: 50,
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.25) : Colors.grey[900],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: active ? color : Colors.grey[600],
          ),
        ),
      ),
    );
  }
}

// ─── Velocity stepper ────────────────────────────────────────

class _VelocityStepper extends StatelessWidget {
  final int velocity;
  final VoidCallback onUp, onDown;

  const _VelocityStepper({
    required this.velocity,
    required this.onUp,
    required this.onDown,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      height: 52,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Down button
          GestureDetector(
            onTap: onDown,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 44,
              height: double.infinity,
              color: Colors.grey[800],
              alignment: Alignment.center,
              child:
                  Icon(Icons.remove_rounded, size: 20, color: Colors.grey[400]),
            ),
          ),
          // Value display
          Container(
            width: 72,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'VEL',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: Colors.grey[500],
                  ),
                ),
                Text(
                  '$velocity',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // Up button
          GestureDetector(
            onTap: onUp,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 44,
              height: double.infinity,
              color: Colors.grey[800],
              alignment: Alignment.center,
              child:
                  Icon(Icons.add_rounded, size: 20, color: Colors.grey[400]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Full-width numpad ───────────────────────────────────────

class _Numpad extends StatelessWidget {
  final void Function(String) onKeyPress;
  final VoidCallback onToggleSign;

  const _Numpad({required this.onKeyPress, required this.onToggleSign});

  @override
  Widget build(BuildContext context) {
    const gap = 4.0;
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['+/-', '0', 'back'],
    ];

    return Column(
      children: [
        for (int r = 0; r < rows.length; r++) ...[
          if (r > 0) const SizedBox(height: gap),
          Expanded(
            child: Row(
              children: [
                for (int c = 0; c < rows[r].length; c++) ...[
                  if (c > 0) const SizedBox(width: gap),
                  Expanded(
                    child: _NumKey(
                      label: rows[r][c],
                      onTap: rows[r][c] == '+/-'
                          ? onToggleSign
                          : () => onKeyPress(rows[r][c]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _NumKey extends ConsumerWidget {
  final String label;
  final VoidCallback onTap;

  const _NumKey({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(colorThemeProvider);
    final isSpecial = label == '+/-' || label == 'back';

    return Material(
      color: isSpecial ? Colors.grey[800] : Colors.grey.shade900,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        splashColor: theme.tileColor(TileColor.blue, null).withValues(alpha: 0.2),
        child: Center(
          child: label == 'back'
              ? Icon(Icons.backspace_outlined,
                  size: 24, color: theme.tileColor(TileColor.orange, null))
              : label == '+/-'
                  ? Text(
                      '+/\u2212',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[300],
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
        ),
      ),
    );
  }
}
