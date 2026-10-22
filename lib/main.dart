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
import 'core/design/design.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
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
      home: const AuthGate(),
    );
  }
}

/// Watches auth state and routes to the right root screen - never shows
/// the home shell without a valid session AND a resolved staff profile,
/// and never gets stuck on a splash screen once bootstrap resolves.
@visibleForTesting
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Worker? _worker;

  @override
  void initState() {
    super.initState();
    final auth = Get.find<AuthController>();
    _splashActive = !_ready(auth);
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

  /// The animated splash stays on top of the next screen until its hand-off
  /// finished (the logo flies into the destination's header). See
  /// eldermin-teacher-app-docs/design/MOTION_SPEC.md section 6.
  late bool _splashActive;

  bool _ready(AuthController auth) => auth.tokenLoginInProgress.value || auth.status.value != AuthStatus.unknown;

  Widget _destination(AuthController auth) {
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
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();

    return Obx(() {
      final ready = _ready(auth);
      // Already resolved when first built (or the splash finished): no overlay.
      // Back to unknown after the hand-off: a plain splash, as before.
      if (!_splashActive) return ready ? _destination(auth) : const SplashScreen();
      final toHeader = auth.status.value == AuthStatus.unauthenticated && !auth.tokenLoginInProgress.value;
      return Stack(
        fit: StackFit.expand,
        children: [
          if (ready) _destination(auth) else const SizedBox.shrink(),
          SplashScreen(
            ready: ready,
            flyToHeader: toHeader,
            onExited: () {
              if (mounted) setState(() => _splashActive = false);
            },
          ),
        ],
      );
    });
  }
}

/// Shown while a `eldermin-teacher://login?token=&slug=` link is validated.
class _LinkSignInScreen extends StatelessWidget {
  const _LinkSignInScreen();

  @override
  Widget build(BuildContext context) => const EmScaffold(
        extendBody: false,
        body: SafeArea(child: EmLoading(label: 'Signing you in...', showLabel: true)),
      );
}
