import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../../core/network/api_exception.dart';
import 'auth_controller.dart';

/// Minimal Phase-2 login logic (full flow - school code UX, deep links,
/// forgot/reset - is Phase 3). A wrong password surfaces as an inline
/// error; it never ends a session.
class LoginController extends GetxController {
  final email = TextEditingController();
  final password = TextEditingController();
  final schoolCode = TextEditingController();

  final loading = false.obs;
  final error = RxnString();
  final obscure = true.obs;

  Future<void> submit() async {
    final e = email.text.trim();
    final p = password.text;
    if (e.isEmpty || p.isEmpty) {
      error.value = 'Enter your email and password.';
      return;
    }
    loading.value = true;
    error.value = null;
    try {
      await Get.find<AuthController>().login(email: e, password: p, slug: schoolCode.text);
    } on ApiException catch (ex) {
      error.value = ex.statusCode == 401 ? 'Invalid email or password.' : ex.message;
    } catch (_) {
      error.value = 'Something went wrong. Please try again.';
    } finally {
      loading.value = false;
    }
  }

  @override
  void onClose() {
    email.dispose();
    password.dispose();
    schoolCode.dispose();
    super.onClose();
  }
}
