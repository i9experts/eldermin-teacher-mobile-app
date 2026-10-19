import 'package:eldermin_teacher_app/app/modules/attendance/controllers/attendance_controller.dart';
import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/app/modules/classes/views/classes_screen.dart';
import 'package:eldermin_teacher_app/app/modules/home/controllers/home_badges_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/controllers/home_dashboard_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/controllers/home_shell_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/views/home_dashboard_screen.dart';
import 'package:eldermin_teacher_app/app/modules/home/views/home_shell.dart';
import 'package:eldermin_teacher_app/app/modules/more/views/more_screen.dart';
import 'package:eldermin_teacher_app/app/routes/app_pages.dart';
import 'package:eldermin_teacher_app/app/routes/app_routes.dart';
import 'package:eldermin_teacher_app/core/design/design.dart';
import 'package:eldermin_teacher_app/core/models/auth_me.dart';
import 'package:eldermin_teacher_app/core/models/home/messaging.dart';
import 'package:eldermin_teacher_app/core/models/staff_me.dart';
import 'package:eldermin_teacher_app/core/network/base_client.dart';
import 'package:eldermin_teacher_app/core/services/auth_api_service.dart';
import 'package:eldermin_teacher_app/core/services/home_repository.dart';
import 'package:eldermin_teacher_app/core/services/permission_service.dart';
import 'package:eldermin_teacher_app/core/services/token_store.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:eldermin_teacher_app/app/modules/timetable/controllers/timetable_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/design_harness.dart';
import '../support/fake_classroom_repositories.dart';
import '../support/fake_home_repository.dart';

class _Tokens implements TokenStore {
  @override
  Future<String?> readToken() async => 'tok';
  @override
  Future<void> saveToken(String t) async {}
  @override
  Future<void> clearAll() async {}
}

class _Api extends AuthApiService {
  _Api() : super(BaseClient());
  bool classTeacher = false;
  List<String>? permissions;
  int meCalls = 0;

  @override
  Future<AuthMe> fetchAuthMe({String? token}) async => const AuthMe(id: 'u', name: 'Tess Teacher', email: 't@s.test', role: 'teacher');

  @override
  Future<StaffMe> fetchStaffMe() async {
    meCalls++;
    return StaffMe.fromJson({
      'user': {'id': 'u', 'name': 'Tess Teacher', 'email': 't@s.test', 'role': 'teacher', if (permissions != null) 'permissions': permissions},
      'staffId': 's1',
      'teacherProfile': {'isClassTeacher': classTeacher},
      'institution': {'slug': 's'},
    });
  }

  @override
  Future<void> logout() async {}
}

class _Ctx {
  _Ctx(this.api, this.auth, this.repo, this.shell);
  final _Api api;
  final AuthController auth;
  final FakeHomeRepository repo;
  final HomeShellController? shell;
}

/// Routes the quick actions / header open; each renders a marker so navigation can be asserted.
final _stubRoutes = [
  Routes.attendanceMark,
  Routes.homeworkNew,
  Routes.leaveApply,
  Routes.timetable,
  Routes.profile,
  Routes.notifications,
];

