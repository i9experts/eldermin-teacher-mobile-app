import 'dart:async';
import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/app/modules/auth/views/auth_widgets.dart' show AuthPhotoSize;
import 'package:eldermin_teacher_app/app/modules/auth/views/login_screen.dart';
import 'package:eldermin_teacher_app/core/design/design.dart';
import 'package:eldermin_teacher_app/core/models/auth_me.dart';
import 'package:eldermin_teacher_app/core/models/institution.dart';
import 'package:eldermin_teacher_app/core/models/login_result.dart';
import 'package:eldermin_teacher_app/core/models/staff_me.dart';
import 'package:eldermin_teacher_app/core/models/teacher_user.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/network/base_client.dart';
import 'package:eldermin_teacher_app/core/services/auth_api_service.dart';
import 'package:eldermin_teacher_app/core/services/permission_service.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/auth_design_harness.dart';
import '../support/design_harness.dart';

class StubLoginApi extends AuthApiService {
  StubLoginApi() : super(BaseClient());
  Completer<void> gate = Completer<void>();
  ApiException? error;

  @override
  Future<LoginResult> login({required String email, required String password, String? slug}) async {
    await gate.future;
    if (error != null) throw error!;
    return LoginResult(accessToken: 'a.b.c', user: TeacherUser(id: 'u', name: 'T', email: email, role: 'teacher'), institution: const Institution(slug: 's'));
  }

  @override
  Future<AuthMe> fetchAuthMe({String? token}) async => const AuthMe(id: 'u', name: 'T', email: 'a@s.test', role: 'teacher');

  @override
  Future<StaffMe> fetchStaffMe() async => StaffMe.fromJson({
        'user': {'id': 'u', 'name': 'T', 'email': 'a@s.test', 'role': 'teacher'},
        'staffId': 's1',
        'teacherProfile': {'isClassTeacher': false},
        'institution': {'slug': 's'},
      });

  @override
  Future<void> logout() async {}
}

/// The simulated keyboard height: change it on a mounted screen to open / close the keyboard.
final keyboardInset = ValueNotifier<double>(0);

Future<StubLoginApi> mount(WidgetTester t, {bool reduce = false, double width = 390, double height = 844, double scale = 1, double keyboard = 0, Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  Get.reset();
  Get.testMode = true;
  final api = StubLoginApi();
  Get.put<AuthApiService>(api);
  Get.put<AuthController>(AuthController(
    api: api,
    permissions: PermissionService(),
    tokenStore: MemTokens(),
    minSplash: Duration.zero,
    resetScopedControllers: () async {},
    notify: (_) {},
  )..status.value = AuthStatus.unauthenticated);
  t.view.physicalSize = Size(width, height);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  keyboardInset.value = keyboard;
  await t.pumpWidget(GetMaterialApp(
    theme: AppTheme.light,
    builder: (context, c) => ValueListenableBuilder<double>(
      valueListenable: keyboardInset,
      child: c,
      builder: (context, kb, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduce,
          textScaler: TextScaler.linear(scale),
          viewInsets: EdgeInsets.only(bottom: kb),
          padding: EdgeInsets.only(top: 47, bottom: kb > 0 ? 0 : 34),
        ),
        child: child!,
      ),
    ),
    home: const LoginScreen(),
  ));
  await t.pump(); // the entrance starts on the first frame ...
  await t.pump(const Duration(milliseconds: 1200)); // ... and is done well within this
  return api;
}

Finder field(String label) => find.widgetWithText(TextFormField, label);
EmMorphButton button(WidgetTester t) => t.widget<EmMorphButton>(find.byType(EmMorphButton));
double buttonWidth(WidgetTester t) => t.getSize(find.descendant(of: find.byType(EmMorphButton), matching: find.byType(AnimatedContainer))).width;
double shakeOffset(WidgetTester t) =>
    t.widget<Transform>(find.descendant(of: find.byType(EmShake), matching: find.byType(Transform)).first).transform.getTranslation().x;

Future<void> fillAndSubmit(WidgetTester t) async {
  await t.enterText(field('Email'), 'tess@stub.test');
  await t.enterText(field('Password'), 'StubPass123');
  await t.tap(find.byType(EmMorphButton));
  await t.pump();
}

