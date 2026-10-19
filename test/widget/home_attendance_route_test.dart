import 'package:eldermin_teacher_app/app/common/services/deep_link_service.dart';
import 'package:eldermin_teacher_app/app/common/views/not_available_screen.dart';
import 'package:eldermin_teacher_app/app/modules/attendance/views/attendance_screen.dart';
import 'package:eldermin_teacher_app/app/routes/app_pages.dart';
import 'package:eldermin_teacher_app/app/routes/app_routes.dart';
import 'package:eldermin_teacher_app/app/routes/route_guard.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:eldermin_teacher_app/core/utils/deep_link_parser.dart';
import 'package:eldermin_teacher_app/core/utils/notification_target.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_messaging_repository.dart' show notif;

/// `/home/attendance` was the Attendance TAB; since D3 it opens the Attendance screen itself, behind the route guard.
/// For a subject teacher (not a class teacher) every way of reaching it must end in the guarded
/// "Not available for your account" state (or be ignored), never a crash or a blank screen.
void main() {
  setUp(() {
    Get.reset();
    Get.testMode = true;
  });
  tearDown(Get.reset);

  Future<void> app(WidgetTester t) async {
    await t.pumpWidget(GetMaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: Center(child: Text('root screen'))),
      getPages: AppPages.pages,
    ));
    await t.pump();
  }

  group('subject teacher (not a class teacher)', () {
    testWidgets('direct route: the guarded "not available" state, with a working way out', (t) async {
      await t.runAsync(() => signedIn(classTeacher: false));
      await app(t);
      Get.toNamed(Routes.homeAttendance);
      await t.pumpAndSettle();
      expect(find.byType(NotAvailableScreen), findsOneWidget);
      expect(find.text('Not available for your account'), findsOneWidget);
      expect(find.byType(AttendanceScreen), findsNothing);
      expect(t.takeException(), isNull);
      await t.tap(find.text('Back to home'));
      await t.pumpAndSettle();
      expect(find.text('root screen'), findsOneWidget);
    });

    testWidgets('the guard rule says no for the route and for its sub-paths', (t) async {
      final h = (await t.runAsync(() => signedIn(classTeacher: false)))!;
      for (final r in [Routes.homeAttendance, '${Routes.homeAttendance}?x=1', Routes.attendance, Routes.attendanceMark]) {
        expect(
          RouteGuardRules.allows(r, signedIn: true, roleSupported: true, profileLoaded: true, permissions: h.perms, isClassTeacher: false),
          isFalse,
          reason: r,
        );
      }
    });

    testWidgets('deep link to /home/attendance (custom scheme and web host) is ignored: nothing opens, nothing breaks', (t) async {
      final h = (await t.runAsync(() => signedIn(classTeacher: false)))!;
      for (final raw in [
        'eldermin-teacher://home/attendance',
        'eldermin-teacher://attendance',
        'https://app.eldermin.com/home/attendance',
      ]) {
        expect(DeepLinkParser.parseString(raw), isNull, reason: raw);
      }
      final svc = Get.put<DeepLinkService>(DeepLinkService(auth: h.auth));
      await app(t);
      svc.handleUri(Uri.parse('eldermin-teacher://home/attendance'));
      svc.handleUri(Uri.parse('https://app.eldermin.com/home/attendance'));
      await t.pumpAndSettle();
      expect(find.text('root screen'), findsOneWidget, reason: 'still on the screen the user was on');
      expect(find.byType(NotAvailableScreen), findsNothing);
      expect(t.takeException(), isNull);
    });

    test('notification taps: no notification type leads to attendance (unknown types stay in the inbox)', () {
      for (final type in ['attendance', 'attendance_reminder', 'attendance_marked', 'other', '']) {
        expect(notificationTargetFor(notif('n', type: type, entity: 'a1b2c3d4e5f60718293a4b5c'), isClassTeacher: false), isNull, reason: type);
        expect(notificationTargetFor(notif('n', type: type, entity: 'a1b2c3d4e5f60718293a4b5c'), isClassTeacher: true), isNull, reason: 'class teacher: $type');
      }
      // and none of the mapped targets is the attendance route
      for (final type in ['message', 'ptm', 'substitution', 'lesson_plan', 'homework', 'leave_status', 'leave_decision']) {
        for (final ct in [false, true]) {
          final target = notificationTargetFor(notif('n', type: type, entity: 'a1b2c3d4e5f60718293a4b5c'), isClassTeacher: ct);
          expect(target?.route.contains('attendance') ?? false, isFalse, reason: '$type ct=$ct -> $target');
        }
      }
    });
  });

  group('class teacher', () {
    testWidgets('the same route is allowed and its page is the Attendance screen', (t) async {
      final h = (await t.runAsync(() => signedIn(classTeacher: true)))!;
      expect(
        RouteGuardRules.allows(Routes.homeAttendance, signedIn: true, roleSupported: true, profileLoaded: true, permissions: h.perms, isClassTeacher: true),
        isTrue,
      );
      final page = AppPages.pages.firstWhere((p) => p.name == Routes.homeAttendance);
      expect(page.page(), isA<AttendanceScreen>());
      expect(page.middlewares, isNotEmpty);
    });
  });

  testWidgets('signed out: the guard also blocks the route (no blank screen, the not-available page)', (t) async {
    await app(t);
    Get.toNamed(Routes.homeAttendance);
    await t.pumpAndSettle();
    expect(find.byType(NotAvailableScreen), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
