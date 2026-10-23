import 'package:eldermin_teacher_app/app/modules/auth/views/auth_widgets.dart' show AuthBanner, AuthPhotoSize, AuthPageShell;
import 'package:eldermin_teacher_app/app/modules/forgot_password/controllers/forgot_password_controller.dart';
import 'package:eldermin_teacher_app/app/modules/forgot_password/views/forgot_password_screen.dart';
import 'package:eldermin_teacher_app/app/modules/reset_password/controllers/reset_password_controller.dart';
import 'package:eldermin_teacher_app/app/modules/reset_password/views/reset_password_screen.dart';
import 'package:eldermin_teacher_app/core/design/design.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:eldermin_teacher_app/core/utils/password_strength.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_design_harness.dart';
import '../support/design_harness.dart';

Future<void> mount(WidgetTester t, Widget screen, {bool reduce = false, double width = 390, double height = 844, double scale = 1}) async {
  setUpAuthDeps();
  t.view.physicalSize = Size(width, height);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(GetMaterialApp(
    theme: AppTheme.light,
    builder: (context, c) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduce, textScaler: TextScaler.linear(scale), padding: const EdgeInsets.only(top: 47, bottom: 34)),
      child: c!,
    ),
    home: screen,
  ));
  await t.pump();
  await t.pump(const Duration(milliseconds: 1200));
}

NodeScenePainter glyph(WidgetTester t) =>
    t.widget<CustomPaint>(find.descendant(of: find.byType(EmAssembleGlyph), matching: find.byWidgetPredicate((w) => w is CustomPaint && w.painter is NodeScenePainter))).painter! as NodeScenePainter;

StrengthPainter strength(WidgetTester t) =>
    t.widget<CustomPaint>(find.descendant(of: find.byType(EmStrengthNodes), matching: find.byWidgetPredicate((w) => w is CustomPaint && w.painter is StrengthPainter))).painter! as StrengthPainter;

