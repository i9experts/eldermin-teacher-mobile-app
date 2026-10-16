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
  const _StateBody({required this.icon, required this.iconBg, required this.iconColor, required this.title, this.message, this.actionLabel, this.onAction, required this.liveRegion});
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(EmSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: ExcludeSemantics(child: Icon(icon, size: 34, color: iconColor)),
            ),
            const SizedBox(height: EmSpacing.s16),
            Semantics(
              liveRegion: liveRegion,
              container: true,
              child: Column(children: [
                Text(title, textAlign: TextAlign.center, style: EmType.heading.copyWith(color: EmColors.ink)),
                if (message != null) ...[
                  const SizedBox(height: 6),
                  Text(message!, textAlign: TextAlign.center, style: EmType.body.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400)),
                ],
              ]),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: EmSpacing.s20),
              EmPrimaryButton(label: actionLabel!, onPressed: onAction, expand: false),
            ],
          ],
        ),
      ),
    );
  }
}

/// Nothing-here state: tinted icon circle, title, message, optional action.
class EmEmptyState extends StatelessWidget {
  const EmEmptyState({super.key, this.icon = Icons.inbox_outlined, required this.title, this.message, this.actionLabel, this.onAction});
  final IconData icon;
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
      );
}

/// Failure state with a Retry action (announced to screen readers).
class EmErrorState extends StatelessWidget {
  const EmErrorState({super.key, this.title = 'Something went wrong', this.message, this.onRetry, this.retryLabel = 'Retry'});
  final String title;
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
      );
}
