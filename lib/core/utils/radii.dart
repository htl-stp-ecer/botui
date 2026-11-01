import 'package:flutter/widgets.dart';

/// Global corner radii for the outer/inner tile scheme: corners on the outside
/// of a group of tiles use [outer], corners facing a neighbouring tile use
/// [inner].
class AppRadii {
  AppRadii._();

  static const double outer = 22;
  static const double inner = 8;

  static const Radius outerRadius = Radius.circular(outer);
  static const Radius innerRadius = Radius.circular(inner);
}
