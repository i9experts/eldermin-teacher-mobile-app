import 'package:flutter/material.dart';
import '../tokens/em_colors.dart';
import '../tokens/em_radius.dart';
import '../tokens/em_spacing.dart';
import '../tokens/em_typography.dart';

/// A field that opens a picker (a date, a student, a class ...): same surface, border and error colour as a text field, 48dp minimum,
/// optional leading widget (avatar / icon) and a trailing chevron. Shows [placeholder] until there is a [title].
class EmSelectField extends StatelessWidget {
  const EmSelectField({
    super.key,
    this.leading,
    this.icon,
    this.title,
    this.subtitle,
    this.placeholder = 'Choose',
    this.hasError = false,
    this.trailingIcon = Icons.expand_more_rounded,
    this.titleKey,
    required this.onTap,
  });

  final Widget? leading;
  final IconData? icon;
  final String? title;
  final String? subtitle;
  final String placeholder;
  final bool hasError;
  final IconData? trailingIcon;

  /// Key for the title text (tests read the chosen value through it).
  final Key? titleKey;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final lead = leading ?? (icon == null ? null : ExcludeSemantics(child: Icon(icon, size: 20, color: EmColors.primary)));
    return Semantics(
      button: true,
      label: title ?? placeholder,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: EmRadius.mdAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: EmSpacing.minTouch),
          child: DecoratedBox(
            decoration: BoxDecoration(color: EmColors.surface, borderRadius: EmRadius.mdAll, border: Border.all(color: hasError ? EmColors.error : EmColors.border)),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(EmSpacing.s16, EmSpacing.s8, EmSpacing.s12, EmSpacing.s8),
              child: Row(children: [
                if (lead != null) ...[lead, const SizedBox(width: EmSpacing.s12)],
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(title ?? placeholder, key: titleKey, style: EmType.body.copyWith(color: title == null ? EmColors.textTertiary : EmColors.ink)),
                    if (subtitle != null && subtitle!.isNotEmpty) Text(subtitle!, style: EmType.caption.copyWith(color: EmColors.textSecondary)),
                  ]),
                ),
                if (trailingIcon != null) ExcludeSemantics(child: Icon(trailingIcon, color: EmColors.textSecondary)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
