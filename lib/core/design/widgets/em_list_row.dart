import 'package:flutter/material.dart';
import '../tokens/em_colors.dart';
import '../tokens/em_typography.dart';
import 'em_card.dart';

/// White rounded row: leading icon circle · two-line text · trailing value
/// and/or kebab. Min height 76.
class EmListRow extends StatelessWidget {
  const EmListRow({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.trailing,
    this.onTap,
    this.onMenu,
    this.menuLabel = 'More options',
    this.semanticLabel,
  });

  final IconData? icon;

  /// Overrides [icon] when you need a custom leading widget.
  final Widget? leading;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onMenu;
  final String menuLabel;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final lead = leading ??
        (icon == null
            ? null
            : Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: EmColors.primaryTint, shape: BoxShape.circle),
                child: ExcludeSemantics(child: Icon(icon, size: 22, color: EmColors.primary)),
              ));
    return EmCard(
      onTap: onTap,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
      semanticLabel: semanticLabel ?? [title, if (subtitle != null) subtitle!, if (trailingText != null) trailingText!].join(', '),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Row(
          children: [
            if (lead != null) ...[lead, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.bodyLarge.copyWith(color: EmColors.ink)),
                  if (subtitle != null)
                    Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.body.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400)),
                ],
              ),
            ),
            if (trailingText != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(trailingText!, maxLines: 1, overflow: TextOverflow.ellipsis, style: EmType.bodyLarge.copyWith(color: EmColors.ink)),
              ),
            ],
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
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
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
