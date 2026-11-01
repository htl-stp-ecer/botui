import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/application/theme/color_theme_provider.dart';
import 'package:stpvelox/core/theme/app_theme.dart';
import 'package:stpvelox/core/widgets/responsive_grid.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/themes.dart';

/// One tile per color theme; tapping selects it (persisted).
class ColorThemeScreen extends ConsumerWidget {
  const ColorThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(colorThemeProvider);

    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: createTopBar(context, 'Color Theme'),
      body: SafeArea(
        child: ResponsiveGrid(
          children: [
            for (final theme in appThemes)
              _ThemeTile(
                theme: theme,
                selected: theme.id == selected.id,
                onPressed: () =>
                    ref.read(colorThemeProvider.notifier).setTheme(theme.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final AppTheme theme;
  final bool selected;
  final VoidCallback onPressed;

  const _ThemeTile({
    required this.theme,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // Not resolved through the active theme: the tile shows the theme's own
    // color, so the theme previews itself.
    final fg = theme.textColor;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          color: theme.preview,
          borderRadius: BorderRadius.circular(10),
          border: selected ? Border.all(color: Colors.white, width: 3) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.palette_outlined,
              color: fg,
              size: 100,
            ),
            const SizedBox(height: 8),
            Text(theme.label, style: TextStyle(color: fg, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
