import 'dart:math' as math;
import 'package:flutter/painting.dart';

/// WCAG 2.x relative luminance (0 = black, 1 = white), alpha ignored.
double relativeLuminance(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.red / 255) + 0.7152 * ch(c.green / 255) + 0.0722 * ch(c.blue / 255);
}

/// WCAG contrast ratio, 1.0 .. 21.0.
double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a), lb = relativeLuminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Picks whichever of [light] / [dark] has the higher contrast against
/// [background] (ties go to [dark]). Defaults: white / ink.
Color readableOn(Color background, {Color light = const Color(0xFFFFFFFF), Color dark = const Color(0xFF12263A)}) {
  return contrastRatio(light, background) > contrastRatio(dark, background) ? light : dark;
}
