import 'package:flutter/widgets.dart';

class EmRadius {
  EmRadius._();
  static const double sm = 12;
  static const double md = 16;
  static const double tile = 20; // nested stat tiles
  static const double card = 24;
  static const double hero = 28;
  static const double navTop = 32;

  /// Corner radius of the white logo tile, as a fraction of its side.
  static const double logoTileRatio = 0.2;

  /// "Fully rounded": larger than any control height.
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius tileAll = BorderRadius.all(Radius.circular(tile));
  static const BorderRadius cardAll = BorderRadius.all(Radius.circular(card));
  static const BorderRadius heroAll = BorderRadius.all(Radius.circular(hero));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}
