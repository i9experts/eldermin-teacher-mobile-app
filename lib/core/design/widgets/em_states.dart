import 'package:flutter/material.dart';
import '../tokens/em_colors.dart';
import '../tokens/em_spacing.dart';
import '../tokens/em_typography.dart';
import 'em_buttons.dart';

/// Centred spinner. [label] is spoken ("Loading") and optionally shown.
class EmLoading extends StatelessWidget {
  const EmLoading({super.key, this.label = 'Loading', this.showLabel = false});
  final String label;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        liveRegion: true,
        label: label,
        excludeSemantics: true,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 3.5, color: EmColors.primary)),
          if (showLabel) ...[const SizedBox(height: 12), Text(label, style: EmType.body.copyWith(color: EmColors.textSecondary))],
        ]),
      ),
    );
  }
}

class _StateBody extends StatelessWidget {
  const _StateBody({required this.icon, required this.iconBg, required this.iconColor, required this.title, this.message, this.actionLabel, this.onAction, required this.liveRegion, this.scroll = true, this.compact = false});
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String? title;
  final bool scroll;
  final bool compact;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final pad = compact ? EmSpacing.s16 : EmSpacing.s24;
    final iconBox = compact ? 52.0 : 72.0;
    final content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: iconBox,
              height: iconBox,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: ExcludeSemantics(child: Icon(icon, size: compact ? 26 : 34, color: iconColor)),
            ),
            SizedBox(height: compact ? EmSpacing.s12 : EmSpacing.s16),
            Semantics(
              liveRegion: liveRegion,
              container: true,
              child: Column(children: [
                if (title != null) Text(title!, textAlign: TextAlign.center, style: EmType.heading.copyWith(color: EmColors.ink)),
                if (message != null) ...[
                  if (title != null) const SizedBox(height: 6),
                  Text(message!, textAlign: TextAlign.center, style: EmType.body.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400)),
                ],
              ]),
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: compact ? EmSpacing.s12 : EmSpacing.s20),
              EmPrimaryButton(label: actionLabel!, onPressed: onAction, expand: false),
            ],
          ],
        );
    // [scroll] false: used inside an already scrolling list (unbounded height), so no nested scroll view.
    return Center(
      child: scroll
          ? SingleChildScrollView(padding: EdgeInsetsDirectional.all(pad), child: content)
          : Padding(padding: EdgeInsetsDirectional.all(pad), child: content),
    );
  }
}

/// Nothing-here state: tinted icon circle, title, message, optional action.
class EmEmptyState extends StatelessWidget {
  const EmEmptyState({super.key, this.icon = Icons.inbox_outlined, required this.title, this.message, this.actionLabel, this.onAction, this.scroll = true, this.compact = false});
  final IconData icon;
  final bool scroll;
  final bool compact;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => _StateBody(
        icon: icon,
        iconBg: EmColors.primaryContainer,
        iconColor: EmColors.primary,
        title: title,
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
        liveRegion: false,
        scroll: scroll,
        compact: compact,
      );
}

/// Failure state with a Retry action (announced to screen readers).
class EmErrorState extends StatelessWidget {
  const EmErrorState({super.key, this.title = 'Something went wrong', this.message, this.onRetry, this.retryLabel = 'Retry', this.scroll = true, this.compact = false});

  /// Pass `title: null` to show only [message] (the server's own text).
  final String? title;
  final bool scroll;
  final bool compact;
  final String? message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) => _StateBody(
        icon: Icons.error_outline_rounded,
        iconBg: EmColors.errorContainer,
        iconColor: EmColors.error,
        title: title,
        message: message,
        actionLabel: onRetry == null ? null : retryLabel,
        onAction: onRetry,
        liveRegion: true,
        scroll: scroll,
        compact: compact,
      );
}
