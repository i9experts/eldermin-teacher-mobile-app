import 'package:get/get.dart';
import '../../../../core/services/app_preferences.dart';
import '../../auth/controllers/auth_controller.dart';

/// First-launch intro carousel state. Shown once: finishing (or skipping)
/// persists the "intro seen" flag, which survives logout.
class IntroController extends GetxController {
  IntroController({AuthController? auth, Future<void> Function()? markSeen})
      : _auth = auth,
        _markSeen = markSeen ?? AppPreferences.setIntroSeen;
  final AuthController? _auth;
  final Future<void> Function() _markSeen;

  static const int slideCount = 3;

  final page = 0.obs;

  bool get isLast => page.value == slideCount - 1;

  /// Persists the flag, then lets the auth gate move on to login.
  Future<void> finish() async {
    try {
      await _markSeen();
    } catch (_) {/* worst case: shown again next launch */}
    (_auth ?? Get.find<AuthController>()).introSeen.value = true;
  }
}
