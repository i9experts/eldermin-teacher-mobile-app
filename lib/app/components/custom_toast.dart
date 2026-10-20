import 'package:flutter/material.dart';
import '../../core/design/design.dart';

/// One-line status toast, styled like the theme's snackbar (ink surface, light text, 16 radius). Shown by `ToastUtil.showToast`, which
/// overlays it; a polite live region so screen readers announce it without stealing focus.
class CustomToast extends StatelessWidget {
  final String message;
  final Color? bgColor;
  final Color? textColor;

  const CustomToast({super.key, required this.message, this.bgColor, this.textColor});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Semantics(
        liveRegion: true,
        container: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: EmSpacing.s16, vertical: EmSpacing.s12),
          margin: const EdgeInsets.symmetric(horizontal: EmSpacing.screenH),
          decoration: BoxDecoration(color: bgColor ?? EmColors.ink, borderRadius: EmRadius.mdAll, boxShadow: EmShadows.soft),
          child: Text(message, style: EmType.body.copyWith(color: textColor ?? EmColors.surface)),
        ),
      ),
    );
  }
}
