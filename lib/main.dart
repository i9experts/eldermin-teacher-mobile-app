import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app/common/bindings/initial_binding.dart';
import 'app/common/services/deep_link_service.dart';
import 'app/modules/auth/controllers/auth_controller.dart';
import 'app/modules/auth/views/login_screen.dart';
import 'app/modules/auth/views/profile_load_screen.dart';
import 'app/modules/auth/views/unsupported_role_screen.dart';
import 'app/modules/home/views/home_shell.dart';
import 'app/modules/intro/views/intro_screen.dart';
import 'app/modules/splash/views/splash_screen.dart';
import 'app/routes/app_pages.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_widgets.dart';
import 'app/components/custom_text.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EldeminTeacherApp());
}

class EldeminTeacherApp extends StatelessWidget {
  const EldeminTeacherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Eldermin Teacher',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialBinding: InitialBinding(),
      getPages: AppPages.pages,
      home: const _AuthGate(),
    );
  }
}

/// Watches auth state and routes to the right root screen - never shows
/// the home shell without a valid session AND a resolved staff profile,
/// and never gets stuck on a splash screen once bootstrap resolves.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  Worker? _worker;

  @override
  void initState() {
    super.initState();
    final auth = Get.find<AuthController>();
    Get.find<DeepLinkService>().init(); // cold + warm start links
    // Whenever auth status actually changes (login OR logout/401), clear
    // any pushed routes (e.g. forgot-password, or some deep screen open
    // when a session expired) so the new root screen is what the user
    // actually sees, not hidden underneath a stale pushed route.
    _worker = ever(auth.status, (_) {
      if (Get.key.currentState?.canPop() ?? false) {
        Get.until((route) => route.isFirst);
      }
    });
  }

  @override
  void dispose() {
    _worker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();

    return Obx(() {
      if (auth.tokenLoginInProgress.value) return const _LinkSignInScreen();
      switch (auth.status.value) {
        case AuthStatus.unknown:
          return const SplashScreen();
        case AuthStatus.unauthenticated:
          return auth.introSeen.value ? const LoginScreen() : const IntroScreen();
        case AuthStatus.authenticated:
          if (!auth.roleSupported.value) return const UnsupportedRoleScreen();
          if (auth.staffMe.value == null) return const ProfileLoadScreen();
          return const HomeShell();
      }
    });
  }
}

/// Shown while a `eldermin-teacher://login?token=&slug=` link is validated.
class _LinkSignInScreen extends StatelessWidget {
  const _LinkSignInScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppLoader(),
              SizedBox(height: AppSpacing.md),
              Center(child: CustomText(text: 'Signing you in...', color: AppColors.muted, fontSize: 13)),
            ],
          ),
        ),
      );
}