Future<_Ctx> _mount(
  WidgetTester t, {
  bool classTeacher = false,
  List<String>? permissions,
  FakeHomeRepository? repo,
  Size size = const Size(390, 844),
  double scale = 1,
  TextDirection dir = TextDirection.ltr,
  DateTime? clock,
  int initialTab = 0,
}) async {
  SharedPreferences.setMockInitialValues({});
  Get.reset();
  Get.testMode = true;
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);

  final api = _Api()
    ..classTeacher = classTeacher
    ..permissions = permissions;
  final perms = PermissionService();
  final auth = AuthController(
    api: api,
    permissions: perms,
    tokenStore: _Tokens(),
    minSplash: Duration.zero,
    resetScopedControllers: () async {},
    notify: (_) {},
  );
  Get.put<AuthApiService>(api);
  Get.put<PermissionService>(perms);
  Get.put<AuthController>(auth);
  final r = repo ?? FakeHomeRepository();
  Get.put<HomeRepository>(r);
  final badges = Get.put(HomeBadgesController(repository: r, auth: auth, autoPoll: false));
  Get.put(HomeDashboardController(repository: r, auth: auth, badges: badges, clock: clock == null ? null : () => clock, tick: null));
  Get.put(TimetableController(repository: r, tick: null));
  Get.put(AttendanceController(students: FakeStudentsRepository(), attendance: FakeAttendanceRepository()));
  await t.runAsync(auth.bootstrap);
  expect(auth.status.value, AuthStatus.authenticated);

  await t.pumpWidget(GetMaterialApp(
    theme: AppTheme.light,
    getPages: [for (final r in _stubRoutes) GetPage(name: r, page: () => Scaffold(body: Center(child: Text('route:$r'))))],
    builder: (context, c) => Directionality(
      textDirection: dir,
      child: MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: c!),
    ),
    home: HomeShell(initialTab: initialTab),
  ));
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
  return _Ctx(api, auth, r, Get.isRegistered<HomeShellController>() ? Get.find<HomeShellController>() : null);
}

Finder navItem(String label) => find.descendant(of: find.byKey(HomeShell.navKey), matching: find.text(label));
Finder get fab => find.byKey(const Key('quick_actions_fab'));

