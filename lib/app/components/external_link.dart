import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/safe_text.dart';
import 'confirm_dialog.dart';

/// Opens a server-supplied link in the system browser ONLY after the user confirms, and only for absolute http(s) URLs. Never inside the app.
class ExternalLinks {
  ExternalLinks._();

  /// Test seam: replace to capture launches without a platform channel.
  static Future<bool> Function(Uri uri) launcher = (u) => launchUrl(u, mode: LaunchMode.externalApplication);

  /// [allowContact] additionally accepts `mailto:` and `tel:` (links inside rich text); attachments and everything else stay http(s) only.
  static Future<void> openWithConfirm(String? url, {bool allowContact = false}) async {
    final u = allowContact ? safeLinkUri(url) : safeExternalUri(url);
    if (u == null) return;
    final web = u.scheme == 'http' || u.scheme == 'https';
    final ok = await ConfirmDialog.show(
      title: 'Open this link?',
      message: 'It opens outside Eldermin Teacher:\n${web ? '${u.host}${u.path.length > 1 ? u.path : ''}' : u.toString()}',
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

  /// "Email support": opens the mail app for an address WE configured (never server text). If no mail app answers, the address is copied.
  static Future<void> openMail(String email) async {
    try {
      if (await launcher(Uri(scheme: 'mailto', path: email))) return;
    } catch (_) {}
    await Clipboard.setData(ClipboardData(text: email));
    _snack('No mail app found. The address was copied.');
  }

  static void _snack(String m) {
    final ctx = Get.context;
    if (ctx != null) ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(SnackBar(content: Text(m)));
  }
}
