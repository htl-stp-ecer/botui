import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/application/theme/color_theme_provider.dart';
import 'package:stpvelox/core/theme/app_theme.dart';
import 'package:stpvelox/core/widgets/tile_position.dart';

class ResponsiveGridTile extends ConsumerWidget {
  final String label;
  final IconData icon;
  final void Function() onPressed;
  final TileColor color;

  const ResponsiveGridTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color = TileColor.grey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(colorThemeProvider);
    final tileColor = theme.tileColor(color, TilePosition.maybeOf(context));
    final fg = theme.textColor;
    return GestureDetector(
        onTap: onPressed,
        child: Container(
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: fg,
                size: 100,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(color: fg, fontSize: 18),
              )
            ],
          ),
        ),
      );
  }
}
