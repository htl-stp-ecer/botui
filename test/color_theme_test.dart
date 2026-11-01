import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stpvelox/core/theme/app_theme.dart';
import 'package:stpvelox/themes.dart';

void main() {
  test('theme ids are unique and the list is not empty', () {
    expect(appThemes, isNotEmpty);
    expect(appThemes.map((t) => t.id).toSet().length, appThemes.length);
  });

  test('colorful: every slot has its own color', () {
    final colors = TileColor.values.map((s) => colorful.tileColor(s, 0));
    expect(colors.toSet().length, TileColor.values.length);
    expect(colorful.tileColor(TileColor.red, 3),
        colorful.tileColor(TileColor.red, 0));
  });

  test('monochrome: every slot is the same grey', () {
    final colors = TileColor.values.map((s) => monochrome.tileColor(s, 2));
    expect(colors.toSet().length, 1);
  });

  test('standard themes: missing slots use the fallback', () {
    const theme = StandardTheme(
      id: 't',
      label: 'T',
      colors: {TileColor.red: Color(0xFF111111)},
      fallback: Color(0xFF222222),
    );
    expect(theme.tileColor(TileColor.red, null), const Color(0xFF111111));
    expect(theme.tileColor(TileColor.green, null), const Color(0xFF222222));
  });

  test('pattern themes color by position and ignore the slot', () {
    final p = raccoon.pattern;
    expect(p.length, 3);
    expect(raccoon.tileColor(TileColor.red, 0), p[0]);
    expect(raccoon.tileColor(TileColor.blue, 0), p[0]);
    expect(raccoon.tileColor(TileColor.red, 2), p[2]);
    expect(raccoon.tileColor(TileColor.red, 3), p[0]); // cycles
    expect(raccoon.tileColor(TileColor.red, null), p[0]); // no position
    expect(raccoon.textColor, const Color(0xFF2F2926));
  });

  test('TileColor.byIndex cycles through the sequence', () {
    expect(TileColor.byIndex(0), TileColor.sequence.first);
    expect(
        TileColor.byIndex(TileColor.sequence.length), TileColor.sequence.first);
  });
}
