import 'package:flutter/material.dart';
import '../tokens/em_colors.dart';
import '../tokens/em_radius.dart';
import '../tokens/em_typography.dart';
import 'em_tone.dart';

/// Pill chip. Default: interactive filter/choice chip (white, selected =
/// `primaryLight` with ink text; 48dp touch target). [EmChip.status] is a
/// non-interactive tag: light container + dark text of an [EmTone].
class EmChip extends StatelessWidget {
  const EmChip({super.key, required this.label, this.selected = false, this.onTap, this.icon})
      : tone = null;

  /// Non-interactive status tag (container + dark text, never solid).
  const EmChip.status({super.key, required this.label, this.tone = EmTone.neutral, this.icon})
      : selected = false,
        onTap = null;

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final EmTone? tone;

  @override
  Widget build(BuildContext context) {
    if (tone != null) {
      return Semantics(
        label: label,
        container: true,
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(color: tone!.background, borderRadius: EmRadius.pillAll),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, size: 14, color: tone!.foreground), const SizedBox(width: 4)],
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: EmType.caption.copyWith(color: tone!.foreground, fontWeight: FontWeight.w600))),
            ]),
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Center(
          widthFactor: 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: selected ? EmColors.primaryLight : EmColors.surface,
              borderRadius: EmRadius.pillAll,
              border: Border.all(color: selected ? EmColors.primaryLight : EmColors.border),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: EmRadius.pillAll,
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 10),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (icon != null) ...[Icon(icon, size: 16, color: selected ? EmColors.primaryDark : EmColors.textSecondary), const SizedBox(width: 6)],
                    Flexible(
                      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: EmType.label.copyWith(color: selected ? EmColors.ink : EmColors.textSecondary)),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
