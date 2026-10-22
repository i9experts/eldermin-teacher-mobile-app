import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../motion/logomark_geometry.dart';
import '../motion/node_network_painter.dart';

/// Eldermin logomark redrawn as SVG from the PNG geometry (PENDING BRAND
/// APPROVAL). [reversed] is for `primaryDark` backgrounds.
///
/// With [drive] the mark is painted live by the node-network painter (same
/// geometry and colours, plus charge / dash drift / pulse / ripples / palette
/// morph); without it, it is the static SVG.
class EmLogomark extends StatelessWidget {
  const EmLogomark({super.key, this.height = 96, this.reversed = false, this.semanticLabel = 'Eldermin', this.drive});
  final double height;
  final bool reversed;
  final String semanticLabel;
  final EmNetworkDrive? drive;

  /// Height of the logomark on the native and Flutter splash (dp). The native
  /// splash PNGs (assets/splash) are exported at this size so the hand-off is seamless.
  static const double splashHeight = 112;

  static const asset = 'assets/brand/logomark.svg';
  static const reversedAsset = 'assets/brand/logomark_reversed.svg';

  @override
  Widget build(BuildContext context) {
    final d = drive;
    if (d != null) {
      return EmNodeNetwork(
        height: height,
        from: reversed ? EmNetworkPalette.reversed : EmNetworkPalette.standard,
        drive: d,
        semanticLabel: semanticLabel,
      );
    }
    return SvgPicture.asset(
      reversed ? reversedAsset : asset,
      height: height,
      semanticsLabel: semanticLabel,
    );
  }
}
