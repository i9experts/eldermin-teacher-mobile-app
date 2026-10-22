import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/em_colors.dart';
import 'em_on_dark.dart';
import '../tokens/em_typography.dart';

/// Token-styled text field (white fill, 3:1 outline, radius 16, min 56dp).
/// The visible [label] is also the spoken label.
class EmTextField extends StatelessWidget {
  const EmTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.prefixIcon,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.enabled = true,
    this.maxLines = 1,
    this.inputFormatters,
    this.autofillHints,
    this.focusNode,
    this.fillColor,
    this.radius,
    this.textCapitalization = TextCapitalization.none,
    this.onTap,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final IconData? prefixIcon;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final int? maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final FocusNode? focusNode;

  /// Overrides the theme fill (e.g. the scaffold tint when the field sits on a white card).
  final Color? fillColor;

  /// Corner radius; defaults to the theme (16). Use `EmRadius.pill` for pill fields.
  final double? radius;
  final TextCapitalization textCapitalization;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      textCapitalization: textCapitalization,
      onTap: onTap,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      maxLines: obscureText ? 1 : maxLines,
      inputFormatters: inputFormatters,
      autofillHints: autofillHints,
      cursorColor: EmOnDark.of(context) ? EmColors.accent : null,
      style: EmType.body.copyWith(
          color: EmOnDark.of(context) ? (enabled ? EmColors.onPrimaryDark : EmColors.primaryMid) : (enabled ? EmColors.ink : EmColors.onDisabled)),
      decoration: _decoration(context),
    );
  }

  InputDecoration _decoration(BuildContext context) {
    final base = Theme.of(context).inputDecorationTheme;
    OutlineInputBorder? shaped(InputBorder? b) {
      if (radius == null || b is! OutlineInputBorder) return b as OutlineInputBorder?;
      return b.copyWith(borderRadius: BorderRadius.circular(radius!));
    }

    if (EmOnDark.of(context)) return _onDark(base, shaped);

    return InputDecoration(
        filled: true,
        fillColor: fillColor,
        border: shaped(base.border),
        enabledBorder: shaped(base.enabledBorder),
        focusedBorder: shaped(base.focusedBorder),
        errorBorder: shaped(base.errorBorder),
        focusedErrorBorder: shaped(base.focusedErrorBorder),
        disabledBorder: shaped(base.disabledBorder),
        contentPadding: radius != null && radius! > 24 ? const EdgeInsetsDirectional.symmetric(horizontal: 22, vertical: 14) : null,
        labelText: label,
        hintText: hint,
        helperText: helper,
        errorText: errorText,
        errorMaxLines: 3,
        helperMaxLines: 3,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 22),
        suffixIcon: suffix,
        constraints: const BoxConstraints(minHeight: 56),
    );
  }

  /// On the blue auth card: transparent fill, white border, accent when focused.
  InputDecoration _onDark(InputDecorationThemeData base, OutlineInputBorder? Function(InputBorder?) shaped) {
    OutlineInputBorder side(InputBorder? b, Color c, double w) =>
        (shaped(b) ?? const OutlineInputBorder()).copyWith(borderSide: BorderSide(color: c, width: w));
    return InputDecoration(
      filled: false,
      border: side(base.border, EmColors.onPrimaryDark, 1.5),
      enabledBorder: side(base.enabledBorder, EmColors.onPrimaryDark, 1.5),
      focusedBorder: side(base.focusedBorder, EmColors.accent, 2),
      errorBorder: side(base.errorBorder, EmColors.errorContainer, 1.5),
      focusedErrorBorder: side(base.focusedErrorBorder, EmColors.errorContainer, 2),
      disabledBorder: side(base.disabledBorder, EmColors.primaryMid, 1.5),
      contentPadding: radius != null && radius! > 24 ? const EdgeInsetsDirectional.symmetric(horizontal: 22, vertical: 14) : null,
      labelText: label,
      hintText: hint,
      helperText: helper,
      errorText: errorText,
      errorMaxLines: 3,
      helperMaxLines: 3,
      labelStyle: EmType.body.copyWith(color: EmColors.primaryContainer, fontWeight: FontWeight.w400),
      floatingLabelStyle: EmType.caption.copyWith(color: EmColors.onPrimaryDark),
      hintStyle: EmType.body.copyWith(color: EmColors.primaryContainer, fontWeight: FontWeight.w400),
      helperStyle: EmType.caption.copyWith(color: EmColors.primaryContainer),
      errorStyle: EmType.caption.copyWith(color: EmColors.errorContainer),
      prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 22, color: EmColors.onPrimaryDark),
      suffixIcon: suffix,
      constraints: const BoxConstraints(minHeight: 56),
    );
  }
}
