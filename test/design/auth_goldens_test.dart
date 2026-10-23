@Tags(['golden'])
library;

import 'dart:io';
import 'package:eldermin_teacher_app/app/common/views/not_available_screen.dart';
import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/app/modules/auth/views/login_screen.dart';
import 'package:eldermin_teacher_app/app/modules/auth/views/profile_load_screen.dart';
import 'package:eldermin_teacher_app/app/modules/auth/views/unsupported_role_screen.dart';
import 'package:eldermin_teacher_app/app/modules/forgot_password/controllers/forgot_password_controller.dart';
import 'package:eldermin_teacher_app/app/modules/forgot_password/views/forgot_password_screen.dart';
import 'package:eldermin_teacher_app/app/modules/intro/views/intro_screen.dart';
import 'package:eldermin_teacher_app/app/modules/reset_password/controllers/reset_password_controller.dart';
import 'package:eldermin_teacher_app/app/modules/reset_password/views/reset_password_screen.dart';
import 'package:eldermin_teacher_app/app/modules/splash/views/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_design_harness.dart';
import '../support/design_harness.dart';

/// Goldens of the signed-out screens: normal, text scale 1.3, and (form screens)
/// keyboard open. 390x844, macOS baselines (other hosts skip).
///
///   Update:  flutter test test/design/auth_goldens_test.dart --tags golden --update-goldens
void main() {
  setUpAll(loadDesignFonts);
  tearDown(Get.reset);
  final skip = Platform.isMacOS ? null : 'goldens are macOS baselines';

  final screens = <String, (Widget Function(), Future<void> Function(WidgetTester, AuthController)?, bool)>{
    'splash': (() => const SplashScreen(), null, false),
    'intro': (() => const IntroScreen(), null, false),
    'login': (() => const LoginScreen(), null, true),
    'login_error': (() => const LoginScreen(), (t, a) async {
          // the inline error uses the same banner as a notice
          a.loginNotice.value = 'Your session expired. Please sign in again.';
          await t.pump();
        }, true),
    'forgot': (() => const ForgotPasswordScreen(), null, true),
    'forgot_sent': (() => const ForgotPasswordScreen(), (t, a) async {
          Get.find<ForgotPasswordController>().sent.value = true;
          await t.pump();
        }, false),
    'reset_paste': (() => const ResetPasswordScreen(), null, true),
    'reset_password': (() => const ResetPasswordScreen(), (t, a) async {
          Get.find<ResetPasswordController>().token.value = 'tok';
          await t.pump();
        }, true),
    'profile_loading': (() => const ProfileLoadScreen(), null, false),
    'profile_error': (() => const ProfileLoadScreen(), (t, a) async {
          a.profileError.value = "Couldn't reach Eldermin. Check your internet connection.";
          await t.pump();
        }, false),
    'unsupported_role': (() => const UnsupportedRoleScreen(), null, false),
    'not_available': (() => const NotAvailableScreen(), null, false),
  };

  for (final e in screens.entries) {
    final (build, prepare, hasKeyboard) = e.value;
    final variants = <String, (double, double)>{'normal': (1.0, 0), 'scale13': (1.3, 0), if (hasKeyboard) 'keyboard': (1.0, 300)};
    for (final v in variants.entries) {
      testWidgets('${e.key} / ${v.key}', (t) async {
        final auth = setUpAuthDeps();
        await pumpScreen(t, build(), textScale: v.value.$1, keyboard: v.value.$2, topInset: e.key == 'splash' ? 0 : 47);
        await loadAuthPhotos(t);
        if (prepare != null) await prepare(t, auth);
        if (v.key == 'keyboard') {
          final f = find.byType(TextField);
          if (f.evaluate().isNotEmpty) {
            await t.showKeyboard(f.first);
            await t.pump(const Duration(milliseconds: 400));
          }
        }
        await t.pump(const Duration(milliseconds: 1200));
        expect(t.takeException(), isNull);
        await expectLater(find.byType(GetMaterialApp), matchesGoldenFile('goldens/auth/${e.key}_${v.key}.png'));
      }, skip: skip != null);
    }
  }
}
