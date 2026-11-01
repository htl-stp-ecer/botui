import 'package:flutter/material.dart';
import 'package:stpvelox/core/utils/spacing.dart';
import 'package:stpvelox/core/widgets/tile_position.dart';

class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double maxTileWidth;
  final double crossAxisSpacing;
  final double mainAxisSpacing;

  /// Defaults to the same gap as between the tiles.
  final EdgeInsets? padding;
  final double? childAspectRatio;
  final bool isScrollable;
  final int? crossAxisCount;

  /// Shrink the tile height so all rows fit without scrolling (when
  /// [childAspectRatio] is not set). Turn off for long, scrolling lists whose
  /// tiles need to stay square.
  final bool fitToHeight;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.maxTileWidth = 150,
    this.crossAxisSpacing = AppSpacing.tileGap,
    this.mainAxisSpacing = AppSpacing.tileGap,
    this.padding,
    this.childAspectRatio,
    this.isScrollable = true,
    this.crossAxisCount,
    this.fitToHeight = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int calculatedCrossAxisCount =
            (constraints.maxWidth / (maxTileWidth + crossAxisSpacing)).floor();

        calculatedCrossAxisCount =
            calculatedCrossAxisCount > 0 ? calculatedCrossAxisCount : 1;

        final cols = crossAxisCount ?? calculatedCrossAxisCount;
        final pad = padding ??
            EdgeInsets.symmetric(
                horizontal: crossAxisSpacing, vertical: mainAxisSpacing);

        return GridView.builder(
          padding: pad,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: crossAxisSpacing,
            mainAxisSpacing: mainAxisSpacing,
            childAspectRatio: childAspectRatio ??
                (fitToHeight ? _fittingAspectRatio(constraints, cols, pad) : 1),
          ),
          itemCount: children.length,
          itemBuilder: (context, index) =>
              TilePosition(index: index, child: children[index]),
          physics: isScrollable
              ? const AlwaysScrollableScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          shrinkWrap: !isScrollable,
        );
      },
    );
  }

  /// Square tiles, unless that makes the grid taller than the available
  /// height: then the tiles get just short enough for all rows to fit without
  /// scrolling. If that would squash them noticeably (more than 10%), stay square and
  /// scroll, e.g. for long lists like the digital ports.
  double _fittingAspectRatio(BoxConstraints c, int cols, EdgeInsets pad) {
    if (!c.hasBoundedHeight || children.isEmpty) return 1;
    final rows = (children.length / cols).ceil();
    final tileWidth =
        (c.maxWidth - pad.horizontal - (cols - 1) * crossAxisSpacing) / cols;
    final fitHeight =
        (c.maxHeight - pad.vertical - (rows - 1) * mainAxisSpacing) / rows;
    if (tileWidth <= 0 || fitHeight >= tileWidth) return 1;
    const minRatio = 0.9; // tile height / width
    return fitHeight / tileWidth >= minRatio ? tileWidth / fitHeight : 1;
  }
}
