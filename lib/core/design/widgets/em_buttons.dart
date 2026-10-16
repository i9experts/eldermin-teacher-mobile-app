import 'package:flutter/material.dart';
import '../tokens/em_colors.dart';
import '../tokens/em_typography.dart';

/// Filled primary pill (white label on `primary`, 52dp).
class EmPrimaryButton extends StatelessWidget {
  const EmPrimaryButton({super.key, required this.label, required this.onPressed, this.icon, this.loading = false, this.expand = true});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Shows a spinner and ignores taps.
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = _content(label, icon, loading, EmColors.onPrimary);
    final btn = ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(64, 52),
        backgroundColor: EmColors.primary,
        foregroundColor: EmColors.onPrimary,
        disabledBackgroundColor: loading ? EmColors.primary : EmColors.disabled,
        disabledForegroundColor: loading ? EmColors.onPrimary : EmColors.onDisabled,
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

/// White pill with a light border and primary label (reference "Drink 200 ml").
class EmSecondaryButton extends StatelessWidget {
  const EmSecondaryButton({super.key, required this.label, required this.onPressed, this.icon, this.expand = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final btn = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        backgroundColor: EmColors.surface,
        foregroundColor: EmColors.primary,
        side: const BorderSide(color: EmColors.primaryLight, width: 1.5),
      ),
      child: _content(label, icon, false, EmColors.primary),
    );
    return Semantics(
      button: true,
      label: label,
      enabled: onPressed != null,
      excludeSemantics: true,
      onTap: onPressed,
      child: expand ? SizedBox(width: double.infinity, child: btn) : btn,
    );
  }
}

Widget _content(String label, IconData? icon, bool loading, Color color) {
  if (loading) {
    return SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: color));
  }
  Text text() => Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: EmType.label.copyWith(fontSize: 15));
  if (icon == null) return text();
  return Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 20), const SizedBox(width: 8), Flexible(child: text())]);
}
