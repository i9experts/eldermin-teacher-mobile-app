import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/em_colors.dart';
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

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
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
      style: EmType.body.copyWith(color: enabled ? EmColors.ink : EmColors.onDisabled),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        errorText: errorText,
        errorMaxLines: 3,
        helperMaxLines: 3,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 22),
        suffixIcon: suffix,
        constraints: const BoxConstraints(minHeight: 56),
      ),
    );
  }
}
