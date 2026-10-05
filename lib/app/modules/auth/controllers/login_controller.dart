import 'package:get/get.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/services/app_preferences.dart';
import 'auth_controller.dart';

/// Sign-in form state. Text controllers live in the screen (so they are
/// disposed with it, not by a global `Get.deleteAll()` on logout); this
/// holds loading / error / UI-toggle state and the submit call.
///
/// A wrong password surfaces as an inline error (the server's own message,
/// e.g. "Invalid credentials"); it never ends a session.
class LoginController extends GetxController {
  LoginController({AuthController? auth, Future<String?> Function()? loadSavedSlug})
      : _auth = auth,
        _loadSavedSlug = loadSavedSlug ?? AppPreferences.getSchoolSlug;

  final AuthController? _auth;
  final Future<String?> Function() _loadSavedSlug;
  AuthController get auth => _auth ?? Get.find<AuthController>();

  final loading = false.obs;
  final error = RxnString();
  final obscure = true.obs;

  /// "Signing in to a specific school?" section.
  final schoolExpanded = false.obs;

  /// The remembered school code (null when none).
  Future<String?> savedSlug() async {
    try {
      final slug = await _loadSavedSlug();
      if (slug != null && slug.trim().isNotEmpty) {
        schoolExpanded.value = true;
        return slug;
      }
    } catch (_) {}
    return null;
  }

  /// Returns true on success. Inputs are validated by the form before this.
  Future<bool> submit({required String email, required String password, String? schoolCode}) async {
    if (loading.value) return false;
    loading.value = true;
    error.value = null;
    auth.loginNotice.value = null;
    try {
      await auth.login(email: email.trim(), password: password, slug: schoolCode);
      return true;
    } on ApiException catch (ex) {
      error.value = ex.message;
    } catch (_) {
      error.value = 'Something went wrong. Please try again.';
    } finally {
      loading.value = false;
    }
    return false;
  }
}
