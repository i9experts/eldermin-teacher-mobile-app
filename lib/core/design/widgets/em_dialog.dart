import 'package:flutter/material.dart';
import '../tokens/em_colors.dart';
import '../tokens/em_spacing.dart';
import '../tokens/em_typography.dart';
import 'em_keyboard_toolbar.dart';

/// Visual weight of a dialog action.
enum EmDialogTone { neutral, primary, destructive }

/// One text action of an [EmDialog] (48dp touch target, token colours; the label never relies on colour alone).
class EmDialogAction extends StatelessWidget {
  const EmDialogAction({super.key, required this.label, required this.onPressed, this.tone = EmDialogTone.neutral});

  final String label;
  final VoidCallback? onPressed;
  final EmDialogTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      EmDialogTone.neutral => EmColors.textSecondary,
      EmDialogTone.primary => EmColors.primary,
      EmDialogTone.destructive => EmColors.error,
    };
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(foregroundColor: color),
      child: Text(label, style: EmType.label.copyWith(color: onPressed == null ? EmColors.onDisabled : color)),
    );
  }
}

/// Token-styled dialog. Still an [AlertDialog] underneath (shape, surface and text styles come from the theme's `dialogTheme`),
/// so existing `find.byType(AlertDialog)` finders and the key on the dialog keep working.
class EmDialog extends StatelessWidget {
  const EmDialog({super.key, required this.title, this.message, this.content, required this.actions})
      : assert(message == null || content == null, 'pass message or content, not both');

  final String title;

  /// Plain body text. Use [content] for anything richer.
  final String? message;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return EmKeyboardAccessory.overlay(
      child: AlertDialog(
        title: Semantics(header: true, child: Text(title)),
        content: content ?? (message == null ? null : Text(message!, style: EmType.bodyRegular.copyWith(color: EmColors.textSecondary, height: 1.5))),
        actionsPadding: const EdgeInsetsDirectional.fromSTEB(EmSpacing.s16, 0, EmSpacing.s16, EmSpacing.s12),
        actionsOverflowButtonSpacing: EmSpacing.s4,
        actions: actions,
      ),
    );
  }
}
