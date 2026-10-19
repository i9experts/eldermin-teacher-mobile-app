import 'package:flutter/material.dart';
import '../tokens/em_colors.dart';
import '../tokens/em_spacing.dart';
import '../tokens/em_typography.dart';
import 'em_icon_circle_button.dart';

/// Transparent app bar: back circle · centred title · optional trailing
/// circle (e.g. "more"). Replaces the inline `AppBar(...)` calls in D2+.
///
/// The title stays centred because the leading and trailing slots both
/// reserve 48dp. At large text scales the title ellipsizes to one line.
class EmAppBar extends StatelessWidget implements PreferredSizeWidget {
  const EmAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.showBack = true,
    this.onBack,
    this.backLabel = 'Back',
    this.trailing,
    this.actions = const [],
  });

  final String? title;
  final Widget? titleWidget;
  final bool showBack;

  /// Defaults to `Navigator.maybePop`.
  final VoidCallback? onBack;
  final String backLabel;

  /// One trailing widget (usually an [EmIconCircleButton]). [actions] are
  /// placed before it.
  final Widget? trailing;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final canPop = Navigator.maybeOf(context)?.canPop() ?? false;
    final back = showBack && (canPop || onBack != null)
        ? EmIconCircleButton(
            icon: rtl ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
            semanticLabel: backLabel,
            tooltip: backLabel,
            onTap: onBack ?? () => Navigator.maybeOf(context)?.maybePop(),
          )
        : const SizedBox(width: 48, height: 48);
    final end = <Widget>[...actions, if (trailing != null) trailing!];
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 72,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: EmSpacing.screenH),
          child: Row(
            children: [
              SizedBox(width: 48, child: back),
              Expanded(
                child: Center(
                  child: Semantics(
                    header: true,
                    child: titleWidget ??
                        Text(
                          title ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: EmType.heading.copyWith(color: EmColors.ink),
                        ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (var i = 0; i < end.length; i++) ...[if (i > 0) const SizedBox(width: 8), end[i]],
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
