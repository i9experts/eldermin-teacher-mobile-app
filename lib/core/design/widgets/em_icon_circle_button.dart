import 'package:flutter/material.dart';
import '../tokens/em_colors.dart';
import '../tokens/em_shadows.dart';

/// White 48dp circle holding one icon (back, more, notifications, calendar).
/// [showDot] draws the small unread dot at the top-end of the icon.
class EmIconCircleButton extends StatelessWidget {
  const EmIconCircleButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.onTap,
    this.showDot = false,
    this.dotLabel = 'new',
    this.size = 48,
    this.iconColor = EmColors.ink,
    this.elevated = true,
    this.tooltip,
  }) : assert(size >= 48, 'touch target must be at least 48dp');

  final IconData icon;

  /// Spoken label, e.g. "Notifications". Required: an icon alone says nothing.
  final String semanticLabel;
  final VoidCallback? onTap;
  final bool showDot;
  final String dotLabel;
  final double size;
  final Color iconColor;
  final bool elevated;

  /// Long-press / hover hint. Also what `tester.pageBack()` looks for on a back button (tooltip "Back").
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Semantics(
      button: true,
      enabled: onTap != null,
      label: showDot ? '$semanticLabel, $dotLabel' : semanticLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: EmColors.surface,
            shape: BoxShape.circle,
            boxShadow: elevated ? EmShadows.soft : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(icon,
                      size: 22,
                      color: onTap == null ? EmColors.onDisabled : iconColor),
                  if (showDot)
                    PositionedDirectional(
                      top: size * 0.22,
                      end: size * 0.25,
                      child: Container(
                        key: const Key('em_dot'),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: EmColors.error,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: EmColors.surface, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return tooltip == null
        ? button
        : Tooltip(message: tooltip!, excludeFromSemantics: true, child: button);
  }
}
