import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/design/design.dart';

/// Two-button confirmation dialog ([EmDialog]). Resolves to true only when the confirm button is tapped; Cancel / barrier tap / back
/// resolve false.
class ConfirmDialog {
  static Future<bool> show({
    required String title,
    String? message,
    required String confirmLabel,
    String cancelLabel = 'Cancel',
    bool destructive = false,
  }) async {
    final result = await Get.dialog<bool>(
      EmDialog(
        title: title,
        message: message,
        actions: [
          EmDialogAction(key: const Key('confirm_dialog_cancel'), label: cancelLabel, onPressed: () => Get.back(result: false)),
          EmDialogAction(
            key: const Key('confirm_dialog_confirm'),
            label: confirmLabel,
            tone: destructive ? EmDialogTone.destructive : EmDialogTone.primary,
            onPressed: () => Get.back(result: true),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
