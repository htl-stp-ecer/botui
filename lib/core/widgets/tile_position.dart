import 'package:flutter/widgets.dart';

/// The position (0-based) of a tile within its group, e.g. its index in a
/// [ResponsiveGrid]. Color themes use it to pick the tile's color.
class TilePosition extends InheritedWidget {
  final int index;

  const TilePosition({super.key, required this.index, required super.child});

  static int? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TilePosition>()?.index;

  @override
  bool updateShouldNotify(TilePosition old) => index != old.index;
}