void main() {
  setUpAll(loadDesignFonts);
  tearDown(Get.reset);

  group('navigation structure: Home · Classes · Messages · More + centre FAB', () {
    testWidgets('four tabs in this order inside the keyed bar; Attendance and Timetable are not tabs', (t) async {
      await _mount(t, classTeacher: true);
      expect(find.byKey(const Key('app_shell_nav')), findsOneWidget);
      expect(HomeShell.navKey, const Key('app_shell_nav'));
      final labels = ['Home', 'Classes', 'Messages', 'More'];
      for (final l in labels) {
        expect(navItem(l), findsOneWidget, reason: l);
      }
      // left-to-right order
      final xs = [for (final l in labels) t.getCenter(navItem(l)).dx];
      expect(xs, [...xs]..sort());
      expect(navItem('Attendance'), findsNothing);
      expect(navItem('Timetable'), findsNothing);
      expect(find.byType(BottomNavigationBar), findsNothing);
      // the FAB sits between the two pairs
      final fabX = t.getCenter(fab).dx;
      expect(fabX, greaterThan(xs[1]));
      expect(fabX, lessThan(xs[2]));
    });

    testWidgets('tapping a tab shows its screen; tabs live in one IndexedStack (state is kept)', (t) async {
      final c = await _mount(t);
      expect(c.shell!.tabIndex.value, 0);
      expect(t.widget<IndexedStack>(find.byType(IndexedStack)).index, 0);
      for (final (label, index, type) in [('Classes', 1, ClassesScreen), ('Messages', 2, null), ('More', 3, MoreScreen), ('Home', 0, HomeDashboardScreen)]) {
        await t.tap(navItem(label));
        await t.pump(const Duration(milliseconds: 300));
        expect(c.shell!.tabIndex.value, index, reason: label);
        expect(t.widget<IndexedStack>(find.byType(IndexedStack)).index, index, reason: label);
        if (type == ClassesScreen) expect(find.byType(ClassesScreen).hitTestable(), findsOneWidget);
        if (type == MoreScreen) expect(find.byType(MoreScreen).hitTestable(), findsOneWidget);
      }
      expect(find.byType(ClassesScreen, skipOffstage: false), findsOneWidget, reason: 'built once, kept alive');
    });

    testWidgets('Messages tab index is 2 and is what notification / deep-link code opens', (t) async {
      expect(HomeShellController.messagesTab, 2);
      final c = await _mount(t, initialTab: 2);
      expect(c.shell!.tabIndex.value, HomeShellController.messagesTab);
    });

    testWidgets('named routes map to the new tab order; /home/attendance opens the guarded Attendance screen itself', (t) async {
      HomeShell shellOf(String name) => AppPages.pages.firstWhere((p) => p.name == name).page() as HomeShell;
      expect(shellOf(Routes.home).initialTab, 0);
      expect(shellOf(Routes.homeClasses).initialTab, 1);
      expect(shellOf(Routes.homeMessages).initialTab, 2);
      expect(shellOf(Routes.messages).initialTab, 2);
      expect(shellOf(Routes.homeMore).initialTab, 3);
      final att = AppPages.pages.firstWhere((p) => p.name == Routes.homeAttendance);
      expect(att.page(), isNot(isA<HomeShell>()));
      expect(att.middlewares, isNotEmpty, reason: 'still behind the route guard');
    });
  });

  group('header: avatar, greeting, name, bell with unread dot', () {
    testWidgets('greeting follows the clock, name is shown, avatar opens Profile, bell opens Notifications', (t) async {
      await _mount(t, clock: DateTime(2026, 10, 5, 8, 10));
      expect(find.text('Good morning'), findsOneWidget);
      expect(find.text('Tess Teacher'), findsOneWidget);
      await t.tap(find.byKey(const Key('shell_header')).first);
      await t.pump(const Duration(milliseconds: 400));
      expect(Get.currentRoute, Routes.profile);
      Get.back();
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.byKey(const Key('bell_badge')));
      await t.pump(const Duration(milliseconds: 400));
      expect(Get.currentRoute, Routes.notifications);
    });

    testWidgets('afternoon / evening greetings', (t) async {
      await _mount(t, clock: DateTime(2026, 10, 5, 14, 0));
      expect(find.text('Good afternoon'), findsOneWidget);
      await _mount(t, clock: DateTime(2026, 10, 5, 21, 0));
      expect(find.text('Good evening'), findsOneWidget);
    });

    testWidgets('bell dot only with real unread notifications; Messages badge only with unread conversations', (t) async {
      final sem = t.ensureSemantics();
      await _mount(t, repo: FakeHomeRepository()
        ..unread = (() async => 4)
        ..threads = (() async => ThreadsResult(items: [const MessageThread(id: '1', staffHasUnread: true)])));
      await t.pump();
      expect(find.byKey(const Key('em_dot')), findsOneWidget);
      expect(find.bySemanticsLabel('Notifications, 4 unread'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('messages_badge')), matching: find.text('1')), findsOneWidget);
      await _mount(t);
      await t.pump();
      expect(find.byKey(const Key('em_dot')), findsNothing);
      expect(find.byKey(const Key('messages_badge')), findsNothing);
      sem.dispose();
    });
  });

  group('centre FAB -> Quick actions sheet', () {
    Future<void> openSheet(WidgetTester t) async {
      await t.tap(fab);
      await t.pumpAndSettle();
    }

    testWidgets('class teacher: Mark Attendance, Add Homework, Apply Leave, Timetable (in order)', (t) async {
      await _mount(t, classTeacher: true);
      await openSheet(t);
      expect(find.text('Quick actions'), findsWidgets);
      final ids = ['attendance', 'homework', 'leave', 'timetable'];
      for (final id in ids) {
        expect(find.byKey(Key('quick_action_$id')), findsOneWidget, reason: id);
      }
      final ys = [for (final id in ids) t.getCenter(find.byKey(Key('quick_action_$id'))).dy];
      expect(ys, [...ys]..sort());
      for (final l in ['Mark Attendance', 'Add Homework', 'Apply Leave', 'Timetable']) {
        expect(find.text(l), findsWidgets);
      }
    });

    testWidgets('subject teacher: no Mark Attendance', (t) async {
      await _mount(t, classTeacher: false);
      await openSheet(t);
      expect(find.byKey(const Key('quick_action_attendance')), findsNothing);
      for (final id in ['homework', 'leave', 'timetable']) {
        expect(find.byKey(Key('quick_action_$id')), findsOneWidget, reason: id);
      }
    });

    testWidgets('no permissions: the FAB is hidden and the four tabs share the bar evenly', (t) async {
      await _mount(t, permissions: const []);
      expect(fab, findsNothing);
      final xs = [for (final l in ['Home', 'Classes', 'Messages', 'More']) t.getCenter(navItem(l)).dx];
      expect(xs[1] - xs[0], closeTo(xs[2] - xs[1], 1));
      expect(xs[2] - xs[1], closeTo(xs[3] - xs[2], 1));
    });

    for (final (id, route) in [
      ('attendance', Routes.attendanceMark),
      ('homework', Routes.homeworkNew),
      ('leave', Routes.leaveApply),
      ('timetable', Routes.timetable),
    ]) {
      testWidgets('"$id" closes the sheet and opens the existing route $route', (t) async {
        await _mount(t, classTeacher: true);
        await openSheet(t);
        await t.tap(find.byKey(Key('quick_action_$id')));
        await t.pumpAndSettle();
        expect(Get.currentRoute, route);
        expect(find.text('route:$route'), findsOneWidget);
        expect(find.byKey(const Key('quick_actions_sheet')), findsNothing, reason: 'the sheet is closed');
      });
    }

    testWidgets('class-teacher flag changing live adds / removes Mark Attendance (no re-login); Home pull refreshes /staff-portal/me', (t) async {
      final c = await _mount(t);
      await openSheet(t);
      expect(find.byKey(const Key('quick_action_attendance')), findsNothing);
      await t.tapAt(const Offset(10, 10)); // dismiss the sheet
      await t.pumpAndSettle();

      c.api.classTeacher = true;
      final before = c.api.meCalls;
      await t.drag(find.byType(SingleChildScrollView).first, const Offset(0, 400));
      await t.pump(const Duration(milliseconds: 50));
      await t.pump(const Duration(milliseconds: 600));
      expect(c.api.meCalls, greaterThan(before), reason: 'pull on Home must call /staff-portal/me');
      await openSheet(t);
      expect(find.byKey(const Key('quick_action_attendance')), findsOneWidget);
      await t.tapAt(const Offset(10, 10));
      await t.pumpAndSettle();

      c.api.classTeacher = false;
      await t.runAsync(() => c.auth.refreshProfile(force: true));
      await t.pump();
      await openSheet(t);
      expect(find.byKey(const Key('quick_action_attendance')), findsNothing);
      expect(c.auth.status.value, AuthStatus.authenticated);
    });
  });

  group('look', () {
    testWidgets('tinted scaffold, white nav bar with the accent FAB (navy glyph), no Material bottom bar, no app bar', (t) async {
      await _mount(t);
      final scaffolds = t.widgetList<Scaffold>(find.byType(Scaffold)).toList();
      expect(scaffolds.first.backgroundColor, EmColors.background);
      expect(scaffolds.first.appBar, isNull);
      expect(t.widget<Icon>(find.descendant(of: fab, matching: find.byIcon(Icons.add_rounded))).color, EmColors.onAccent);
    });
  });

  group('robust: widths 320/360/375/430, text scale 1.0/1.3, RTL, every tab', () {
    for (final classTeacher in [false, true]) {
      testWidgets('${classTeacher ? 'class' : 'plain'} teacher', (t) async {
        final problems = <String>{};
        void drain(String where) {
          Object? e;
          while ((e = t.takeException()) != null) {
            problems.add('$where: ${e.toString().split('\n').first}');
          }
        }

        for (final w in [320.0, 360.0, 375.0, 430.0]) {
          for (final scale in [1.0, 1.3]) {
            for (final dir in [TextDirection.ltr, TextDirection.rtl]) {
              final at = '${w.toInt()}dp x$scale ${dir.name}';
              await _mount(t, classTeacher: classTeacher, size: Size(w, w < 400 ? 667 : 844), scale: scale, dir: dir);
              drain('Home $at');
              for (final tab in ['Classes', 'Messages', 'More', 'Home']) {
                await t.tap(navItem(tab));
                await t.pump(const Duration(milliseconds: 350));
                drain('$tab $at');
              }
              await t.tap(fab);
              await t.pumpAndSettle();
              drain('sheet $at');
              await t.tapAt(const Offset(10, 10));
              await t.pumpAndSettle();
            }
          }
        }
        expect(problems, isEmpty, reason: problems.join('\n'));
      });
    }
  });
}
