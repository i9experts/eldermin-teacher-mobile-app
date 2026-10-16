import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../tokens/em_colors.dart';
import '../tokens/em_shadows.dart';

/// Colour treatment of the diamond. Glyph colour is derived (`onAccent` navy on
/// accent; `onPrimary` white on primary), never white on accent.
enum EmFabStyle { accent, primary }

/// Rounded square rotated 45deg with an upright glyph. 56dp side (hit area
/// follows the diamond). Sits half above the bar in [EmBottomNav].
class EmDiamondFab extends StatelessWidget {
  const EmDiamondFab({super.key, required this.icon, required this.semanticLabel, required this.onPressed, this.style = EmFabStyle.accent, this.side = 56})
      : assert(side >= 48);

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final EmFabStyle style;
  final double side;

  @override
  Widget build(BuildContext context) {
    final fill = style == EmFabStyle.accent ? EmColors.accent : EmColors.primary;
    final glyph = style == EmFabStyle.accent ? EmColors.onAccent : EmColors.onPrimary;
    final diag = side * math.sqrt2;
    return Semantics(
      button: true,
      label: semanticLabel,
      enabled: onPressed != null,
      excludeSemantics: true,
      onTap: onPressed,
      child: SizedBox(
        width: diag,
        height: diag,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: math.pi / 4,
              child: DecoratedBox(
                decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(side * 0.3), boxShadow: EmShadows.fab),
                child: Material(
                  type: MaterialType.transparency,
                  borderRadius: BorderRadius.circular(side * 0.3),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(onTap: onPressed, child: SizedBox(width: side, height: side)),
                ),
              ),
            ),
            IgnorePointer(child: Icon(icon, size: 26, color: glyph)),
          ],
        ),
      ),
    );
  }
}
