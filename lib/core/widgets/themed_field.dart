import 'package:flutter/material.dart';
import 'package:stpvelox/core/theme/app_theme.dart';

/// Background of the cards that hold form fields (same as the hotspot form).
const Color kFormCardColor = Color(0xFF11161C);

/// Background of dropdown menus.
const Color kFormMenuColor = Color(0xFF1A2027);

/// Field style of the hotspot settings, colored from the theme: the field at
/// [index] takes the [index]-th color of the theme's pattern (border, icon,
/// label and a light tint).
InputDecoration themedFieldDecoration(
  AppTheme theme,
  int index, {
  required String label,
  required IconData icon,
  String? hint,
  Widget? suffix,
}) {
  final color = theme.tileColor(TileColor.byIndex(index), index);
  OutlineInputBorder border(Color c, {double width = 1.5}) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: c, width: width),
      );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: color.withValues(alpha: 0.12),
    labelStyle: TextStyle(color: Colors.grey[300]),
    floatingLabelStyle: TextStyle(color: color),
    hintStyle: TextStyle(color: Colors.grey[500]),
    prefixIcon: Icon(icon, color: color),
    suffixIcon: suffix,
    suffixIconColor: Colors.white70,
    border: border(color.withValues(alpha: 0.55)),
    enabledBorder: border(color.withValues(alpha: 0.55)),
    focusedBorder: border(color, width: 2),
    errorBorder: border(Colors.redAccent),
    focusedErrorBorder: border(Colors.redAccent, width: 2),
  );
}
