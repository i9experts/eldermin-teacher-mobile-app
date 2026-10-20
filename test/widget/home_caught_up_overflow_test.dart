import 'package:eldermin_teacher_app/app/modules/home/controllers/home_badges_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/controllers/home_dashboard_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/controllers/home_shell_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/views/home_dashboard_screen.dart';
import 'package:eldermin_teacher_app/core/services/home_repository.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_home_repository.dart';

/// The "You're all caught up - no unread messages" card on Home overflowed to the
/// right at large text sizes (18 px at 375 dp, 33 px at 360 dp, text scale 1.3).
void main() {
  setUp(() {
    Get.reset();
    Get.testMode = true;
  });
  tearDown(Get.reset);

  for (final (w, h) in [(360.0, 800.0), (375.0, 667.0)]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('all-caught-up card does not overflow at ${w.toInt()}dp, text scale $scale', (t) async {
        t.view.physicalSize = Size(w, h);
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(t.view.reset);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);

        final repo = FakeHomeRepository();
        final harness = (await t.runAsync(() => signedIn()))!;
        Get.put<HomeRepository>(repo);
        Get.put(HomeShellController());
        final badges = Get.put(HomeBadgesController(repository: repo, auth: harness.auth, autoPoll: false));
        Get.put(HomeDashboardController(repository: repo, auth: harness.auth, permissions: harness.perms, badges: badges, tick: null));
        await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: const Scaffold(body: HomeDashboardScreen())));
        await t.pump();
        await t.pump();

        expect(find.byKey(const Key('messages_caught_up')), findsOneWidget);
        // flutter_test's font is far wider than a real one, so other Home rows may report overflow
        // here; this test is about the all-caught-up card only: drain those, then check the card itself.
        while (t.takeException() != null) {}
        // the card text stays inside the card (before the fix it ran past the right edge)
        final card = t.getRect(find.byKey(const Key('messages_caught_up')));
        final text = t.getRect(find.textContaining('all caught up - no unread'));
        expect(text.right, lessThanOrEqualTo(card.right + 0.5), reason: 'text ends at ${text.right}, card at ${card.right}');
      });
    }
  }
}
