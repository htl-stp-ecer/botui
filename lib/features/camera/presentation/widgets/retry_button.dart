import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/application/theme/color_theme_provider.dart';
import 'package:stpvelox/core/theme/app_theme.dart';

/// The "Try again" button of the camera screens, colored by the active theme.
class RetryButton extends ConsumerWidget {
  const RetryButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(colorThemeProvider);
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: theme.tileColor(TileColor.blue, null),
        foregroundColor: theme.textColor,
      ),
      child: const Text('Try again'),
    );
  }
}
