import 'package:flutter/material.dart';
import '../tokens/em_colors.dart';
import '../tokens/em_radius.dart';
import '../tokens/em_shadows.dart';

/// White surface, radius 24, separated by tint (no border). Optional tap.
class EmCard extends StatelessWidget {
  const EmCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsetsDirectional.all(16),
    this.onTap,
    this.color = EmColors.surface,
    this.radius = EmRadius.card,
    this.elevated = false,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final double radius;
  final bool elevated;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    Widget card = DecoratedBox(
      decoration: ShapeDecoration(color: color, shape: shape, shadows: elevated ? EmShadows.soft : null),
      child: Material(
        type: MaterialType.transparency,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? Padding(padding: padding, child: child)
            : InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
    if (semanticLabel != null) {
      card = Semantics(container: true, button: onTap != null, label: semanticLabel, child: card);
    }
    return card;
  }
}
