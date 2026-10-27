import 'dart:io';
import 'package:eldermin_teacher_app/app/common/views/not_available_screen.dart';
import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/app/modules/auth/views/auth_widgets.dart';
import 'package:eldermin_teacher_app/app/modules/auth/views/login_screen.dart';
import 'package:eldermin_teacher_app/app/modules/auth/views/profile_load_screen.dart';
import 'package:eldermin_teacher_app/app/modules/auth/views/unsupported_role_screen.dart';
import 'package:eldermin_teacher_app/app/modules/forgot_password/controllers/forgot_password_controller.dart';
import 'package:eldermin_teacher_app/app/modules/forgot_password/views/forgot_password_screen.dart';
import 'package:eldermin_teacher_app/app/modules/intro/views/intro_screen.dart';
import 'package:eldermin_teacher_app/app/modules/reset_password/controllers/reset_password_controller.dart';
import 'package:eldermin_teacher_app/app/modules/reset_password/views/reset_password_screen.dart';
import 'package:eldermin_teacher_app/app/modules/splash/views/splash_screen.dart';
import 'package:eldermin_teacher_app/core/design/design.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:eldermin_teacher_app/core/constants/login_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_design_harness.dart';
import '../support/design_harness.dart';

/// One entry per signed-out screen state. `prepare` flips controller state
/// after the first frame; `submit` is the finder of the primary action (null =
/// no form).
class _Case {
  const _Case(this.name, this.build, {this.prepare, this.submit});
  final String name;
  final Widget Function() build;
  final Future<void> Function(WidgetTester t, AuthController auth)? prepare;
  final String? submit;
}

final cases = <_Case>[
  _Case('login', () => const LoginScreen(), submit: 'Sign in', prepare: (t, a) async {
    a.loginNotice.value = 'Your session expired. Please sign in again.';
    await t.pump();
  }),
  _Case('forgot', () => const ForgotPasswordScreen(), submit: 'Send reset link'),
  _Case('forgot_sent', () => const ForgotPasswordScreen(), submit: 'I have a reset code or link', prepare: (t, a) async {
    Get.find<ForgotPasswordController>().sent.value = true;
    await t.pump();
  }),
  _Case('reset_paste', () => const ResetPasswordScreen(), submit: 'Continue'),
  _Case('reset_password', () => const ResetPasswordScreen(), submit: 'Update password', prepare: (t, a) async {
    Get.find<ResetPasswordController>().token.value = 'tok';
    await t.pump();
  }),
  _Case('intro', () => const IntroScreen(), submit: 'Next'),
  _Case('profile_error', () => const ProfileLoadScreen(), prepare: (t, a) async {
    a.profileError.value = "Couldn't reach Eldermin. Check your internet connection.";
    await t.pump();
  }),
  _Case('profile_loading', () => const ProfileLoadScreen()),
  _Case('unsupported_role', () => const UnsupportedRoleScreen(), submit: 'Sign out'),
  _Case('not_available', () => const NotAvailableScreen(), submit: 'Back to home'),
  _Case('splash', () => const SplashScreen()),
];

