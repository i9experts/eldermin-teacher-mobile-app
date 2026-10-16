import 'package:flutter/material.dart';
import '../tokens/em_colors.dart';
import '../tokens/em_radius.dart';
import '../tokens/em_typography.dart';

/// Lighter-tint tile (radius 20): white icon circle, optional kebab, bold
/// value + small unit, caption label. Sits inside an [EmHeroCard].
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

  /// Shows the vertical kebab (48dp target) when set.
  final VoidCallback? onMenu;
  final String menuLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: EmColors.surface, shape: BoxShape.circle),
                child: ExcludeSemantics(child: Icon(icon, size: 20, color: EmColors.primary)),
              ),
              const Spacer(),
              if (onMenu != null)
                Semantics(
                  button: true,
                  label: menuLabel,
                  excludeSemantics: true,
                  onTap: onMenu,
                  child: InkResponse(
                    onTap: onMenu,
                    radius: 24,
                    child: const SizedBox(width: 48, height: 48, child: Icon(Icons.more_vert_rounded, size: 20, color: EmColors.ink)),
                  ),
                )
              else
                const SizedBox(height: 40),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: value, style: EmType.valueSmall.copyWith(color: EmColors.ink)),
                if (unit != null) TextSpan(text: ' $unit', style: EmType.caption.copyWith(color: EmColors.ink, fontWeight: FontWeight.w400)),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.caption.copyWith(color: EmColors.textSecondary)),
          ),
        ],
      ),
    );
    final tile = DecoratedBox(
      decoration: const BoxDecoration(color: EmColors.primaryTint, borderRadius: EmRadius.tileAll),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: EmRadius.tileAll,
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
    return Semantics(
      container: true,
      label: '$label: $value${unit != null ? ' $unit' : ''}',
      button: onTap != null,
      onTap: onTap,
      child: tile,
    );
  }
}
