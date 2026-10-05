import 'package:get/get.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/services/auth_api_service.dart';
import '../../../../core/utils/deep_link_parser.dart';
import '../../../common/services/deep_link_service.dart';
import '../../../routes/app_routes.dart';
import '../../../utils/toast_util.dart';
import '../../auth/controllers/auth_controller.dart';

/// `POST /auth/reset-password {token, newPassword}`.
///
/// The token comes from a deep link ([DeepLinkService]) or from the manual
/// "Paste reset code or link" fallback. An invalid/expired token is a 401
/// with a message to show inline - it is NOT a session expiry.
class ResetPasswordController extends GetxController {
  ResetPasswordController({
    AuthApiService? api,
    DeepLinkService? links,
    void Function()? onSuccess,
  })  : _api = api,
        _links = links,
        _onSuccess = onSuccess;

  final AuthApiService? _api;
  final DeepLinkService? _links;
  final void Function()? _onSuccess;
  AuthApiService get api => _api ?? Get.find<AuthApiService>();
  DeepLinkService? get links => _links ?? (Get.isRegistered<DeepLinkService>() ? Get.find<DeepLinkService>() : null);

  /// The token to submit (null until a link was opened or code pasted).
  final token = RxnString();
  final pasteError = RxnString();
  final submitting = false.obs;
  final error = RxnString();
  final obscure = true.obs;

  /// True when the server said the token is invalid/expired.
  final tokenRejected = false.obs;

  Worker? _worker;

  @override
  void onInit() {
    super.onInit();
    final svc = links;
    if (svc != null) {
      _adopt(svc.takeResetToken());
      // Warm start: a new link arrives while this screen is open.
      _worker = ever<String?>(svc.resetToken, (t) {
        if (t != null) _adopt(svc.takeResetToken());
      });
    }
  }

  void _adopt(String? t) {
    if (t == null) return;
    token.value = t;
    pasteError.value = null;
    error.value = null;
    tokenRejected.value = false;
  }

  /// Manual fallback: accepts a bare token or a full https / custom-scheme
  /// link and extracts the token. Returns true when a token was found.
  bool applyPasted(String input) {
    final t = DeepLinkParser.extractResetToken(input);
    if (t == null) {
      pasteError.value = "That doesn't look like a valid reset code or link.";
      return false;
    }
    _adopt(t);
    return true;
  }

  void clearToken() {
    token.value = null;
    tokenRejected.value = false;
    error.value = null;
  }

  Future<bool> submit(String newPassword) async {
    final t = token.value;
    if (t == null || submitting.value) return false;
    submitting.value = true;
    error.value = null;
    try {
      await api.resetPassword(token: t, newPassword: newPassword);
      token.value = null; // single use - drop it
      (_onSuccess ?? _defaultOnSuccess)();
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 401) tokenRejected.value = true;
      error.value = e.message;
    } catch (_) {
      error.value = 'Something went wrong. Please try again.';
    } finally {
      submitting.value = false;
    }
    return false;
  }

  static void _defaultOnSuccess() {
    // Back to the login screen (the auth gate's root), with a toast.
    Get.until((route) => route.isFirst);
    final signedIn = Get.isRegistered<AuthController>() &&
        Get.find<AuthController>().status.value == AuthStatus.authenticated;
    ToastUtil.showToast(signedIn
        ? 'Password updated.'
        : 'Password updated. Please sign in with your new password.');
  }

  @override
  void onClose() {
    _worker?.dispose();
    super.onClose();
  }

  /// Navigates to a fresh "request a new link" screen.
  void requestNewLink() => Get.offNamed(Routes.forgotPassword);
}
