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

/// Home must follow the class-teacher assignments of `/staff-portal/me` while it stays alive (the mark screen refreshes the profile, then the
/// teacher goes back to Home): the set of cards, their stale banners and their snapshots all track the NEW profile.
const _a = {'gradeId': 'g5', 'gradeName': 'Grade 5', 'sectionName': 'C', 'name': 'Grade 5 - C'};
const _b = {'gradeId': 'g8', 'gradeName': 'Grade 8', 'sectionName': 'B', 'name': 'Grade 8 - B'};

void main() {
  late FakeHomeRepository repo;
  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakeHomeRepository()..attendance = (_, __, ___, ____) async => 12;
  });
  tearDown(Get.reset);

  Future<({HomeDashboardController c, HarnessApi api, dynamic auth})> mount(WidgetTester t, List<Map<String, Object?>> initial) async {
    // The token only ever claims the first class (a stale token).
    final h = (await t.runAsync(() => signedIn(classTeacher: true, classTeacherAssignments: initial, token: classTeacherJwt([(grade: 'Grade 5', section: 'C')]))))!;
    Get.put<HomeRepository>(repo);
    Get.put(HomeShellController());
    final badges = Get.put(HomeBadgesController(repository: repo, auth: h.auth, autoPoll: false));
    final c = Get.put(HomeDashboardController(repository: repo, auth: h.auth, permissions: h.perms, badges: badges, tick: null));
    await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: const Scaffold(body: HomeDashboardScreen())));
    await t.pump();
    await t.pump();
    return (c: c, api: h.api, auth: h.auth);
  }

  const keyC = ValueKey('mark_attendance_5|c');
  const keyB = ValueKey('mark_attendance_8|b');
  const bannerC = ValueKey('home_stale_banner_5|c');
  const bannerB = ValueKey('home_stale_banner_8|b');

  void expectTwoCards(WidgetTester t, HomeDashboardController c) {
    expect(find.text('My classes'), findsOneWidget);
    expect(find.byKey(keyC), findsOneWidget);
    expect(find.byKey(keyB), findsOneWidget);
    expect(find.byKey(bannerC), findsNothing);
    expect(find.byKey(bannerB), findsOneWidget);
    expect([for (final s in c.classCard.value.data!) s.label], ['Grade 5 - C', 'Grade 8 - B']);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  }

  testWidgets('the profile refresh (what the mark screen does) adds the new class card with a stale banner and a snapshot', (t) async {
    final m = await mount(t, [_a]);
    expect(find.text('My class'), findsOneWidget);
    expect(find.byKey(keyB), findsNothing);

    m.api.classTeacherAssignments = [_a, _b];
    await t.runAsync(() => m.auth.refreshProfile(force: true));
    await t.pump();
    await t.pump();
    expectTwoCards(t, m.c);
    expect(repo.calls, contains('roster:Grade 8:B'));
  });

  testWidgets('pull-to-refresh (refreshAll) shows the new class card too', (t) async {
    final m = await mount(t, [_a]);
    m.api.classTeacherAssignments = [_a, _b];
    await t.runAsync(() => m.c.refreshAll());
    await t.pump();
    await t.pump();
    expectTwoCards(t, m.c);
  });

  testWidgets('the profile shrinking from two classes to one leaves one card', (t) async {
    final m = await mount(t, [_a, _b]);
    expect(find.byKey(keyB), findsOneWidget);

    m.api.classTeacherAssignments = [_a];
    await t.runAsync(() => m.auth.refreshProfile(force: true));
    await t.pump();
    await t.pump();
    expect(find.text('My class'), findsOneWidget);
    expect(find.byKey(const Key('mark_attendance_button')), findsOneWidget); // the single-class key
    expect(find.byKey(keyB), findsNothing);
    expect(find.byKey(bannerB), findsNothing);
    expect(m.c.classCard.value.data!, hasLength(1));
  });

  testWidgets('an identical profile re-apply does not reload the class card', (t) async {
    final m = await mount(t, [_a, _b]);
    final before = repo.calls.where((c) => c.startsWith('roster:')).length;
    await t.runAsync(() => m.auth.refreshProfile(force: true));
    await t.pump();
    expect(repo.calls.where((c) => c.startsWith('roster:')).length, before);
  });
}
