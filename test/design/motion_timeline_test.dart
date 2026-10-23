import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/core/design/design.dart';
import 'package:eldermin_teacher_app/core/network/base_client.dart';
import 'package:eldermin_teacher_app/core/services/auth_api_service.dart';
import 'package:eldermin_teacher_app/core/services/permission_service.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/auth_design_harness.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Duration ms(int v) => Duration(milliseconds: v);

  group('EmSplashTimeline.exitDelay', () {
    test('waits for the end of the current beat', () {
      expect(EmSplashTimeline.exitDelay(ms(0)), ms(700));
      expect(EmSplashTimeline.exitDelay(ms(450)), ms(250));
      expect(EmSplashTimeline.exitDelay(ms(700)), ms(600)); // next beat B2 -> 1300
      expect(EmSplashTimeline.exitDelay(ms(1299)), ms(1));
      expect(EmSplashTimeline.exitDelay(ms(1400)), ms(100));
    });
    test('never waits once the intro is over (init slower than the motion)', () {
      expect(EmSplashTimeline.exitDelay(ms(1500)), Duration.zero);
      expect(EmSplashTimeline.exitDelay(ms(4000)), Duration.zero);
    });
    test('wait + exit stays under the hard cap after init', () {
      for (var e = 0; e < 3000; e += 7) {
        final w = EmSplashTimeline.exitDelay(ms(e));
        expect(w + EmMotion.hero, lessThanOrEqualTo(EmSplashTimeline.maxAfterInit), reason: 'init at $e ms');
      }
      // a tight cap clamps the wait
      expect(EmSplashTimeline.exitDelay(ms(0), exit: ms(1400)), ms(200));
    });
    test('windows sit inside the intro', () {
      for (final w in [
        EmSplashTimeline.charge,
        EmSplashTimeline.pulse,
        EmSplashTimeline.ripple,
        EmSplashTimeline.text
      ]) {
        expect(w.begin, greaterThanOrEqualTo(0));
        expect(w.end, lessThanOrEqualTo(EmSplashTimeline.intro.inMilliseconds));
      }
      // painter sweeps and their windows agree
      expect(EmSplashTimeline.charge.end - EmSplashTimeline.charge.begin, NodeNetworkPainter.chargeTotalMs);
      expect(EmSplashTimeline.ripple.end - EmSplashTimeline.ripple.begin, NodeNetworkPainter.rippleTotalMs);
    });
  });

  test('the logo dash drift loops without a seam', () {
    // same seed -> same painter output is covered by paint determinism; here the loop contract:
    // every node uses whole cycles per ambient loop
    expect(EmMotion.ambientPeriod.inMilliseconds % EmMotion.dashPeriod.inMilliseconds, 0);
  });

  group('minimum hold', () {
    test('is one motion beat: link charge + the start of the pulse (0.9-1.0 s)', () {
      expect(EmSplashTimeline.minHold.inMilliseconds, inInclusiveRange(900, 1000));
      expect(EmSplashTimeline.minHold.inMilliseconds, greaterThan(EmSplashTimeline.charge.end));
      expect(EmSplashTimeline.minHold.inMilliseconds, greaterThan(EmSplashTimeline.pulse.begin));
      expect(EmSplashTimeline.slowInitAfter, const Duration(seconds: 3));
    });

    testWidgets('AuthController default holds the splash for minHold, not 1.5 s (no token -> login)', (t) async {
      SharedPreferences.setMockInitialValues({});
      Get.reset();
      Get.testMode = true;
      final auth = AuthController(
        api: AuthApiService(BaseClient()),
        permissions: PermissionService(),
        tokenStore: MemTokens(),
        resetScopedControllers: () async {},
        notify: (_) {},
      );
      final done = auth.bootstrap();
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20))); // prefs
      await t.pump(const Duration(milliseconds: 900));
      expect(auth.status.value, AuthStatus.unknown, reason: 'still inside the hold');
      await t.pump(const Duration(milliseconds: 100));
      await done;
      expect(auth.status.value, AuthStatus.unauthenticated);
      Get.reset();
    });
  });
}
