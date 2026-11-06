import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/application/theme/color_theme_provider.dart';
import 'package:stpvelox/core/theme/app_theme.dart';

/// Auto Scale / Fixed toggle for the graph screens' top bar.
///
/// The color is the active color theme's "blue" slot (so a pattern theme like
/// raccoon turns it gold, etc.) and is the same in both modes; only the label
/// changes. It is compact (60 px high) so it doesn't touch the top and bottom
/// edges of the top bar; the app's default button theme is 80 px tall.
class AutoScaleAction extends ConsumerWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const AutoScaleAction(
      {super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(colorThemeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ElevatedButton(
        onPressed: () => onChanged(!value),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.tileColor(TileColor.blue, 0),
          foregroundColor: theme.textColor,
          minimumSize: const Size(0, 60),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(
          value ? 'Auto Scale' : 'Fixed',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
