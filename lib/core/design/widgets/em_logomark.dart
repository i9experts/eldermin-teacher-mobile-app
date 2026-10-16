import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Eldermin logomark redrawn as SVG from the PNG geometry (PENDING BRAND
/// APPROVAL). [reversed] is for `primaryDark` backgrounds.
class EmLogomark extends StatelessWidget {
  const EmLogomark({super.key, this.height = 96, this.reversed = false, this.semanticLabel = 'Eldermin'});
  final double height;
  final bool reversed;
  final String semanticLabel;

  static const asset = 'assets/brand/logomark.svg';
  static const reversedAsset = 'assets/brand/logomark_reversed.svg';

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      reversed ? reversedAsset : asset,
      height: height,
      semanticsLabel: semanticLabel,
    );
  }
}
