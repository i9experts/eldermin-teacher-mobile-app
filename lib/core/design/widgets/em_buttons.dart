import 'package:flutter/material.dart';
import '../tokens/em_colors.dart';
import 'em_on_dark.dart';
import '../tokens/em_typography.dart';

/// Filled primary pill (white label on `primary`, 52dp).
class EmPrimaryButton extends StatelessWidget {
  const EmPrimaryButton({super.key, required this.label, required this.onPressed, this.icon, this.loading = false, this.expand = true, this.destructive = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Shows a spinner and ignores taps.
  final bool loading;
  final bool expand;

  /// Error-coloured fill for an action that rejects / removes (the label still says what it does).
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    // On the blue auth card the primary action is the accent (yellow) fill with an ink label (>= 4.5:1).
    // Every button is the theme yellow with an ink label (>= 4.5:1); only a destructive action stays red.
    final fill = destructive ? EmColors.error : EmColors.accent;
    final on = destructive ? EmColors.onError : EmColors.ink;
    final child = _content(label, icon, loading, on);
    final btn = ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(64, 52),
        backgroundColor: fill,
        foregroundColor: on,
        disabledBackgroundColor: loading ? fill : (EmOnDark.of(context) ? EmColors.primaryMid : EmColors.disabled),
        disabledForegroundColor: loading ? on : (EmOnDark.of(context) ? EmColors.onPrimaryDark : EmColors.onDisabled),
      ),
      child: child,
    );
    return Semantics(
      button: true,
      label: label,
      enabled: onPressed != null && !loading,
      excludeSemantics: true,
      onTap: loading ? null : onPressed,
      child: expand ? SizedBox(width: double.infinity, child: btn) : btn,
    );
  }
}

/// White button with a yellow border and ink label (reference "Drink 200 ml").
class EmSecondaryButton extends StatelessWidget {
  const EmSecondaryButton({super.key, required this.label, required this.onPressed, this.icon, this.expand = false, this.destructive = false, this.loading = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final bool destructive;

  /// Shows a spinner next to the label and ignores taps.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final btn = OutlinedButton(
      onPressed: loading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        backgroundColor: EmColors.surface,
        foregroundColor: destructive ? EmColors.error : EmColors.ink,
        side: BorderSide(color: destructive ? EmColors.error : EmColors.accent, width: 1.5),
      ),
      child: _content(label, icon, loading, destructive ? EmColors.error : EmColors.ink),
    );
    return Semantics(
      button: true,
      label: label,
      enabled: onPressed != null && !loading,
      excludeSemantics: true,
      onTap: onPressed,
      child: expand ? SizedBox(width: double.infinity, child: btn) : btn,
    );
  }
}

Widget _content(String label, IconData? icon, bool loading, Color color) {
  if (loading) {
    // spinner + the (busy) label, so the state is readable, not only animated
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: color)),
      const SizedBox(width: 10),
      Flexible(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: EmType.label.copyWith(fontSize: 15))),
    ]);
  }
  Text text() => Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: EmType.label.copyWith(fontSize: 15));
  if (icon == null) return text();
  return Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 20), const SizedBox(width: 8), Flexible(child: text())]);
}
