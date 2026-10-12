// ignore_for_file: invalid_use_of_protected_member
// 5e: a failed REFRESH keeps the last good data on screen under a "Refresh failed - Retry" banner; a failed FIRST load keeps the plain error card.
import 'package:eldermin_teacher_app/app/modules/home/controllers/home_badges_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/controllers/home_dashboard_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/models/section_state.dart';
import 'package:eldermin_teacher_app/app/modules/home/views/widgets/section_view.dart';
import 'package:eldermin_teacher_app/app/modules/leave/controllers/leave_controller.dart';
import 'package:eldermin_teacher_app/app/modules/leave/views/leave_screen.dart';
import 'package:eldermin_teacher_app/app/routes/app_routes.dart';
import 'package:eldermin_teacher_app/core/models/home/pending_grading.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:eldermin_teacher_app/core/widgets/app_widgets.dart';
import 'package:eldermin_teacher_app/core/widgets/screen_state_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_home_repository.dart';
import '../support/fake_phase7b_repositories.dart';

Widget host(Widget child) => GetMaterialApp(theme: AppTheme.light, home: Scaffold(body: child));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    Get.reset();
    Get.testMode = true;
  });
  tearDown(Get.reset);

  group('SectionState', () {
    const good = SectionState<List<int>>.data([1, 2]);

    test('transient failure after data keeps the data as stale (error status, hasData, isStale)', () {
      final s = SectionState<List<int>>.fromError(ApiException('boom', statusCode: 500), previous: good);
      expect(s.status, SectionStatus.error);
      expect(s.isStale, isTrue);
      expect(s.hasData, isTrue);
      expect(s.data, [1, 2]);
      expect(s.message, 'The server had a problem. Please try again.');
    });

    test('a second failure keeps the SAME stale data; offline / timeout messages come through', () {
      final first = SectionState<List<int>>.fromError(ApiException('No internet connection', statusCode: null), previous: good);
      final second = SectionState<List<int>>.fromError(ApiException('Request timed out'), previous: first);
      expect(second.isStale, isTrue);
      expect(second.data, [1, 2]);
      expect(second.message, 'Request timed out');
    });

    test('first-load failure (no previous data) is a plain error without stale data', () {
      final s = SectionState<List<int>>.fromError(ApiException('boom', statusCode: 500));
      expect(s.status, SectionStatus.error);
      expect(s.isStale, isFalse);
      expect(s.hasData, isFalse);
      expect(SectionState<List<int>>.fromError(ApiException('boom', statusCode: 500), previous: const SectionState.loading()).isStale, isFalse);
      expect(SectionState<List<int>>.fromError(ApiException('boom', statusCode: 500), previous: const SectionState.empty()).isStale, isFalse);
    });

    test('403 / 404 / 501 replace the data (access gone / feature missing), they are not a refresh failure', () {
      expect(SectionState<List<int>>.fromError(ApiException('x', statusCode: 403), previous: good).status, SectionStatus.forbidden);
      expect(SectionState<List<int>>.fromError(ApiException('x', statusCode: 404), previous: good).status, SectionStatus.unavailable);
      expect(SectionState<List<int>>.fromError(ApiException('x', statusCode: 501), previous: good).data, isNull);
    });

    test('loading(previous:) that fails keeps the previous data', () {
      final s = SectionState<List<int>>.fromError(ApiException('x', statusCode: 500), previous: const SectionState.loading(previous: [7]));
      expect(s.data, [7]);
    });
  });

  group('Home dashboard sections', () {
    late FakeHomeRepository repo;
    setUp(() => repo = FakeHomeRepository());

    Future<({HomeDashboardController c, HarnessApi api})> make(WidgetTester t) async {
      final h = (await t.runAsync(() async {
        final h = await signedIn(classTeacher: true);
        await h.auth.refreshProfile(force: true);
        return h;
      }))!;
      final badges = HomeBadgesController(repository: repo, auth: h.auth, autoPoll: false);
      final c = HomeDashboardController(repository: repo, auth: h.auth, permissions: h.perms, badges: badges, clock: () => DateTime(2026, 10, 5, 9), tick: null);
      return (c: c, api: h.api);
    }

    final grading = PendingGrading.fromJson({
      'total': 3,
      'items': [
        {'assignmentId': 'a1', 'title': 'HW', 'subject': 'Maths', 'gradeLevel': 'Grade 5', 'sectionName': 'A', 'submittedCount': 3, 'totalSubmissions': 5}
      ]
    });

    testWidgets('refresh 500 after good data: data kept (stale error); Retry re-runs ONLY that section and clears the banner', (t) async {
      final m = await make(t);
      var fail = false;
      var calls = 0;
      repo.pendingGrading = () async {
        calls++;
        if (fail) throw ApiException('boom', statusCode: 500);
        return grading;
      };
      await t.runAsync(() => m.c.loadHomework());
      expect(m.c.homework.value.status, SectionStatus.data);
      final lessonCalls = repo.calls.where((x) => x.startsWith('lessonPlans')).length;
      fail = true;
      await t.runAsync(() => m.c.loadHomework());
      expect(m.c.homework.value.isStale, isTrue);
      expect(m.c.homework.value.data!.totalUngraded, 3);
      // the banner's Retry is the section's own load: it fails again -> still stale; then succeeds -> clean data
      await t.runAsync(() => m.c.loadHomework());
      expect(m.c.homework.value.isStale, isTrue);
      fail = false;
      await t.runAsync(() => m.c.loadHomework());
      expect(m.c.homework.value.status, SectionStatus.data);
      expect(m.c.homework.value.isStale, isFalse);
      expect(calls, 4);
      expect(repo.calls.where((x) => x.startsWith('lessonPlans')).length, lessonCalls, reason: 'other sections are not touched');
    });

    testWidgets('first load failure: plain error (no stale data); 403 after data replaces it', (t) async {
      final m = await make(t);
      repo.pendingGrading = () async => throw ApiException('boom', statusCode: 500);
      await t.runAsync(() => m.c.loadHomework());
      expect(m.c.homework.value.status, SectionStatus.error);
      expect(m.c.homework.value.isStale, isFalse);
      repo.pendingGrading = () async => grading;
      await t.runAsync(() => m.c.loadHomework());
      repo.pendingGrading = () async => throw ApiException('no', statusCode: 403);
      await t.runAsync(() => m.c.loadHomework());
      expect(m.c.homework.value.status, SectionStatus.forbidden);
    });

    testWidgets('SectionView: stale error shows the banner ABOVE the data; first-load error shows the card; Retry calls onRetry', (t) async {
      var retried = 0;
      Widget view(SectionState<List<String>> s) => host(SectionView<List<String>>(title: 'Things', state: s, onRetry: () => retried++, builder: (d) => Text('rows:${d.join(",")}')));
      await t.pumpWidget(view(const SectionState.error('The server had a problem. Please try again.', stale: ['a', 'b'])));
      expect(find.text('Refresh failed'), findsOneWidget);
      expect(find.text('rows:a,b'), findsOneWidget);
      expect(t.getTopLeft(find.text('Refresh failed')).dy, lessThan(t.getTopLeft(find.text('rows:a,b')).dy));
      expect(find.byKey(const Key('section_error')), findsNothing);
      await t.tap(find.text('Retry'));
      expect(retried, 1);
      await t.pumpWidget(view(const SectionState.error('The server had a problem. Please try again.')));
      expect(find.byKey(const Key('section_error')), findsOneWidget);
      expect(find.text('Refresh failed'), findsNothing);
    });
  });

  group('ScreenStateView', () {
    Widget view(SectionState<List<String>> s, VoidCallback retry) => host(ScreenStateView<List<String>>(state: s, onRefresh: () async {}, onRetry: retry, builder: (d) => [for (final x in d) Text('row $x')]));

    testWidgets('stale error: banner above the kept rows, Retry works, no error card', (t) async {
      var retried = 0;
      await t.pumpWidget(view(const SectionState.error("Couldn't reach the server", stale: ['one', 'two']), () => retried++));
      expect(find.byKey(const Key('refresh_failed_banner')), findsOneWidget);
      expect(find.text('Refresh failed'), findsOneWidget);
      expect(find.text("Couldn't reach the server"), findsOneWidget);
      expect(find.text('row one'), findsOneWidget);
      expect(find.text('row two'), findsOneWidget);
      expect(find.byKey(const Key('screen_error')), findsNothing);
      expect(t.getTopLeft(find.byKey(const Key('refresh_failed_banner'))).dy, lessThan(t.getTopLeft(find.text('row one')).dy));
      await t.tap(find.text('Retry'));
      expect(retried, 1);
    });

    testWidgets('first-load error keeps the existing error card (Try again), no banner', (t) async {
      await t.pumpWidget(view(const SectionState.error('The server had a problem. Please try again.'), () {}));
      expect(find.byKey(const Key('screen_error')), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.byKey(const Key('refresh_failed_banner')), findsNothing);
    });
  });

  group('RefreshFailedBanner', () {
    testWidgets('shows title, optional message and a Retry button', (t) async {
      var n = 0;
      await t.pumpWidget(host(RefreshFailedBanner(onRetry: () => n++)));
      expect(find.text('Refresh failed'), findsOneWidget);
      await t.tap(find.text('Retry'));
      expect(n, 1);
    });
  });

  group('Leave screen (custom layout) with a real controller', () {
    testWidgets('history refresh failure: requests stay visible under the banner; Retry re-reads history only', (t) async {
      final lv = FakeLeaveRepository();
      final c = Get.put(LeaveController(repository: lv));
      lv.history = () async => [leaveRow('p', status: 'pending', reason: 'Family wedding out of town')];
      await t.binding.setSurfaceSize(const Size(430, 1600));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: const LeaveScreen(), getPages: [for (final r in Routes.all) GetPage(name: r, page: () => const SizedBox())]));
      await t.runAsync(() => c.reload());
      await t.pump();
      expect(find.text('Family wedding out of town'), findsOneWidget);
      lv.history = () async => fail7b(500);
      await t.runAsync(() => c.loadHistory(userInitiated: true));
      await t.pump();
      expect(find.text('Refresh failed'), findsOneWidget);
      expect(find.text('Family wedding out of town'), findsOneWidget, reason: 'previous data stays visible');
      expect(find.byKey(const Key('leave_history_error')), findsNothing);
      lv.history = () async => [leaveRow('p2', reason: 'Dentist appointment tomorrow')];
      final balanceCalls = lv.calls.where((x) => x == 'balance').length;
      await t.tap(find.text('Retry'));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await t.pump();
      expect(find.text('Refresh failed'), findsNothing);
      expect(find.text('Dentist appointment tomorrow'), findsOneWidget);
      expect(lv.calls.where((x) => x == 'balance').length, balanceCalls);
    });
  });
}
