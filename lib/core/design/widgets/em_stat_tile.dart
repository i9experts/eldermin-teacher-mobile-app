import 'package:flutter/material.dart';
import '../tokens/em_colors.dart';
import '../tokens/em_radius.dart';
import '../tokens/em_typography.dart';

/// Lighter-tint tile (radius 20): white icon circle, optional kebab, bold
/// value + small unit, caption label. Sits inside an [EmHeroCard].
///
/// The kebab has a 48dp target aligned to the tile's top-end corner; its glyph
/// is right-aligned so three tiles still fit side by side on a 320dp screen.
class EmStatTile extends StatelessWidget {
  const EmStatTile({
    super.key,
    required this.icon,
    required this.value,
    this.unit,
    required this.label,
    this.onMenu,
    this.menuLabel = 'More options',
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String? unit;
  final String label;

  /// Shows the vertical kebab when set.
  final VoidCallback? onMenu;
  final String menuLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final summary = '$label: $value${unit != null ? ' $unit' : ''}';
    final content = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 48,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: EmColors.surface, shape: BoxShape.circle),
                child: Icon(icon, size: 20, color: EmColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: value, style: EmType.valueSmall.copyWith(color: EmColors.ink)),
              if (unit != null) TextSpan(text: ' $unit', style: EmType.caption.copyWith(color: EmColors.ink, fontWeight: FontWeight.w400)),
            ]),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.caption.copyWith(color: EmColors.textSecondary)),
        ],
      ),
    );
    final tile = DecoratedBox(
      decoration: const BoxDecoration(color: EmColors.primaryTint, borderRadius: EmRadius.tileAll),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: EmRadius.tileAll,
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Semantics(
              container: true,
              button: onTap != null,
              label: summary,
              onTap: onTap,
              excludeSemantics: true,
              child: onTap == null ? content : InkWell(onTap: onTap, child: content),
            ),
            if (onMenu != null)
              PositionedDirectional(
                top: 8,
                end: 0,
                child: Semantics(
                  button: true,
                  label: menuLabel,
                  excludeSemantics: true,
                  onTap: onMenu,
                  child: InkResponse(
                    onTap: onMenu,
                    radius: 24,
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Align(alignment: AlignmentDirectional.centerEnd, child: Padding(padding: EdgeInsetsDirectional.only(end: 6), child: Icon(Icons.more_vert_rounded, size: 20, color: EmColors.ink))),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return tile;
  }
}
