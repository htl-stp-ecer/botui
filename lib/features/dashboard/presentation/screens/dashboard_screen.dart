import 'package:stpvelox/core/router/safe_navigation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/application/overview/overview_settings_provider.dart';
import 'package:stpvelox/application/theme/color_theme_provider.dart';
import 'package:stpvelox/core/theme/app_theme.dart';
import 'package:stpvelox/core/router/app_router.dart';
import 'package:stpvelox/core/utils/colors/colors.dart';
import 'package:stpvelox/core/utils/radii.dart';
import 'package:stpvelox/core/utils/spacing.dart';
import 'package:stpvelox/features/dashboard/presentation/widgets/overview_section.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final side = ref.watch(overviewSideProvider);
    final menu = Column(
      children: [
        Expanded(
          flex: 1,
          child: _DashboardTile(
            index: 0,
          label: "Sensors & Actors",
            icon: Icons.sensors,
            route: AppRoutes.sensors,
            color: TileColor.blue,
            borderRadius: const BorderRadius.vertical(
              top: AppRadii.outerRadius,
              bottom: AppRadii.innerRadius,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.tileGap),
        Expanded(
          flex: 1,
          child: _DashboardTile(
            index: 1,
          label: "Programs",
            icon: Icons.code,
            route: AppRoutes.programs,
            color: TileColor.green,
            borderRadius: const BorderRadius.all(AppRadii.innerRadius),
          ),
        ),
        const SizedBox(height: AppSpacing.tileGap),
        Expanded(
          flex: 1,
          child: _DashboardTile(
            index: 2,
          label: "Settings",
            icon: Icons.settings,
            route: AppRoutes.settings,
            color: TileColor.orange,
            borderRadius: const BorderRadius.vertical(
              top: AppRadii.innerRadius,
              bottom: AppRadii.outerRadius,
            ),
          ),
        ),
      ],
    );

    // 50:50 split; the overview takes the configured half, the menu the other.
    // With the overview off the menu fills the whole screen.
    final Widget content;
    if (side == OverviewSide.off) {
      content = menu;
    } else {
      const overview = OverviewSection();
      final isPortrait =
          MediaQuery.orientationOf(context) == Orientation.portrait;
      // Landscape: side by side, overview left or right. Portrait: stacked;
      // the stored "right" becomes top and "left" becomes bottom.
      final overviewFirst =
          isPortrait ? side == OverviewSide.right : side == OverviewSide.left;
      final halves = overviewFirst ? [overview, menu] : [menu, overview];
      final children = <Widget>[
        Expanded(child: halves[0]),
        isPortrait
            ? const SizedBox(height: AppSpacing.tileGap)
            : const SizedBox(width: AppSpacing.tileGap),
        Expanded(child: halves[1]),
      ];
      content = isPortrait ? Column(children: children) : Row(children: children);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: content,
        ),
      ),
    );
  }
}

/// Dashboard tile that navigates using go_router
class _DashboardTile extends ConsumerWidget {
  final String label;
  final IconData icon;
  final String route;
  final TileColor color;
  final BorderRadius borderRadius;
  final int index;

  const _DashboardTile({
    required this.label,
    required this.icon,
    required this.route,
    required this.color,
    required this.borderRadius,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(colorThemeProvider);
    final tileColor = theme.tileColor(color, index);
    final fg = theme.textColor;
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: () => context.pushOnce(route),
        child: Container(
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: borderRadius,
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                offset: Offset(0, 4),
                blurRadius: 6,
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 50,
                  color: fg,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontSize: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
