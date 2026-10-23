import 'package:eldermin_teacher_app/app/modules/auth/views/auth_widgets.dart' show AuthPageShell, AuthPhotoSize;
import 'package:eldermin_teacher_app/app/modules/auth/views/login_screen.dart';
import 'package:eldermin_teacher_app/app/modules/forgot_password/controllers/forgot_password_controller.dart';
import 'package:eldermin_teacher_app/app/modules/forgot_password/views/forgot_password_screen.dart';
import 'package:eldermin_teacher_app/app/modules/intro/views/intro_screen.dart';
import 'package:eldermin_teacher_app/app/modules/reset_password/controllers/reset_password_controller.dart';
import 'package:eldermin_teacher_app/app/modules/reset_password/views/reset_password_screen.dart';
import 'package:eldermin_teacher_app/app/modules/splash/views/splash_screen.dart';
import 'package:eldermin_teacher_app/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_design_harness.dart';
import '../support/design_harness.dart';

/// Text on the photo overlay (MOTION_SPEC.md section 7): every text colour is AA against the overlay's
/// guaranteed colour (its alpha at the strong line over pure white = the worst photo), and on every screen the
/// text really starts at or below that line.
void main() {
  setUpAll(loadDesignFonts);
  tearDown(() {
    Get.reset();
    EmLogoHandoff.reset();
  });

  group('tokens', () {
    test('the overlay is clear at the top and near-opaque at the bottom', () {
      for (final safeTop in [0.3, 0.5, EmPhotoOverlay.defaultSafeTop, AuthPageShell.photoSafeTop]) {
        expect(EmPhotoOverlay.alphaAt(0, safeTop: safeTop), 0);
        expect(EmPhotoOverlay.alphaAt(1, safeTop: safeTop), EmPhotoOverlay.bottomAlpha);
        expect(EmPhotoOverlay.bottomAlpha, greaterThanOrEqualTo(0.95));
        var prev = -1.0;
        for (var y = 0.0; y <= 1.0; y += 0.01) {
          final a = EmPhotoOverlay.alphaAt(y, safeTop: safeTop);
          expect(a, greaterThanOrEqualTo(prev), reason: 'monotonic at $y');
          prev = a;
        }
        expect(EmPhotoOverlay.alphaAt(EmPhotoOverlay.strongLine(safeTop), safeTop: safeTop), closeTo(EmPhotoOverlay.strongAlpha, 1e-9));
      }
    });

    test('the overlay base is the brand navy token', () => expect(EmPhotoOverlay.base, EmColors.primaryDark));

    for (final pair in EmPhotoOverlay.pairs) {
      test('${pair.name}: >= ${pair.min}:1 on the overlay at the strong line (worst-case photo)', () {
        final bg = EmPhotoOverlay.worstCaseAtStrongLine;
        expect(contrastRatio(pair.foreground, bg), greaterThanOrEqualTo(pair.min), reason: 'on $bg');
      });
    }

    test('accent text is never small: accent on the brand navy is below 4.5:1, so only the 3:1 (large text) rule can apply', () {
      expect(contrastRatio(EmColors.accent, EmColors.primaryDark), lessThan(4.5));
      expect(contrastRatio(EmColors.accent, EmPhotoOverlay.worstCaseAtStrongLine), greaterThanOrEqualTo(3));
    });

    test('the button label (ink) on the accent fill is AA, the pair that is not on the overlay', () {
      expect(contrastRatio(EmColors.ink, EmColors.accent), greaterThanOrEqualTo(4.5));
    });

    test('fields: the light border and the error text hold up on the overlay', () {
      final bg = EmPhotoOverlay.worstCaseAtStrongLine;
      expect(contrastRatio(EmColors.primaryLight, bg), greaterThanOrEqualTo(3));
      expect(contrastRatio(EmColors.errorContainer, bg), greaterThanOrEqualTo(4.5));
    });
  });

  group('placement: no text above the strong line', () {
    final sizes = [(320.0, 568.0), (375.0, 667.0), (390.0, 844.0), (430.0, 932.0)];

    /// Every Text on screen (bar the ones in [skip]) starts at or below [line] (px from the top).
    void expectBelow(WidgetTester t, double line, String reason, {Set<Key> skip = const {}}) {
      for (final e in find.byType(Text).evaluate()) {
        final w = e.widget as Text;
        if (skip.contains(w.key)) continue;
        final rect = t.getRect(find.byWidget(w));
        expect(rect.top, greaterThanOrEqualTo(line - 0.5), reason: '$reason: "${w.data}" starts at ${rect.top}, line $line');
      }
    }

    testWidgets('sign in (tall photo)', (t) async {
      for (final (w, h) in sizes) {
        for (final scale in [1.0, 1.3]) {
          Get.reset();
          setUpAuthDeps();
          await pumpScreen(t, const LoginScreen(), width: w, height: h, textScale: scale);
          final photo = t.getSize(find.byKey(const Key('auth_photo'))).height;
          expectBelow(t, photo * AuthPageShell.contentStart, 'login ${w}x$h @$scale');
        }
      }
    });

    testWidgets('sign in fits the iPhone SE (375 x 667) without scrolling: the photo gives way to 46%', (t) async {
      setUpAuthDeps();
      await pumpScreen(t, const LoginScreen(), width: 375, height: 667);
      expect(t.getSize(find.byKey(const Key('auth_photo'))).height, closeTo(667 * AuthPhotoSize.compactTall, 1));
      expect(t.getRect(find.text('Forgot password?')).bottom, lessThanOrEqualTo(667));
      expect(t.getRect(find.byType(EmMorphButton)).bottom, lessThanOrEqualTo(667));
    });

    testWidgets('forgot / reset (short photo), including the sent state', (t) async {
      for (final (w, h) in sizes) {
        for (final scale in [1.0, 1.3]) {
          for (final which in ['forgot', 'sent', 'paste', 'reset']) {
            Get.reset();
            setUpAuthDeps();
            await pumpScreen(t, which == 'forgot' || which == 'sent' ? const ForgotPasswordScreen() : const ResetPasswordScreen(), width: w, height: h, textScale: scale);
            if (which == 'sent') Get.find<ForgotPasswordController>().sent.value = true;
            if (which == 'reset') Get.find<ResetPasswordController>().token.value = 'tok';
            await t.pump(const Duration(milliseconds: 1200));
            final photo = t.getSize(find.byKey(const Key('auth_photo'))).height;
            expect(photo, closeTo(h * AuthPhotoSize.short.fractionFor(h), 1));
            expectBelow(t, photo * AuthPageShell.contentStart, '$which ${w}x$h @$scale');
          }
        }
      }
    });

    testWidgets('onboarding: the title, body and buttons start below the overlay\'s strong line, at every size', (t) async {
      for (final (w, h) in sizes) {
        for (final scale in [1.0, 1.3]) {
          Get.reset();
          setUpAuthDeps().introSeen.value = false;
          await pumpScreen(t, const IntroScreen(), width: w, height: h, textScale: scale, topInset: 0, bottomInset: 0);
          final backdrop = t.widget<EmPhotoCarouselBackdrop>(find.byKey(const Key('intro_scene')));
          final line = EmPhotoOverlay.strongLine(backdrop.safeTop) * h;
          for (final key in const [Key('intro_title_0'), Key('intro_body_0'), Key('intro_skip')]) {
            expect(t.getRect(find.byKey(key)).top, greaterThanOrEqualTo(line - 0.5), reason: '$key ${w}x$h @$scale (line $line)');
          }
          expect(t.getRect(find.byType(EmPrimaryButton)).top, greaterThanOrEqualTo(line));
        }
      }
    });

    testWidgets('splash: title, tagline and caption start below the strong line', (t) async {
      for (final (w, h) in sizes) {
        for (final scale in [1.0, 1.3]) {
          await pumpScreen(t, const SplashScreen(), width: w, height: h, textScale: scale, topInset: 0, bottomInset: 0);
          final backdrop = t.widget<EmPhotoBackdrop>(find.byType(EmPhotoBackdrop));
          final line = EmPhotoOverlay.strongLine(backdrop.safeTop) * h;
          for (final key in const [Key('splash_title'), Key('splash_tagline'), Key('splash_connecting')]) {
            expect(t.getRect(find.byKey(key)).top, greaterThanOrEqualTo(line - 0.5), reason: '$key ${w}x$h @$scale (line $line)');
          }
        }
      }
    });
  });

  group('text styles on the overlay', () {
    testWidgets('only white, muted-light, light-caption and LARGE bold accent text; no dark or off-token text on a photo screen', (t) async {
      final allowed = {EmColors.onPrimaryDark, EmColors.primaryContainer, EmColors.primaryLight, EmColors.accent, EmColors.ink, EmColors.errorContainer};
      for (final build in <Widget Function()>[() => const LoginScreen(), () => const ForgotPasswordScreen(), () => const IntroScreen(), () => const SplashScreen()]) {
        Get.reset();
        setUpAuthDeps().introSeen.value = false;
        await pumpScreen(t, build());
        for (final text in t.widgetList<Text>(find.byType(Text))) {
          final c = text.style?.color;
          if (c == null) continue;
          expect(allowed, contains(c), reason: '"${text.data}"');
          if (c == EmColors.accent) {
            expect(text.style!.fontSize, greaterThanOrEqualTo(18.66), reason: '"${text.data}" accent must be large (bold >= 18.66 px)');
            expect(text.style!.fontWeight, FontWeight.w700);
          }
        }
      }
    });
  });
}
