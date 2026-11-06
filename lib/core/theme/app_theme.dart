import 'package:flutter/material.dart';

/// The named color slots tiles use. Screens never hardcode a color: a tile
/// says "I am red" ([TileColor.red]) and the active theme decides what red
/// looks like (a red, a grey, a gold, ...).
enum TileColor {
  red,
  orange,
  amber,
  green,
  teal,
  cyan,
  blue,
  indigo,
  purple,
  pink,
  brown,
  blueGrey,

  /// Neutral / disabled.
  grey;

  /// For tiles that get a slot by an index (sensor categories, programs, ...).
  static const List<TileColor> sequence = [
    blue,
    green,
    orange,
    purple,
    red,
    teal,
    pink,
    indigo,
    amber,
    cyan,
  ];

  static TileColor byIndex(int i) => sequence[i % sequence.length];
}

/// A color theme. Themes are defined in `lib/themes.dart`; nothing else needs
/// to change to add or remove one.
///
/// There are two kinds:
///  * [StandardTheme]: maps every named slot ([TileColor]) to a color.
///  * [PatternTheme]: ignores the slots; the tile at position i in its group
///    gets `pattern[i % pattern.length]`.
sealed class AppTheme {
  /// Stable id, stored in the preferences. Changing it resets users to the
  /// first theme.
  final String id;

  /// Name shown in the theme picker.
  final String label;

  /// Color of icons and text on tiles.
  final Color textColor;

  /// Color of this theme's tile in the theme picker. If null, a default is
  /// derived from the theme (the blue slot, or the first pattern color).
  final Color? previewColor;

  const AppTheme({
    required this.id,
    required this.label,
    this.textColor = Colors.white,
    this.previewColor,
  });

  /// Color shown on this theme's tile in the picker.
  Color get preview => previewColor ?? defaultPreview;

  /// Fallback for [preview] when [previewColor] is not set.
  Color get defaultPreview;

  /// The color of "disabled / neutral" things. It is the same in every theme.
  static const Color disabledColor = Color(0xFF616161);

  /// True for themes that color by position (see [PatternTheme]).
  bool get isPattern => this is PatternTheme;

  /// The color of a tile that asks for [slot] and sits at [position] (0-based)
  /// in its group; [position] is null for tiles that are not in a group.
  ///
  /// [TileColor.grey] (disabled) is always [disabledColor], whatever the theme.
  Color tileColor(TileColor slot, int? position) =>
      slot == TileColor.grey ? disabledColor : themedColor(slot, position);

  /// What this theme makes of [slot] / [position]. Themes implement this;
  /// callers use [tileColor], which keeps disabled grey.
  @protected
  Color themedColor(TileColor slot, int? position);
}

class StandardTheme extends AppTheme {
  /// Slot -> color. Slots that are missing fall back to [fallback].
  final Map<TileColor, Color> colors;
  final Color fallback;

  const StandardTheme({
    required super.id,
    required super.label,
    required this.colors,
    this.fallback = const Color(0xFF616161),
    super.textColor,
    super.previewColor,
  });

  /// A theme in which every slot is the same color.
  StandardTheme.single({
    required super.id,
    required super.label,
    required Color color,
    super.textColor,
    super.previewColor,
  })  : colors = {for (final slot in TileColor.values) slot: color},
        fallback = color;

  @override
  Color get defaultPreview => colors[TileColor.blue] ?? fallback;

  @override
  Color themedColor(TileColor slot, int? position) => colors[slot] ?? fallback;
}

class PatternTheme extends AppTheme {
  /// The colors, in order. Should not be empty (an empty pattern falls back
  /// to grey).
  final List<Color> pattern;

  const PatternTheme({
    required super.id,
    required super.label,
    required this.pattern,
    super.textColor,
    super.previewColor,
  });

  @override
  Color get defaultPreview =>
      pattern.isEmpty ? const Color(0xFF616161) : pattern.first;

  @override
  Color themedColor(TileColor slot, int? position) => pattern.isEmpty
      ? const Color(0xFF616161)
      : pattern[(position ?? 0) % pattern.length];
}
