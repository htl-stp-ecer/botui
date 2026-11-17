import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/application/theme/color_theme_provider.dart';
import 'package:stpvelox/core/theme/app_theme.dart';

/// One button of a [TwoButtonStrip].
class StripButton {
  const StripButton({
    required this.label,
    required this.icon,
    required this.slot,
    this.onTap,
  });

  final String label;
  final IconData icon;

  /// The theme color the button takes (like the tiles of the other menus).
  final TileColor slot;

  /// Null: the button is shown disabled.
  final VoidCallback? onTap;
}

/// A card with a title and a row of buttons, in the style of the "Network
/// Mode" card of the Wi-Fi screen. Meant for two buttons, works for more.
class TwoButtonStrip extends ConsumerWidget {
  const TwoButtonStrip({
    super.key,
    required this.title,
    required this.buttons,
    this.height = 134,
  });

  final String title;
  final List<StripButton> buttons;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: height,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF11161C),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                children: [
                  for (var i = 0; i < buttons.length; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: i == buttons.length - 1 ? 0 : 10,
                        ),
                        child: _StripButtonView(button: buttons[i], index: i),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StripButtonView extends ConsumerWidget {
  const _StripButtonView({required this.button, required this.index});

  final StripButton button;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent =
        ref.watch(colorThemeProvider).tileColor(button.slot, index);
    final enabled = button.onTap != null;

    return Opacity(
      opacity: enabled ? 1 : 0.65,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: button.onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              color: const Color(0xFF1A212A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(button.icon, color: accent, size: 28),
                  const SizedBox(height: 6),
                  Text(
                    button.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
