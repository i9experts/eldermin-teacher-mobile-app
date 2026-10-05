import 'package:eldermin_teacher_app/core/theme/app_theme.dart';

import 'common_image_view.dart';
import 'custom_text.dart';
import 'svg_icon.dart';
// import '../config/app_colors.dart';
import '../config/app_icons.dart';
import '../config/app_images.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CustomAppSnackbar {
  static void show({
    required String title,
    required String message,
    String imagePath = AppImages.logoImage,
    Color textColor = AppColors.black,
    Color backgroundColor = AppColors.white,
    Color accentColor = AppColors.accentColor,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    Get.rawSnackbar(
      snackPosition: SnackPosition.TOP,
      backgroundColor: AppColors.transparent,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      padding: EdgeInsets.zero,
      duration: const Duration(seconds: 3),
      isDismissible: true,
      forwardAnimationCurve: Curves.easeOutBack,
      reverseAnimationCurve: Curves.easeIn,
      messageText: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          // gradient: AppColors.appbarGradient,
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: accentColor.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            // if (imagePath != null)
            Container(
              height: 42,
              width: 42,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: AppColors.white.withOpacity(0.1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: CommonImageView(imagePath: imagePath, fit: BoxFit.cover),
              ),
            ),

            /// 🔹 TEXT CONTENT
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText(
                    text: title,
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  const SizedBox(height: 4),
                  CustomText(
                    text: message,
                    color: textColor.withOpacity(0.75),
                    fontSize: 12,
                  ),
                ],
              ),
            ),

            /// 🔥 ACTION BUTTON (Optional)
            // if (actionLabel != null)
            GestureDetector(
              onTap: () {
                Get.closeCurrentSnackbar();
                if (onAction != null) onAction();
              },
              child: Container(
                padding: const EdgeInsets.all(5),
                // margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SvgIcon(
                  assetName: AppIcons.cross,
                  color: textColor,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void success(String message) {
    show(title: "Success", message: message, accentColor: AppColors.seaGreen);
  }

  static void error(String message) {
    show(title: "Error", message: message, accentColor: AppColors.red);
  }

  static void warning(String message) {
    show(title: "Warning", message: message, accentColor: AppColors.orange);
  }
}
