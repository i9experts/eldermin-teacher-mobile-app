import 'package:flutter/material.dart';
import '../tokens/em_colors.dart';
import '../tokens/em_radius.dart';
import '../tokens/em_spacing.dart';
import '../tokens/em_typography.dart';

/// White fully-rounded search field (height 52) with an optional circular
/// action beside it (e.g. calendar [EmIconCircleButton]).
class EmSearchPill extends StatelessWidget {
  const EmSearchPill({
    super.key,
    this.controller,
    this.hint = 'Search…',
    this.onChanged,
    this.onSubmitted,
    this.trailing,
    this.semanticLabel = 'Search',
    this.fieldKey,
  });

  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;
  final String semanticLabel;

  /// Key of the inner text field (tests enter text through it).
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: DecoratedBox(
              decoration: const BoxDecoration(color: EmColors.surface, borderRadius: EmRadius.pillAll),
              child: Row(
                children: [
                  const SizedBox(width: 18),
                  const ExcludeSemantics(child: Icon(Icons.search_rounded, size: 22, color: EmColors.textSecondary)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Semantics(
                      textField: true,
                      label: semanticLabel,
                      child: TextField(
                      key: fieldKey,
                      controller: controller,
                      onChanged: onChanged,
                      onSubmitted: onSubmitted,
                      textInputAction: TextInputAction.search,
                      style: EmType.body.copyWith(color: EmColors.ink),
                      cursorColor: EmColors.primary,
                      decoration: InputDecoration(
                        isCollapsed: false,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: hint,
                        hintStyle: EmType.body.copyWith(color: EmColors.textTertiary),
                        contentPadding: const EdgeInsetsDirectional.symmetric(vertical: 16),
                      ),
                    ),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: EmSpacing.s12), trailing!],
      ],
    );
  }
}
