// All color themes of the app live here. To add a theme: define it and add it
// to [appThemes]. To remove one: delete it from [appThemes]. Nothing else in
// the app needs to be touched; the theme picker, the persistence and the
// default (the first entry) all follow this list.
//
// Two kinds of themes:
//
//  * StandardTheme: every named slot (TileColor.red, .green, ...) gets a
//    color, given as a built-in color (Colors.red) or a hex value
//    (Color(0xFFRRGGBB)). Tiles ask for a slot, not a color, so a theme can
//    turn "red" into anything, e.g. a grey. Missing slots use `fallback`.
//
//  * PatternTheme: a list of colors, repeated in order by tile position: the
//    1st tile of a screen gets pattern[0], the 2nd pattern[1], ...
//
// All tile colors (slots) a StandardTheme can define, and where they are used:
//
//   TileColor.red       danger/stop: Shutdown, Stop Program, Cancel
//   TileColor.orange    Settings (main menu), System, Reboot, Network status
//   TileColor.amber     only via the sensor/program color sequence (below)
//   TileColor.green     Programs (main menu), Start buttons, Network, Hostname
//   TileColor.teal      Versions, Rotate, Scan Networks, Manage Connection
//   TileColor.cyan      Screensaver (when on); also in the sequence (below)
//   TileColor.blue      Sensors (main menu), Keyboard, Network Scan, Submit
//   TileColor.indigo    Services, Overview left/right
//   TileColor.purple    Display, Calibrate, Hotspot Settings, Tilt Maze
//   TileColor.pink      Personality, Color Theme
//   TileColor.brown     LAN Status
//   TileColor.blueGrey  Hide UI, Device Info, Advanced
//   TileColor.grey      neutral/disabled: Screensaver off, Overview off,
//                       Stop Program when no program runs
//
// Sensor categories, IMU entries, programs and the calibration board take
// their slot by position from this sequence (then it repeats):
//   blue, green, orange, purple, red, teal, pink, indigo, amber, cyan
//
// A slot you leave out falls back to the theme's `fallback` color.
//
// `textColor` is the color of icons and text on the tiles (default white).
// `previewColor` is the color of the theme's own tile in the theme picker
// (optional; by default the blue slot, or the first pattern color).

import 'package:flutter/material.dart';
import 'package:stpvelox/core/theme/app_theme.dart';

/// Every theme, in the order shown in the picker. The first one is the default.
final List<AppTheme> appThemes = [
  colorful,
  raccoon,
  monochrome,
];

/// The multi-colored look: each slot is its own color.
final colorful = StandardTheme(
  id: 'colorful',
  label: 'Colorful',
  colors: {
    TileColor.red: Colors.red[600]!,
    TileColor.orange: Colors.orange[600]!,
    TileColor.amber: Colors.amber[600]!,
    TileColor.green: Colors.green[600]!,
    TileColor.teal: Colors.teal[600]!,
    TileColor.cyan: Colors.cyan[600]!,
    TileColor.blue: Colors.blue[600]!,
    TileColor.indigo: Colors.indigo[400]!,
    TileColor.purple: Colors.purple[600]!,
    TileColor.pink: Colors.pink[600]!,
    TileColor.brown: Colors.brown[600]!,
    TileColor.blueGrey: Colors.blueGrey[600]!,
    TileColor.grey: Colors.grey[700]!,
  },
);

/// Gold, rust and green (Raccoon docs palette), repeating by position.
const raccoon = PatternTheme(
  id: 'raccoon',
  label: 'Raccoon',
  pattern: [
    Color(0xFFD99F40), // gold
    Color(0xFFBA643C), // rust
    Color(0xFF6A994E), // green
  ],
  textColor: Color(0xFF2F2926),
  previewColor: Color(0xFFD99F40),
);

/// Every slot the same grey.
final monochrome = StandardTheme.single(
  id: 'monochrome',
  label: 'Monochrome',
  color: const Color(0xFF5E5E5E),
);