void main() {
  setUpAll(loadDesignFonts);
  tearDown(() {
    Get.reset();
    EmLogoHandoff.reset();
  });

  group('photo header', () {
    testWidgets('navy page, the first photo behind a navy overlay, the logo tile is the splash landing anchor; no constellation, no card', (t) async {
      await mount(t);
      expect(t.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, EmColors.primaryDark);
      expect(find.byKey(const Key('auth_photo')), findsOneWidget);
      expect(t.widget<Image>(find.descendant(of: find.byKey(const Key('auth_photo')), matching: find.byType(Image))).fit, BoxFit.cover);
      expect(find.byKey(const Key('photo_overlay')), findsOneWidget);
      expect(find.byType(EmLogoTile), findsOneWidget);
      expect(EmLogoHandoff.hasAnchor, isTrue);
      expect(EmLogoHandoff.anchorPalette, EmNetworkPalette.standard);
      expect(t.widget<EmLogomark>(find.descendant(of: find.byType(EmLogoAnchor), matching: find.byType(EmLogomark))).reversed, isFalse, reason: 'navy / orange logo on the white tile');
    });

    testWidgets('the photo fills the top ~55% of the screen', (t) async {
      await mount(t);
      expect(t.getSize(find.byKey(const Key('auth_photo'))).height, closeTo(844 * AuthPhotoSize.tall.fraction, 1));
      expect(t.getTopLeft(find.byKey(const Key('auth_photo'))).dy, 0);
    });

    testWidgets('"Welcome Back!" in accent (large bold, on navy), muted subtitle', (t) async {
      await mount(t);
      final title = t.widget<Text>(find.byKey(const Key('auth_title')));
      expect(title.data, 'Welcome Back!');
      expect(title.style!.color, EmColors.accent);
      expect(title.style!.fontSize, greaterThanOrEqualTo(24));
      expect(title.style!.fontWeight, FontWeight.w700);
      expect(t.widget<Text>(find.byKey(const Key('auth_subtitle'))).style!.color, EmColors.primaryContainer);
    });

    testWidgets('the content rises and fades in, its items stagger (not all visible on the first frames)', (t) async {
      SharedPreferences.setMockInitialValues({});
      Get.reset();
      final api = StubLoginApi();
      Get.put<AuthApiService>(api);
      Get.put<AuthController>(AuthController(api: api, permissions: PermissionService(), tokenStore: MemTokens(), minSplash: Duration.zero, resetScopedControllers: () async {}, notify: (_) {})
        ..status.value = AuthStatus.unauthenticated);
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: const LoginScreen()));
      await t.pump(const Duration(milliseconds: 16));
      double opacityOf(Finder f) => t.widget<FadeTransition>(find.ancestor(of: f, matching: find.byType(FadeTransition)).first).opacity.value;
      final cardY0 = t.getTopLeft(find.byKey(const Key('auth_title'))).dy;
      expect(opacityOf(field('Email')), lessThan(0.2));
      await t.pump(const Duration(milliseconds: 200));
      final emailMid = opacityOf(field('Email'));
      final buttonMid = t.widget<FadeTransition>(find.ancestor(of: find.byType(EmMorphButton), matching: find.byType(FadeTransition)).first).opacity.value;
      expect(emailMid, greaterThan(buttonMid), reason: 'earlier items arrive first');
      await t.pump(const Duration(milliseconds: 1000));
      expect(opacityOf(field('Email')), 1);
      expect(t.getTopLeft(find.byKey(const Key('auth_title'))).dy, lessThan(cardY0), reason: 'the content moved up into place');
    });

    testWidgets('keyboard open: the photo collapses to a strip with the logo tile, the button stays reachable', (t) async {
      await mount(t);
      final fullHeight = t.getSize(find.byKey(const Key('auth_photo'))).height;
      await mount(t, keyboard: 300, height: 667);
      await t.pump(const Duration(milliseconds: 600));
      expect(t.getSize(find.byKey(const Key('auth_photo'))).height, lessThan(fullHeight - 100));
      expect(find.byType(EmLogoTile), findsOneWidget);
      expect(t.getRect(find.byType(EmLogoTile)).bottom, lessThan(t.getSize(find.byKey(const Key('auth_photo'))).height), reason: 'the tile stays on the photo strip');
      await t.ensureVisible(find.byType(EmMorphButton));
      await t.pump(const Duration(milliseconds: 300));
      expect(t.getRect(find.byType(EmMorphButton)).bottom, lessThanOrEqualTo(667 - 300 + 0.5));
      expect(t.takeException(), isNull);
    });

    testWidgets('the collapse is animated, not a jump', (t) async {
      // open the keyboard on a mounted screen
      await mount(t);
      final before = t.getSize(find.byKey(const Key('auth_photo'))).height;
      keyboardInset.value = 300;
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      final mid = t.getSize(find.byKey(const Key('auth_photo'))).height;
      await t.pump(const Duration(milliseconds: 600));
      final after = t.getSize(find.byKey(const Key('auth_photo'))).height;
      expect(after, lessThan(mid));
      expect(mid, lessThan(before));
    });
  });

  group('submit button', () {
    testWidgets('press -> circular spinner while loading (width morphs to 52), nothing else changes', (t) async {
      await mount(t);
      expect(button(t).phase, EmMorphPhase.idle);
      final full = buttonWidth(t);
      expect(full, greaterThan(250));
      await fillAndSubmit(t);
      await t.pump(const Duration(milliseconds: 20));
      await t.pump(const Duration(milliseconds: 60)); // mid-morph
      expect(button(t).phase, EmMorphPhase.loading);
      final mid = buttonWidth(t);
      await t.pump(const Duration(milliseconds: 400));
      expect(buttonWidth(t), EmMorphButton.height);
      expect(mid, lessThan(full));
      expect(mid, greaterThan(EmMorphButton.height));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Sign in'), findsNothing);
      // taps are ignored while busy
      await t.tap(find.byType(EmMorphButton));
      await t.pump();
    });

    testWidgets('success: the spinner becomes a drawn check (stroke trimmed 0 -> 1)', (t) async {
      final api = await mount(t);
      await fillAndSubmit(t);
      await t.pump(const Duration(milliseconds: 400));
      api.gate.complete();
      await t.pump(const Duration(milliseconds: 20));
      await t.pump(const Duration(milliseconds: 20));
      expect(button(t).phase, EmMorphPhase.success);
      await t.pump(const Duration(milliseconds: 150));
      final early = t.widget<CustomPaint>(find.descendant(of: find.byType(EmMorphButton), matching: find.byType(CustomPaint)).last).painter! as CheckPainter;
      expect(early.progress, inExclusiveRange(0, 1), reason: 'being drawn');
      await t.pump(const Duration(milliseconds: 400));
      final done = t.widget<CustomPaint>(find.descendant(of: find.byType(EmMorphButton), matching: find.byType(CustomPaint)).last).painter! as CheckPainter;
      expect(done.progress, 1);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('error: morphs back, the card shakes gently, the existing message shows', (t) async {
      final api = await mount(t);
      api.error = ApiException('Invalid credentials', statusCode: 401);
      await fillAndSubmit(t);
      await t.pump(const Duration(milliseconds: 400));
      expect(button(t).phase, EmMorphPhase.loading);
      expect(shakeOffset(t), 0);
      api.gate.complete();
      await t.pump(const Duration(milliseconds: 10));
      await t.pump(const Duration(milliseconds: 40));
      expect(button(t).phase, EmMorphPhase.idle);
      // shaking: sideways offset, within the token, then back to rest
      var maxOffset = 0.0;
      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 16));
        maxOffset = maxOffset < shakeOffset(t).abs() ? shakeOffset(t).abs() : maxOffset;
      }
      expect(maxOffset, inInclusiveRange(2, EmMotion.shakeDistance));
      await t.pump(const Duration(milliseconds: 600));
      expect(shakeOffset(t), 0);
      expect(find.text('Invalid credentials'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget, reason: 'the button is back to its label');
      expect(buttonWidth(t), greaterThan(250));
    });
  });

  group('school code', () {
    testWidgets('collapsed by default; the toggle expands the slug field with a size animation', (t) async {
      await mount(t);
      expect(find.text('Have a school code?'), findsOneWidget);
      expect(field('School code'), findsNothing);
      await t.tap(find.byKey(const Key('school_code_toggle')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      final mid = t.getSize(find.byType(Form)).height;
      await t.pump(const Duration(milliseconds: 600));
      final full = t.getSize(find.byType(Form)).height;
      expect(field('School code'), findsOneWidget);
      expect(mid, lessThan(full), reason: 'still growing at 100 ms');
      expect(t.getSize(find.byKey(const Key('school_code_toggle'))).height, greaterThanOrEqualTo(48));
    });

    testWidgets('a remembered school code: expanded from the start and prefilled', (t) async {
      await mount(t, prefs: {'eldermin_teacher_school_slug': 'demo-school'});
      await t.pump(const Duration(milliseconds: 600));
      expect(field('School code'), findsOneWidget);
      expect(find.text('demo-school'), findsOneWidget);
    });
  });

  group('reduce motion', () {
    testWidgets('no shake, no width morph: the label swaps in place and the check shows at once', (t) async {
      final api = await mount(t, reduce: true);
      api.error = ApiException('Invalid credentials', statusCode: 401);
      await fillAndSubmit(t);
      expect(buttonWidth(t), EmMorphButton.height, reason: 'no width animation: collapsed on the first frame');
      api.gate.complete();
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 16));
        expect(shakeOffset(t), 0, reason: 'no shake');
      }
      expect(find.text('Invalid credentials'), findsOneWidget);
      expect(button(t).phase, EmMorphPhase.idle);
    });

    testWidgets('school code expands and the photo collapses instantly (no animated resize, no layout assertion)', (t) async {
      await mount(t, reduce: true);
      await t.tap(find.byKey(const Key('school_code_toggle')));
      await t.pump();
      expect(field('School code'), findsOneWidget, reason: 'there on the next frame');
      keyboardInset.value = 300;
      await t.pump();
      await t.pump(const Duration(milliseconds: 16));
      expect(t.getSize(find.byKey(const Key('auth_photo'))).height, lessThan(200), reason: 'collapsed on the next frame, not animated');
      expect(t.takeException(), isNull);
    });

    testWidgets('success check is already drawn on the first frame', (t) async {
      final api = await mount(t, reduce: true);
      await fillAndSubmit(t);
      api.gate.complete();
      await t.pump(const Duration(milliseconds: 10));
      await t.pump(const Duration(milliseconds: 10));
      expect(button(t).phase, EmMorphPhase.success);
      await t.pump(const Duration(milliseconds: 250)); // the 200 ms crossfade of the content
      final painter = t.widget<CustomPaint>(find.descendant(of: find.byType(EmMorphButton), matching: find.byType(CustomPaint)).last).painter! as CheckPainter;
      expect(painter.progress, 1);
    });
  });

  group('layout', () {
    for (final (w, h, s) in [(320.0, 568.0, 1.3), (360.0, 800.0, 1.3), (390.0, 844.0, 1.0), (430.0, 932.0, 1.3)]) {
      for (final kb in [0.0, 300.0]) {
        if (kb > 0 && h < 600 && kb >= h - 200) continue;
        testWidgets('${w.toInt()}x${h.toInt()} text $s keyboard ${kb.toInt()}: no overflow, button reachable', (t) async {
          await mount(t, width: w, height: h, scale: s, keyboard: kb);
          await t.pump(const Duration(milliseconds: 400));
          expect(t.takeException(), isNull);
          await t.ensureVisible(find.byType(EmMorphButton));
          await t.pump(const Duration(milliseconds: 300));
          expect(t.getRect(find.byType(EmMorphButton)).bottom, lessThanOrEqualTo(h - kb + 0.5));
          expect(t.takeException(), isNull);
        });
      }
    }

    testWidgets('RTL: the logo tile sits in the end (left) corner and is not mirrored', (t) async {
      SharedPreferences.setMockInitialValues({});
      Get.reset();
      final api = StubLoginApi();
      Get.put<AuthApiService>(api);
      Get.put<AuthController>(AuthController(api: api, permissions: PermissionService(), tokenStore: MemTokens(), minSplash: Duration.zero, resetScopedControllers: () async {}, notify: (_) {})
        ..status.value = AuthStatus.unauthenticated);
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!), home: const LoginScreen()));
      await t.pump(const Duration(milliseconds: 1200));
      expect(t.getCenter(find.descendant(of: find.byType(EmLogoAnchor), matching: find.byType(EmLogomark))).dx, closeTo(56, 1)); // RTL: the end corner is the left one
      expect(t.takeException(), isNull);
    });
  });
}
