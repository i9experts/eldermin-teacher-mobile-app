import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/safe_text.dart';
import 'confirm_dialog.dart';

/// Opens a server-supplied link in the system browser ONLY after the user confirms, and only for absolute http(s) URLs. Never inside the app.
class ExternalLinks {
  ExternalLinks._();

  /// Test seam: replace to capture launches without a platform channel.
  static Future<bool> Function(Uri uri) launcher = (u) => launchUrl(u, mode: LaunchMode.externalApplication);

  static Future<void> openWithConfirm(String? url) async {
    final u = safeExternalUri(url);
    if (u == null) return;
    final ok = await ConfirmDialog.show(
      title: 'Open this link?',
      message: 'It opens in your browser, outside Eldermin Teacher:\n${u.host}${u.path.length > 1 ? u.path : ''}',
      confirmLabel: 'Open',
    );
    if (!ok) return;
    try {
      final launched = await launcher(u);
      if (!launched) _snack("Couldn't open the link.");
    } catch (_) {
      _snack("Couldn't open the link.");
    }
  }

  static void _snack(String m) {
    final ctx = Get.context;
    if (ctx != null) ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(SnackBar(content: Text(m)));
  }
}
