import 'package:eldermin_teacher_app/core/theme/app_theme.dart';

import 'common_image_view.dart';
import 'custom_text.dart';
// import '../config/app_colors.dart';
import '../config/app_images.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// A lightweight, branded toast for a short one-line status update — for
/// a title + message + accent color, use [CustomAppSnackbar] instead.
/// Shown via [Get.rawSnackbar], which already handles the slide/fade
/// transition, so this widget only supplies the content.
class CustomToast extends StatelessWidget {
  final String message;
  final String? imagePath;
  final Color bgColor;
  final Color textColor;

  const CustomToast({
    super.key,
    required this.message,
    this.imagePath,
    required this.bgColor,
    required this.textColor,
  });

  static void show(String message, {Color? bgColor, Color? textColor}) {
    Get.rawSnackbar(
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.transparent,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: EdgeInsets.zero,
      messageText: CustomToast(
        message: message,
        bgColor: bgColor ?? AppColors.blackColor,
        textColor: textColor ?? AppColors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 28,
              width: 28,
              margin: const EdgeInsets.only(right: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CommonImageView(
                  imagePath: imagePath ?? AppImages.fullLogo,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Flexible(
              child: CustomText(
                text: message,
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