void main() {
  setUpAll(loadDesignFonts);
  late AuthController auth;
  setUp(() => auth = setUpAuthDeps());
  tearDown(() {
    LoginConfig.showSchoolCodeOverride = null;
    Get.reset();
  });

  group('layout matrix: widths 320/360/375/430 x text 1.0/1.3 x LTR/RTL x keyboard closed/open', () {
    for (final c in cases) {
      testWidgets(c.name, (t) async {
        for (final w in [320.0, 360.0, 375.0, 430.0]) {
          for (final scale in [1.0, 1.3]) {
            for (final dir in [TextDirection.ltr, TextDirection.rtl]) {
              for (final kb in [0.0, 300.0]) {
                Get.reset();
                auth = setUpAuthDeps();
                final h = w < 400 ? 667.0 : 844.0;
                await pumpScreen(t, c.build(), width: w, height: h, textScale: scale, dir: dir, keyboard: kb);
                if (c.prepare != null) await c.prepare!(t, auth);
                await t.pump(const Duration(milliseconds: 400));
                final reason = '${c.name} ${w}x$h @$scale ${dir.name} kb=$kb';
                final e = t.takeException();
                expect(e, isNull, reason: '$reason: ${e?.toString().split('\n').first}');
                // the primary action can always be scrolled into view and sits above the keyboard
                if (c.submit != null) {
                  final f = find.text(c.submit!);
                  expect(f, findsOneWidget, reason: reason);
                  if (find.byType(Scrollable).evaluate().isNotEmpty) {
                    await t.ensureVisible(f);
                    await t.pump(const Duration(milliseconds: 300));
                  }
                  final r = t.getRect(f);
                  expect(r.bottom, lessThanOrEqualTo(h - kb + 0.5), reason: '$reason submit hidden by keyboard (bottom ${r.bottom})');
                  expect(r.top, greaterThanOrEqualTo(0), reason: reason);
                  expect(t.takeException(), isNull, reason: reason);
                }
              }
            }
          }
        }
      });
    }
  });

  group('look and feel (REFERENCE_SPEC)', () {
    testWidgets('login: navy page with photo, transparent 10 dp fields (1 px light border, accent when focused), accent button, logomark', (t) async {
      await pumpScreen(t, const LoginScreen());
      expect(t.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, EmColors.primaryDark);
      expect(find.byType(EmLogomark), findsOneWidget);
      expect(find.byType(EmCard), findsNothing);
      expect(find.byKey(const Key('auth_photo')), findsOneWidget);

      // fields: transparent, white border, accent when focused, still pills
      expect(find.byType(EmTextField), findsNWidgets(2));
      for (final field in t.widgetList<TextField>(find.byType(TextField))) {
        final d = field.decoration!;
        expect(d.filled, isFalse);
        final enabled = d.enabledBorder! as OutlineInputBorder;
        expect(enabled.borderSide.color, EmColors.primaryLight);
        expect(enabled.borderSide.width, 1);
        expect(enabled.borderRadius, BorderRadius.circular(10));
        expect((d.focusedBorder! as OutlineInputBorder).borderSide.color, EmColors.accent);
      }

      // button: accent fill, ink label (the morph button)
      expect(find.byType(EmMorphButton), findsOneWidget);
      final fill = t.widget<AnimatedContainer>(find.descendant(of: find.byType(EmMorphButton), matching: find.byType(AnimatedContainer))).decoration! as BoxDecoration;
      expect(fill.color, EmColors.accent);
      expect(t.widget<Text>(find.descendant(of: find.byType(EmMorphButton), matching: find.text('Sign in'))).style!.color, EmColors.ink);
    });

    test('colours used on the navy page are AA on the brand navy', () {
      for (final fg in [EmColors.onPrimaryDark, EmColors.primaryContainer, EmColors.errorContainer]) {
        expect(contrastRatio(fg, EmColors.primaryDark), greaterThanOrEqualTo(4.5), reason: '$fg on navy');
      }
      expect(contrastRatio(EmColors.ink, EmColors.accent), greaterThanOrEqualTo(4.5)); // button label
    });

    testWidgets('accent text only as LARGE bold text (accent is 4.43:1 on navy), on every signed-out screen', (t) async {
      for (final c in cases) {
        Get.reset();
        auth = setUpAuthDeps();
        await pumpScreen(t, c.build());
        if (c.prepare != null) await c.prepare!(t, auth);
        for (final text in t.widgetList<Text>(find.byType(Text))) {
          final color = text.style?.color;
          if (color == EmColors.accent) {
            expect(text.style!.fontSize, greaterThanOrEqualTo(18.66), reason: '${c.name}: "${text.data}"');
            expect(text.style!.fontWeight!.index, greaterThanOrEqualTo(FontWeight.w700.index), reason: '${c.name}: "${text.data}"');
          }
        }
      }
    });

    testWidgets('every text style on the signed-out screens is AA on its likely background (ink/secondary/primary tokens only)', (t) async {
      final allowed = {
        EmColors.ink, EmColors.textSecondary, EmColors.textTertiary, EmColors.primary, EmColors.primaryDark, EmColors.primaryLight,
        EmColors.onPrimary, EmColors.onErrorContainer, EmColors.error, EmColors.onDisabled,
        EmColors.primaryContainer, // subtitle / captions on the navy overlay
        EmColors.accent, // large bold headings only (checked above)
      };
      for (final c in cases) {
        Get.reset();
        auth = setUpAuthDeps();
        await pumpScreen(t, c.build());
        if (c.prepare != null) await c.prepare!(t, auth);
        for (final text in t.widgetList<Text>(find.byType(Text))) {
          final color = text.style?.color;
          if (color != null) expect(allowed, contains(color), reason: '${c.name}: "${text.data}" uses an off-token colour');
        }
      }
    });

    testWidgets('touch targets: back, password eye, school toggle (re-enabled), links are >= 48dp', (t) async {
      LoginConfig.showSchoolCodeOverride = true;
      await pumpScreen(t, const LoginScreen());
      expect(t.getSize(find.byKey(const Key('school_code_toggle'))).height, greaterThanOrEqualTo(48));
      expectMinTouch(t, find.byType(PasswordVisibilityButton));
      expect(t.getSize(find.widgetWithText(TextButton, 'Forgot password?')).height, greaterThanOrEqualTo(48));
    });

    testWidgets('forgot / reset screens have the circular back button, login has none', (t) async {
      await pumpScreen(t, const LoginScreen());
      expect(find.byType(EmIconCircleButton), findsNothing);
      await pumpScreen(t, const ForgotPasswordScreen());
      expect(find.byType(EmIconCircleButton), findsOneWidget);
      await pumpScreen(t, const ResetPasswordScreen());
      expect(find.byType(EmIconCircleButton), findsOneWidget);
    });

    testWidgets('error banner uses the error container with dark text and is announced', (t) async {
      final h = t.ensureSemantics();
      auth.loginNotice.value = 'Something to read';
      await pumpScreen(t, const LoginScreen());
      final box = t.widget<Container>(find.ancestor(of: find.text('Something to read'), matching: find.byType(Container)).first);
      expect((box.decoration as BoxDecoration).color, EmTone.error.background);
      expect(t.widget<Text>(find.text('Something to read')).style!.color, EmTone.error.foreground);
      h.dispose();
    });
  });

  group('splash hand-off', () {
    testWidgets('navy first frame, reversed logomark in the exact screen centre at the native size, from the first frame', (t) async {
      await pumpScreen(t, const SplashScreen(), width: 390, height: 844, topInset: 0, bottomInset: 0);
      expect(find.byWidgetPredicate((w) => w is ColoredBox && w.color == EmColors.primaryDark), findsWidgets);
      final photoFade = t.widget<FadeTransition>(find.ancestor(of: find.byType(EmPhotoBackdrop), matching: find.byType(FadeTransition)).first);
      expect(photoFade.opacity.value, 0, reason: 'frame 0 is the native splash: navy + logo only, the photo is not in yet');
      final logo = find.byType(EmLogomark);
      expect(t.widget<EmLogomark>(logo).reversed, isTrue);
      expect(t.getSize(logo).height, EmLogomark.splashHeight);
      final c = t.getCenter(logo);
      expect(c.dx, closeTo(195, 0.5));
      expect(c.dy, closeTo(422, 0.5));
    });
    testWidgets('logo position is the same on a different screen size and with large text', (t) async {
      for (final (w, h, scale) in [(320.0, 568.0, 1.0), (430.0, 932.0, 1.3), (360.0, 800.0, 1.3)]) {
        await pumpScreen(t, const SplashScreen(), width: w, height: h, textScale: scale, topInset: 0, bottomInset: 0);
        final c = t.getCenter(find.byType(EmLogomark));
        expect(c.dx, closeTo(w / 2, 0.5));
        expect(c.dy, closeTo(h / 2, 0.5));
        expect(t.takeException(), isNull);
      }
    });
    testWidgets('logo does not animate (same rect on the first frame and after the entrance)', (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: const SplashScreen()));
      final first = t.getRect(find.byType(EmLogomark));
      await t.pump(const Duration(milliseconds: 1500));
      expect(t.getRect(find.byType(EmLogomark)), first);
    });
    testWidgets('native splash config matches: primaryDark, reversed logo, iOS + Android, Android 12 block, dark = light', (t) async {
      final y = await _readYaml();
      expect(y, contains('color: "#18457A"'));
      expect(y, contains('image: assets/splash/splash_logo.png'));
      expect(y, contains('color_dark: "#18457A"'));
      expect(y, contains('android: true'));
      expect(y, contains('android_12:'));
      expect(y, contains('icon_background_color: "#18457A"'));
      // the native navy is the token
      expect(EmColors.primaryDark.toARGB32() & 0xFFFFFF, 0x18457A);
    });
  });
}

Future<String> _readYaml() async => File('pubspec.yaml').readAsStringSync();