void main() {
  setUpAll(loadDesignFonts);
  tearDown(() {
    Get.reset();
    EmLogoHandoff.reset();
  });

  group('forgot password', () {
    testWidgets('form: short photo header with the logo tile (no glyph yet), the back circle, staggered items', (t) async {
      await mount(t, const ForgotPasswordScreen());
      expect(find.byKey(const Key('auth_photo')), findsOneWidget);
      expect(t.widget<AuthPageShell>(find.byType(AuthPageShell)).photoSize, AuthPhotoSize.short);
      expect(find.byType(EmLogoTile), findsOneWidget);
      expect(find.byType(EmAssembleGlyph), findsNothing);
      expect(find.byType(EmIconCircleButton), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.text("Enter your email and we'll send you a reset link"), findsOneWidget);
      expect(find.text('Send reset link'), findsOneWidget);
    });

    testWidgets('success: the nodes assemble into an envelope on the photo header (scattered -> in place), the existing message shows', (t) async {
      await mount(t, const ForgotPasswordScreen());
      final shell = t.element(find.byType(AuthPageShell));
      Get.find<ForgotPasswordController>().sent.value = true;
      await t.pump();
      await t.pump(const Duration(milliseconds: 40));
      expect(glyph(t).layouts, EmScenes.envelope);
      expect(glyph(t).value, lessThan(0.1), reason: 'starts scattered');
      await t.pump(const Duration(milliseconds: 250));
      expect(glyph(t).value, inExclusiveRange(0.05, 0.95), reason: 'gliding into place');
      await t.pump(const Duration(milliseconds: 900));
      expect(glyph(t).value, closeTo(1, 0.001));
      expect(t.element(find.byType(AuthPageShell)), same(shell), reason: 'same shell: no remount, no entrance replay');

      expect(find.text('Check your email'), findsOneWidget);
      expect(find.text(ForgotPasswordController.genericMessage), findsOneWidget);
      expect(find.text('Open the link on this phone, or copy the link and paste it on the next screen.'), findsOneWidget);
      expect(find.text('I have a reset code or link'), findsOneWidget);
      expect(find.text('Back to sign in'), findsOneWidget);
      expect(find.text('Send reset link'), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('the accent node pulses once after the nodes are in place', (t) async {
      await mount(t, const ForgotPasswordScreen());
      Get.find<ForgotPasswordController>().sent.value = true;
      await t.pump();
      await t.pump(const Duration(milliseconds: 900)); // assembled
      final pulse = glyph(t).pulse!;
      await t.pump(const Duration(milliseconds: 20));
      await t.pump(const Duration(milliseconds: 120));
      expect(pulse.value, inExclusiveRange(0, 1));
      await t.pump(const Duration(milliseconds: 800));
      expect(pulse.value, 1);
    });

    testWidgets('reduce motion: the finished envelope crossfades in, nothing glides or pulses', (t) async {
      await mount(t, const ForgotPasswordScreen(), reduce: true);
      Get.find<ForgotPasswordController>().sent.value = true;
      await t.pump();
      await t.pump(const Duration(milliseconds: 16));
      expect(glyph(t).value, 1, reason: 'already in place on the first frame');
      await t.pump(const Duration(milliseconds: 600));
      expect(glyph(t).pulse!.value, 0, reason: 'no pulse');
    });
  });

  group('reset password', () {
    test('strength: display-only scoring (the only blocking rule stays the minimum length)', () {
      expect(PasswordStrength.of(''), 0);
      expect(PasswordStrength.of('a'), 1);
      expect(PasswordStrength.of('abcde'), 1);
      expect(PasswordStrength.of('abcdef'), 2); // minimum length reached
      expect(PasswordStrength.of('abcdefghijkl'), 2); // long but one class
      expect(PasswordStrength.of('Abcdef1'), 3); // three classes
      expect(PasswordStrength.of('Abcdefg1xyz!'), 4);
      expect(PasswordStrength.of('abcdefgh1234'), 3); // 12+, two classes
      for (var i = 0; i < 60; i++) {
        final s = PasswordStrength.of('Aa1!' * i);
        expect(s, inInclusiveRange(i == 0 ? 0 : 1, 4));
      }
    });

    testWidgets('four nodes link up as strength rises, with the word beside them', (t) async {
      await mount(t, const ResetPasswordScreen());
      Get.find<ResetPasswordController>().token.value = 'tok';
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byType(EmStrengthNodes), findsNothing, reason: 'nothing typed yet');

      final field = find.widgetWithText(TextFormField, 'New password');
      for (final (text, level, word) in [('a', 1, 'Weak'), ('abcdefgh', 2, 'Fair'), ('Abcdefg1', 3, 'Good'), ('Abcdefg1xyz!', 4, 'Strong')]) {
        await t.enterText(field, text);
        await t.pump();
        await t.pump(const Duration(milliseconds: 600));
        expect(strength(t).value, closeTo(level.toDouble(), 0.001), reason: text);
        expect(find.text(word), findsOneWidget, reason: text);
        // level n: n nodes lit; the links between lit nodes are drawn
        for (var i = 0; i < 4; i++) {
          expect(strength(t).nodeFill(i), i < level ? 1.0 : 0.0, reason: '$text node $i');
        }
        for (var i = 0; i < 3; i++) {
          expect(strength(t).linkFill(i), i < level - 1 ? 1.0 : 0.0, reason: '$text link $i');
        }
      }
      await t.enterText(field, '');
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(find.byType(EmStrengthNodes), findsNothing);
    });

    testWidgets('the nodes charge up over time (not a jump) and have a spoken label', (t) async {
      final handle = t.ensureSemantics();
      await mount(t, const ResetPasswordScreen());
      Get.find<ResetPasswordController>().token.value = 'tok';
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.enterText(find.widgetWithText(TextFormField, 'New password'), 'Abcdefg1xyz!');
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      expect(strength(t).value, inExclusiveRange(0.2, 3.9), reason: 'mid-way');
      await t.pump(const Duration(milliseconds: 600));
      expect(find.bySemanticsLabel('Password strength: Strong'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('validation is unchanged: too short still shows the same message', (t) async {
      await mount(t, const ResetPasswordScreen());
      Get.find<ResetPasswordController>().token.value = 'tok';
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.enterText(find.widgetWithText(TextFormField, 'New password'), 'abc');
      await t.enterText(find.widgetWithText(TextFormField, 'Confirm new password'), 'abc');
      await t.tap(find.text('Update password'));
      await t.pump();
      expect(find.text('Password must be at least 6 characters.'), findsOneWidget);
    });

    testWidgets('invalid / expired token: the banner wording and the new-link action are unchanged', (t) async {
      await mount(t, const ResetPasswordScreen());
      final c = Get.find<ResetPasswordController>();
      c.token.value = 'tok';
      c.tokenRejected.value = true;
      c.error.value = 'This reset link is invalid or has expired.';
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byType(AuthBanner), findsOneWidget);
      expect(find.text('This reset link is invalid or has expired.'), findsOneWidget);
      expect(find.text('Request a new reset link'), findsOneWidget);
      expect(find.text('Use a different code or link'), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('reduce motion: the strength jumps to its level at once', (t) async {
      await mount(t, const ResetPasswordScreen(), reduce: true);
      Get.find<ResetPasswordController>().token.value = 'tok';
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      await t.enterText(find.widgetWithText(TextFormField, 'New password'), 'Abcdefg1xyz!');
      await t.pump();
      await t.pump(const Duration(milliseconds: 16));
      expect(strength(t).value, 4);
    });

    testWidgets('paste form (no token yet) keeps its copy', (t) async {
      await mount(t, const ResetPasswordScreen());
      expect(find.text('Paste the code or link from your email'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.byKey(const Key('auth_photo')), findsOneWidget);
    });
  });

  group('layout', () {
    for (final (w, h, s) in [(320.0, 568.0, 1.3), (360.0, 800.0, 1.0), (430.0, 932.0, 1.3)]) {
      testWidgets('${w.toInt()}x${h.toInt()} text $s: forgot (sent) and reset (strength) fit without overflow', (t) async {
        await mount(t, const ForgotPasswordScreen(), width: w, height: h, scale: s);
        Get.find<ForgotPasswordController>().sent.value = true;
        await t.pump();
        await t.pump(const Duration(milliseconds: 1500));
        expect(t.takeException(), isNull);
        Get.reset();
        await mount(t, const ResetPasswordScreen(), width: w, height: h, scale: s);
        Get.find<ResetPasswordController>().token.value = 'tok';
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        await t.enterText(find.widgetWithText(TextFormField, 'New password'), 'Abcdefg1xyz!');
        await t.pump(const Duration(milliseconds: 800));
        expect(t.takeException(), isNull);
        await t.ensureVisible(find.text('Update password'));
        await t.pump(const Duration(milliseconds: 300));
        expect(t.getRect(find.text('Update password')).bottom, lessThanOrEqualTo(h));
      });
    }
  });
}
