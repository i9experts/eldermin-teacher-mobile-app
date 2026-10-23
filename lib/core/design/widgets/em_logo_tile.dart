import 'package:flutter/material.dart';
import '../tokens/em_colors.dart';
import '../tokens/em_radius.dart';
import '../tokens/em_shadows.dart';
import 'em_logomark.dart';

/// The logo in a white rounded tile: the splash mark, and (small) the landing
/// anchor on the sign-in and onboarding screens. [child] replaces the logo
/// (the assembled success glyph sits on a navy tile).
class EmLogoTile extends StatelessWidget {
  const EmLogoTile({super.key, this.size = 56, this.color = EmColors.surface, this.child, this.semanticLabel = 'Eldermin'});

  final double size;
  final Color color;
  final Widget? child;
  final String semanticLabel;

  /// Share of the tile's side the logo takes (the splash logo is 112 dp in a 160 dp tile).
  static const double logoShare = 0.7;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * EmRadius.logoTileRatio),
        boxShadow: EmShadows.soft,
      ),
      child: SizedBox.square(
        dimension: size,
        child: Center(child: child ?? EmLogomark(height: size * logoShare, semanticLabel: semanticLabel)),
      ),
    );
  }
}
