import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../components/common_image_view.dart';
import '../../../components/custom_text.dart';
import '../../../config/app_images.dart';

/// Shared layout for the signed-out screens (login, forgot / reset
/// password): logo, title, subtitle, then the form content.
class AuthPageShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;
  const AuthPageShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: showBack
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              foregroundColor: AppColors.primaryColor,
              iconTheme: const IconThemeData(color: AppColors.primaryColor),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(
                    height: 84,
                    child: CommonImageView(imagePath: AppImages.fullLogo, fit: BoxFit.contain),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CustomText(
                      text: title,
                      textAlign: TextAlign.center,
                      color: AppColors.primaryColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w800),
                  const SizedBox(height: 4),
                  CustomText(text: subtitle, textAlign: TextAlign.center, color: AppColors.muted, fontSize: 13),
                  const SizedBox(height: AppSpacing.xl),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline message box (errors in red, notices in amber).
class AuthBanner extends StatelessWidget {
  final String message;
  final bool isError;
  const AuthBanner({super.key, required this.message, this.isError = true});

  @override
  Widget build(BuildContext context) {
    final fg = isError ? AppColors.error : AppColors.primaryColor;
    final bg = isError ? AppColors.redBg : AppColors.pale;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md - 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isError ? Icons.error_outline_rounded : Icons.info_outline_rounded, color: fg, size: 18),
          const SizedBox(width: 8),
          Expanded(child: CustomText(text: message, color: fg, fontSize: 12.5)),
        ],
      ),
    );
  }
}

/// Eye icon button for password fields.
class PasswordVisibilityButton extends StatelessWidget {
  final bool obscured;
  final VoidCallback onToggle;
  const PasswordVisibilityButton({super.key, required this.obscured, required this.onToggle});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onToggle,
        child: Icon(obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
      );
}
