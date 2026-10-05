import 'package:eldermin_teacher_app/app/common/services/deep_link_service.dart';
import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/app/modules/auth/views/login_screen.dart';
import 'package:eldermin_teacher_app/app/modules/forgot_password/controllers/forgot_password_controller.dart';
import 'package:eldermin_teacher_app/app/modules/forgot_password/views/forgot_password_screen.dart';
import 'package:eldermin_teacher_app/app/modules/intro/controllers/intro_controller.dart';
import 'package:eldermin_teacher_app/app/modules/intro/views/intro_screen.dart';
import 'package:eldermin_teacher_app/app/modules/reset_password/controllers/reset_password_controller.dart';
import 'package:eldermin_teacher_app/app/modules/reset_password/views/reset_password_screen.dart';
import 'package:eldermin_teacher_app/core/models/auth_me.dart';
import 'package:eldermin_teacher_app/core/models/institution.dart';
import 'package:eldermin_teacher_app/core/models/login_result.dart';
import 'package:eldermin_teacher_app/core/models/staff_me.dart';
import 'package:eldermin_teacher_app/core/models/teacher_user.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/network/base_client.dart';
import 'package:eldermin_teacher_app/core/services/auth_api_service.dart';
import 'package:eldermin_teacher_app/core/services/permission_service.dart';
import 'package:eldermin_teacher_app/core/services/token_store.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _hex = 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';

class _MemTokens implements TokenStore {
  String? token;
  @override
  Future<String?> readToken() async => token;
  @override
  Future<void> saveToken(String t) async => token = t;
  @override
  Future<void> clearAll() async => token = null;
}

class _FakeApi extends AuthApiService {
  _FakeApi() : super(BaseClient());
  final loginCalls = <Map<String, String?>>[];
  ApiException? loginError;
  final forgotCalls = <String>[];
  ApiException? forgotError;
  final resetCalls = <Map<String, String>>[];
  ApiException? resetError;

  @override
  Future<LoginResult> login({required String email, required String password, String? slug}) async {
    loginCalls.add({'email': email, 'password': password, 'slug': slug});
    if (loginError != null) throw loginError!;
    return LoginResult(
      accessToken: 'a.b.c',
      user: TeacherUser(id: 'u', name: 'T', email: email, role: 'teacher'),
      institution: const Institution(slug: 's'),
    );
  }

  @override
  Future<AuthMe> fetchAuthMe({String? token}) async =>
      const AuthMe(id: 'u', name: 'T', email: 'a@s.test', role: 'teacher');

  @override
  Future<StaffMe> fetchStaffMe() async => StaffMe.fromJson({
        'user': {'id': 'u', 'name': 'T', 'email': 'a@s.test', 'role': 'teacher'},
        'staffId': 's1',
        'teacherProfile': {'isClassTeacher': false},
        'institution': {'slug': 's'},
      });

  @override
  Future<void> forgotPassword(String email) async {
    forgotCalls.add(email);
    if (forgotError != null) throw forgotError!;
  }

  @override
  Future<void> resetPassword({required String token, required String newPassword}) async {
    resetCalls.add({'token': token, 'password': newPassword});
    if (resetError != null) throw resetError!;
  }

  @override
  Future<void> logout() async {}
}

late _FakeApi api;
late AuthController auth;

