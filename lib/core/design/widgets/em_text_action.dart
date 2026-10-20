import 'package:flutter/material.dart';
import '../tokens/em_colors.dart';
import '../tokens/em_spacing.dart';
import '../tokens/em_typography.dart';

/// Text-only action with an optional leading icon (sort, delete, "Behaviour history"...). Unlike `TextButton.icon` the label wraps to two
/// lines instead of overflowing at a large text scale; 48dp tall; [destructive] uses the error colour.
class EmTextAction extends StatelessWidget {
  const EmTextAction({super.key, required this.label, required this.onPressed, this.icon, this.destructive = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? EmColors.error : EmColors.primary;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(foregroundColor: color, minimumSize: const Size(EmSpacing.minTouch, EmSpacing.minTouch)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[ExcludeSemantics(child: Icon(icon, size: 20)), const SizedBox(width: EmSpacing.s8)],
        Flexible(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.label.copyWith(color: onPressed == null ? EmColors.onDisabled : color))),
      ]),
    );
  }
}
