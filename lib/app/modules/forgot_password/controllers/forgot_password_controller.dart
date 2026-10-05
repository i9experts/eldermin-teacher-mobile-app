import 'package:get/get.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/services/auth_api_service.dart';

/// `POST /auth/forgot-password`. The backend answers with the same generic
/// message whether or not the account exists, and so does this screen: on
/// success we show a fixed message, never anything server-derived.
class ForgotPasswordController extends GetxController {
  ForgotPasswordController({AuthApiService? api}) : _api = api;
  final AuthApiService? _api;
  AuthApiService get api => _api ?? Get.find<AuthApiService>();

  static const String genericMessage =
      'If an account exists for that email, we have sent a link to reset your password. '
      'It is valid for one hour.';

  final submitting = false.obs;
  final sent = false.obs;
  final error = RxnString();

  Future<void> submit(String email) async {
    if (submitting.value) return;
    submitting.value = true;
    error.value = null;
    try {
      await api.forgotPassword(email.trim());
      sent.value = true;
    } on ApiException catch (e) {
      error.value = e.message;
    } catch (_) {
      error.value = 'Something went wrong. Please try again.';
    } finally {
      submitting.value = false;
    }
  }

  void reset() {
    sent.value = false;
    error.value = null;
  }
}