Future<void> _pump(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: screen));
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.testMode = true;
    api = _FakeApi();
    auth = AuthController(
      api: api,
      permissions: PermissionService(),
      tokenStore: _MemTokens(),
      minSplash: Duration.zero,
      resetScopedControllers: () async {},
      notify: (_) {},
    )..status.value = AuthStatus.unauthenticated;
    Get.put<AuthApiService>(api);
    Get.put<AuthController>(auth);
  });

  tearDown(Get.reset);

  Finder field(String hint) => find.widgetWithText(TextFormField, hint);

  group('LoginScreen', () {
    testWidgets('empty form shows required-field errors and does not call the API', (tester) async {
      await _pump(tester, const LoginScreen());
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      expect(api.loginCalls, isEmpty);
    });

    testWidgets('invalid email format is rejected', (tester) async {
      await _pump(tester, const LoginScreen());
      await tester.enterText(field('Email'), 'not-an-email');
      await tester.enterText(field('Password'), 'secret1');
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(api.loginCalls, isEmpty);
    });

    testWidgets('valid credentials sign in (no school code sent when collapsed)', (tester) async {
      await _pump(tester, const LoginScreen());
      await tester.enterText(field('Email'), '  tess@stub.test ');
      await tester.enterText(field('Password'), 'StubPass123');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(api.loginCalls.single['email'], 'tess@stub.test');
      expect(api.loginCalls.single['slug'], '');
      expect(auth.status.value, AuthStatus.authenticated);
    });

    testWidgets('401 shows the server message inline and does not log out or toast session expiry', (tester) async {
      api.loginError = ApiException('Invalid credentials', statusCode: 401);
      await _pump(tester, const LoginScreen());
      await tester.enterText(field('Email'), 'tess@stub.test');
      await tester.enterText(field('Password'), 'wrongpass');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Invalid credentials'), findsOneWidget);
      expect(auth.status.value, AuthStatus.unauthenticated);
      expect(find.text('Sign in'), findsOneWidget); // button back to idle, not stuck loading
    });

    testWidgets('school code is hidden until the toggle is tapped, then sent', (tester) async {
      await _pump(tester, const LoginScreen());
      expect(field('School code'), findsNothing);
      await tester.tap(find.byKey(const Key('school_code_toggle')));
      await tester.pump();
      expect(field('School code'), findsOneWidget);
      await tester.enterText(field('Email'), 'tess@stub.test');
      await tester.enterText(field('Password'), 'StubPass123');
      await tester.enterText(field('School code'), 'demo-school');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(api.loginCalls.single['slug'], 'demo-school');
    });

    testWidgets('a remembered school code is prefilled and the section is expanded', (tester) async {
      SharedPreferences.setMockInitialValues({'eldermin_teacher_school_slug': 'demo-school'});
      await _pump(tester, const LoginScreen());
      await tester.pumpAndSettle();
      expect(field('School code'), findsOneWidget);
      expect(find.text('demo-school'), findsOneWidget);
    });

    testWidgets('show/hide password toggles obscuring', (tester) async {
      await _pump(tester, const LoginScreen());
      EditableText editable() => tester.widget<EditableText>(
          find.descendant(of: field('Password'), matching: find.byType(EditableText)));
      expect(editable().obscureText, isTrue);
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();
      expect(editable().obscureText, isFalse);
    });

    testWidgets('a failed token deep-link shows its notice banner', (tester) async {
      auth.loginNotice.value = 'This sign-in link is invalid or has expired.';
      await _pump(tester, const LoginScreen());
      expect(find.textContaining('invalid or has expired'), findsOneWidget);
    });
  });

  group('ForgotPasswordScreen', () {
    testWidgets('validates the email', (tester) async {
      await _pump(tester, const ForgotPasswordScreen());
      await tester.tap(find.text('Send reset link'));
      await tester.pump();
      expect(find.text('Enter your email address.'), findsOneWidget);
      await tester.enterText(field('Email'), 'nope');
      await tester.tap(find.text('Send reset link'));
      await tester.pump();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(api.forgotCalls, isEmpty);
    });

    testWidgets('shows the same generic success screen regardless of the email', (tester) async {
      await _pump(tester, const ForgotPasswordScreen());
      await tester.enterText(field('Email'), 'whoever@stub.test');
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();
      expect(api.forgotCalls, ['whoever@stub.test']);
      expect(find.text('Check your email'), findsOneWidget);
      expect(find.text(ForgotPasswordController.genericMessage), findsOneWidget);
    });

    testWidgets('a network failure is shown inline (no success screen)', (tester) async {
      api.forgotError = ApiException('No internet connection.');
      await _pump(tester, const ForgotPasswordScreen());
      await tester.enterText(field('Email'), 'a@stub.test');
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();
      expect(find.text('No internet connection.'), findsOneWidget);
      expect(find.text('Check your email'), findsNothing);
    });
  });

  group('ResetPasswordScreen', () {
    late int successCalls;
    setUp(() {
      successCalls = 0;
      Get.put<ResetPasswordController>(ResetPasswordController(api: api, onSuccess: () => successCalls++));
    });

    Future<void> pasteAndContinue(WidgetTester tester, String text) async {
      await tester.enterText(field('Paste reset code or link'), text);
      await tester.tap(find.text('Continue'));
      await tester.pump();
    }

    testWidgets('without a token it asks to paste a code or link', (tester) async {
      await _pump(tester, const ResetPasswordScreen());
      expect(field('Paste reset code or link'), findsOneWidget);
      expect(field('New password'), findsNothing);
    });

    testWidgets('paste fallback extracts the token from a full https link', (tester) async {
      await _pump(tester, const ResetPasswordScreen());
      await pasteAndContinue(tester, 'https://app.eldermin.com/reset-password?token=$_hex');
      expect(field('New password'), findsOneWidget);
      expect(Get.find<ResetPasswordController>().token.value, _hex);
    });

    testWidgets('paste fallback extracts the token from a custom-scheme link', (tester) async {
      await _pump(tester, const ResetPasswordScreen());
      await pasteAndContinue(tester, 'eldermin-teacher://reset-password?token=$_hex');
      expect(Get.find<ResetPasswordController>().token.value, _hex);
    });

    testWidgets('paste fallback accepts a bare token', (tester) async {
      await _pump(tester, const ResetPasswordScreen());
      await pasteAndContinue(tester, '  $_hex  ');
      expect(Get.find<ResetPasswordController>().token.value, _hex);
    });

    testWidgets('paste fallback rejects junk and foreign links', (tester) async {
      await _pump(tester, const ResetPasswordScreen());
      await pasteAndContinue(tester, 'https://evil.com/reset-password?token=$_hex');
      expect(find.textContaining("doesn't look like a valid reset code"), findsOneWidget);
      expect(Get.find<ResetPasswordController>().token.value, isNull);
      await pasteAndContinue(tester, 'javascript:alert(1)');
      expect(Get.find<ResetPasswordController>().token.value, isNull);
    });

    testWidgets('password rules: min 6 (backend DTO) and confirmation must match', (tester) async {
      await _pump(tester, const ResetPasswordScreen());
      await pasteAndContinue(tester, _hex);
      await tester.enterText(field('New password'), '12345');
      await tester.enterText(field('Confirm new password'), '12345');
      await tester.tap(find.text('Update password'));
      await tester.pump();
      expect(find.text('Password must be at least 6 characters.'), findsOneWidget);

      await tester.enterText(field('New password'), 'abcdef');
      await tester.enterText(field('Confirm new password'), 'abcdeg');
      await tester.tap(find.text('Update password'));
      await tester.pump();
      expect(find.text("Passwords don't match."), findsOneWidget);
      expect(api.resetCalls, isEmpty);
    });

    testWidgets('success submits token + password then finishes (back to login)', (tester) async {
      await _pump(tester, const ResetPasswordScreen());
      await pasteAndContinue(tester, _hex);
      await tester.enterText(field('New password'), 'abcdef');
      await tester.enterText(field('Confirm new password'), 'abcdef');
      await tester.tap(find.text('Update password'));
      await tester.pumpAndSettle();
      expect(api.resetCalls.single, {'token': _hex, 'password': 'abcdef'});
      expect(successCalls, 1);
      expect(Get.find<ResetPasswordController>().token.value, isNull); // single-use token dropped
    });

    testWidgets('invalid/expired token shows the server message and offers a new link', (tester) async {
      api.resetError = ApiException('This reset link is invalid or has expired', statusCode: 401);
      await _pump(tester, const ResetPasswordScreen());
      await pasteAndContinue(tester, _hex);
      await tester.enterText(field('New password'), 'abcdef');
      await tester.enterText(field('Confirm new password'), 'abcdef');
      await tester.tap(find.text('Update password'));
      await tester.pumpAndSettle();
      expect(find.text('This reset link is invalid or has expired'), findsOneWidget);
      expect(find.text('Request a new reset link'), findsOneWidget);
      expect(successCalls, 0);
      expect(auth.status.value, AuthStatus.unauthenticated); // not treated as session expiry
    });

    testWidgets('a token from a deep link skips the paste step', (tester) async {
      Get.reset();
      Get.testMode = true;
      Get.put<AuthApiService>(api);
      Get.put<AuthController>(auth);
      final svc = Get.put<DeepLinkService>(DeepLinkService(auth: auth));
      svc.resetToken.value = _hex;
      Get.put<ResetPasswordController>(ResetPasswordController(api: api, links: svc, onSuccess: () {}));
      await _pump(tester, const ResetPasswordScreen());
      expect(field('New password'), findsOneWidget);
      expect(svc.resetToken.value, isNull); // taken + cleared from deep-link state
    });
  });

  group('IntroScreen', () {
    testWidgets('three slides; Get started on the last persists the flag and flips introSeen', (tester) async {
      auth.introSeen.value = false;
      var saved = 0;
      Get.put<IntroController>(IntroController(auth: auth, markSeen: () async => saved++));
      await _pump(tester, const IntroScreen());
      expect(find.text('Next'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Get started'), findsOneWidget);
      expect(auth.introSeen.value, isFalse);
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      expect(saved, 1);
      expect(auth.introSeen.value, isTrue);
    });

    testWidgets('Skip finishes immediately', (tester) async {
      auth.introSeen.value = false;
      var saved = 0;
      Get.put<IntroController>(IntroController(auth: auth, markSeen: () async => saved++));
      await _pump(tester, const IntroScreen());
      await tester.tap(find.byKey(const Key('intro_skip')));
      await tester.pumpAndSettle();
      expect(saved, 1);
      expect(auth.introSeen.value, isTrue);
    });
  });
}
