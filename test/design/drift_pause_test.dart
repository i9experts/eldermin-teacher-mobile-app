import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/app/modules/auth/views/login_screen.dart';
import 'package:eldermin_teacher_app/core/design/design.dart';
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

final keyboard = ValueNotifier<double>(0);

Future<void> mount(WidgetTester t, {bool reduce = false}) async {
  SharedPreferences.setMockInitialValues({});
  Get.reset();
  Get.testMode = true;
  final api = StubApi();
  Get.put<AuthApiService>(api);
  Get.put<AuthController>(AuthController(api: api, permissions: PermissionService(), tokenStore: MemTokens(), minSplash: Duration.zero, resetScopedControllers: () async {}, notify: (_) {})
    ..status.value = AuthStatus.unauthenticated);
  keyboard.value = 0;
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(GetMaterialApp(
    theme: AppTheme.light,
    navigatorKey: Get.key,
    builder: (context, c) => ValueListenableBuilder<double>(
      valueListenable: keyboard,
      child: c,
      builder: (context, kb, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reduce, viewInsets: EdgeInsets.only(bottom: kb)), child: child!),
    ),
    home: const LoginScreen(),
  ));
  await t.pump();
  await t.pump(const Duration(milliseconds: 1200));
}

class StubApi extends AuthApiService {
  StubApi() : super(BaseClient());
}

EmDriftClock clock(WidgetTester t) => t.widget<EmAuthHero>(find.byType(EmAuthHero)).time! as EmDriftClock;

/// Drift advanced over [ms] of frames.
Future<double> advance(WidgetTester t, EmDriftClock c, [int ms = 1000]) async {
  final before = c.value;
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
  return (c.value - before).abs();
}

void main() {
  setUpAll(loadDesignFonts);
  tearDown(() {
    Get.reset();
    EmLogoHandoff.reset();
  });

  testWidgets('drifts by default', (t) async {
    await mount(t);
    final c = clock(t);
    expect(c.active, isTrue);
    expect(c.ticking, isTrue);
    expect(await advance(t, c, 2000), greaterThan(0));
    expect(c.rate, closeTo(1, 0.01));
  });

  testWidgets('keyboard open (hero collapsed): eases to a stop, ticker off, resumes when it closes', (t) async {
    await mount(t);
    final c = clock(t);
    await advance(t, c, 500);
    keyboard.value = 300;
    await t.pump();
    // eases, it does not stop dead
    final firstStep = await advance(t, c, 100);
    expect(c.rate, inExclusiveRange(0.05, 1));
    expect(firstStep, greaterThan(0));
    await advance(t, c, 1500);
    expect(c.rate, 0);
    expect(c.ticking, isFalse, reason: 'no frames scheduled while paused');
    final frozen = c.value;
    await advance(t, c, 1000);
    expect(c.value, frozen);
    expect(find.byType(EmConstellation), findsOneWidget, reason: 'still drawn, just still (dimmed)');

    keyboard.value = 0;
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(c.ticking, isTrue);
    final early = await advance(t, c, 100); // eases back up: slower than full speed at first
    final later = await advance(t, c, 100);
    await advance(t, c, 1000);
    final full = await advance(t, c, 100);
    expect(early, lessThan(full));
    expect(later, lessThanOrEqualTo(full + 1e-9));
    expect(c.rate, closeTo(1, 0.02));
  });

  testWidgets('app inactive / backgrounded: pauses; resumed: continues from where it was', (t) async {
    await mount(t);
    final c = clock(t);
    await advance(t, c, 500);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await t.pump();
    await advance(t, c, 1500);
    expect(c.active, isFalse);
    expect(c.ticking, isFalse);
    final frozen = c.value;
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await advance(t, c, 500);
    expect(c.value, frozen);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(c.active, isTrue);
    expect(await advance(t, c, 1000), greaterThan(0));
    expect(c.value, isNot(frozen));
  });

  testWidgets('another route on top: paused; back on top: resumes', (t) async {
    await mount(t);
    final c = clock(t);
    await advance(t, c, 500);
    final nav = Get.key.currentState!;
    nav.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('covering'))));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400)); // transition
    await advance(t, c, 1500);
    expect(c.active, isFalse);
    expect(c.ticking, isFalse);
    nav.pop();
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(c.active, isTrue);
    expect(await advance(t, c, 1000), greaterThan(0));
  });

  testWidgets('reduce motion: no clock, no constellation', (t) async {
    await mount(t, reduce: true);
    expect(t.widget<EmAuthHero>(find.byType(EmAuthHero)).time, isA<EmDriftClock>());
    expect(find.byType(EmConstellation), findsNothing);
    final c = clock(t);
    expect(c.active, isFalse);
    expect(c.ticking, isFalse);
  });

  testWidgets('a paused screen schedules no frames at all (pumpAndSettle returns)', (t) async {
    await mount(t);
    keyboard.value = 300;
    await t.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    expect(t.takeException(), isNull);
  });
}
