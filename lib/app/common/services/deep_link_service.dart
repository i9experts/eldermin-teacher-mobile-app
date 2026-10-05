import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../../core/utils/deep_link_parser.dart';
import '../../modules/auth/controllers/auth_controller.dart';
import '../../routes/app_routes.dart';
import '../../utils/toast_util.dart';

/// Receives `eldermin-teacher://` links (cold start via
/// `getInitialLink`, warm start via `uriLinkStream`), validates them with
/// [DeepLinkParser] and routes them.
///
/// Security: credentials in links (reset token, JWT) are held in memory only
/// as long as needed, never logged and never persisted. A pending link is
/// dropped as soon as it has been acted on.
class DeepLinkService extends GetxService {
  DeepLinkService({required AuthController auth, AppLinks? appLinks})
      : _auth = auth,
        _appLinks = appLinks;

  final AuthController _auth;
  final AppLinks? _appLinks;
  StreamSubscription<Uri>? _sub;
  Worker? _statusWorker;

  /// Reset token received via link, waiting for the reset screen to take it.
  final resetToken = Rxn<String>();

  DeepLink? _pending;

  /// Start listening. Safe to call once at startup.
  Future<void> init() async {
    final links = _appLinks ?? AppLinks();
    try {
      final initial = await links.getInitialLink();
      if (initial != null) handleUri(initial);
    } catch (_) {/* no initial link / platform quirk: ignore */}
    _sub = links.uriLinkStream.listen(handleUri, onError: (_) {});
  }

  /// Entry point for every incoming URI (also used by tests).
  void handleUri(Uri uri) {
    final link = DeepLinkParser.parse(uri);
    if (link == null) {
      debugPrint('Ignored an unsupported incoming link');
      return;
    }
    _pending = link;
    _dispatchWhenReady();
  }

  void _dispatchWhenReady() {
    if (_auth.status.value == AuthStatus.unknown) {
      // Cold start: wait until the session check resolves.
      _statusWorker ??= ever(_auth.status, (s) {
        if (s != AuthStatus.unknown) {
          _statusWorker?.dispose();
          _statusWorker = null;
          // After the auth gate has finished reacting to the same change
          // (it pops stale pushed routes), so our push is not popped.
          scheduleMicrotask(_dispatch);
        }
      });
      return;
    }
    _dispatch();
  }

  Future<void> _dispatch() async {
    final link = _pending;
    _pending = null; // clear from in-memory deep-link state right away
    if (link == null) return;

    switch (link) {
      case ResetPasswordLink(:final token):
        resetToken.value = token;
        if (Get.currentRoute != Routes.resetPassword) Get.toNamed(Routes.resetPassword);
      case TokenLoginLink(:final token, :final slug):
        if (_auth.status.value == AuthStatus.authenticated) {
          ToastUtil.showToast("You're already signed in. Sign out first to use that sign-in link.");
          return;
        }
        // Validated against /auth/me before anything is stored.
        await _auth.signInWithToken(token: token, slug: slug);
    }
  }

  /// The reset screen calls this to take (and clear) the token from a link.
  String? takeResetToken() {
    final t = resetToken.value;
    resetToken.value = null;
    return t;
  }

  @override
  void onClose() {
    _sub?.cancel();
    _statusWorker?.dispose();
    super.onClose();
  }
}
