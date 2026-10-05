import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_theme.dart';
import 'custom_text.dart';

/// Two-button confirmation dialog in the app's dialog style (rounded
/// [AlertDialog], [CustomText], [AppColors]). Resolves to true only when
/// the confirm button is tapped; Cancel / barrier tap / back resolve false.
class ConfirmDialog {
  static Future<bool> show({
    required String title,
    String? message,
    required String confirmLabel,
    String cancelLabel = 'Cancel',
    bool destructive = false,
  }) async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: CustomText(text: title, fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.black),
        content: message == null
            ? null
            : CustomText(text: message, fontSize: 14, color: AppColors.grey, height: 1.5),
        actions: [
          TextButton(
            key: const Key('confirm_dialog_cancel'),
            onPressed: () => Get.back(result: false),
            child: CustomText(text: cancelLabel, color: AppColors.grey),
          ),
          TextButton(
            key: const Key('confirm_dialog_confirm'),
            onPressed: () => Get.back(result: true),
            child: CustomText(
              text: confirmLabel,
              color: destructive ? Colors.red.shade700 : AppColors.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
