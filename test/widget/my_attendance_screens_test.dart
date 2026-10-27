// ignore_for_file: invalid_use_of_protected_member
import 'package:eldermin_teacher_app/app/modules/my_attendance/controllers/attendance_correction_controller.dart';
import 'package:eldermin_teacher_app/app/modules/my_attendance/controllers/my_attendance_controller.dart';
import 'package:eldermin_teacher_app/app/modules/my_attendance/views/attendance_correction_screen.dart';
import 'package:eldermin_teacher_app/app/modules/my_attendance/views/my_attendance_screen.dart';
import 'package:eldermin_teacher_app/app/modules/my_attendance/views/my_attendance_sheets.dart';
import 'package:eldermin_teacher_app/app/routes/app_routes.dart';
import 'package:eldermin_teacher_app/core/models/attendance/self_attendance_models.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:eldermin_teacher_app/core/widgets/detail_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/design_harness.dart' show loadDesignFonts;
import '../support/fake_self_attendance_repositories.dart';
import '../support/layout_probe.dart';

String? _value(DetailSheetData d, String label) => [...d.fields, for (final s in d.sections) ...s.fields].where((f) => f.label == label).firstOrNull?.value;

void main() {
  late FakeSelfAttendanceRepository repo;
  final now = DateTime(2026, 10, 8, 13);
  setUpAll(loadDesignFonts);
  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakeSelfAttendanceRepository();
  });
  tearDown(Get.reset);

  Future<void> show(WidgetTester t, Widget home, {double width = 390, double scale = 1.0}) async {
    await t.binding.setSurfaceSize(Size(width, 1400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(GetMaterialApp(
      theme: AppTheme.light,
      home: probeWrap(home, scale: scale),
      getPages: [for (final r in Routes.all) GetPage(name: r, page: () => Scaffold(body: Text('went:$r')))],
    ));
    await t.pump();
  }

  Future<void> settle(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 350));
  }

  Future<MyAttendanceController> boot(WidgetTester t, {double width = 390, double scale = 1.0}) async {
    final c = Get.put(MyAttendanceController(repository: repo, clock: () => now));
    await show(t, const MyAttendanceScreen(), width: width, scale: scale);
    await t.runAsync(() => c.reload());
    await settle(t);
    return c;
  }

  void data() {
    repo.month = (m, y) async => [
          dayRow('2026-10-03', status: 'late', checkIn: '08:25', checkOut: '14:30', late: 25, notes: 'Bus delay'),
          dayRow('2026-10-02', status: 'present', checkIn: '07:58', checkOut: '14:35'),
          dayRow('2026-10-01', status: 'sick_leave'),
          dayRow('2026-10-04', status: 'weekend'),
          dayRow('2026-10-05', status: 'brand_new_status'),
        ];
    repo.corrections = () async => [
          corrRow('p1', day: '2026-10-03', current: 'late', requested: 'present'),
          corrRow('r1', day: '2026-10-01', status: 'rejected', requested: 'sick_leave', reviewer: 'Hina HR', notes: 'Please apply for leave.'),
        ];
  }

  for (final w in [390.0, 320.0]) {
    for (final sc in [1.0, 1.3]) {
      if (w == 390 && sc == 1.3) continue;
      testWidgets('attendance tab lays out at ${w.toInt()}dp x $sc (month bar, summary, rows, chips, bottom action)', (t) async {
        data();
        await boot(t, width: w, scale: sc);
        expectNoLayoutError(t);
        expect(find.text('October 2026'), findsOneWidget);
        expectInsideScreen(t, find.byKey(const Key('my_att_summary')), w);
        expectInsideScreen(t, find.byKey(const Key('my_att_new_correction')), w);
        expectInsideScreen(t, find.text('Late'), w);
        expect(find.text('Brand_new_status'), findsNothing);
        expect(find.text('Brand new status'), findsOneWidget, reason: 'unknown status renders neutrally, readable');
        expect(find.text('Weekend'), findsOneWidget);
        expect(t.getSize(find.byKey(const Key('my_att_new_correction'))).height, greaterThanOrEqualTo(48));
      });
    }
  }

  testWidgets('summary counts and day rows (times, lateness, pending hint)', (t) async {
    data();
    await boot(t);
    final s = find.byKey(const Key('my_att_summary'));
    expect(find.descendant(of: s, matching: find.text('Present')), findsOneWidget);
    expect(find.text('In 08:25 · Out 14:30 · 25 min late · Correction pending'), findsOneWidget);
    expect(find.byKey(const ValueKey('my_att_day_d2026-10-02')), findsOneWidget);
  });

  testWidgets('month selector: previous loads September; next is disabled at the current month', (t) async {
    data();
    final c = await boot(t);
    final before = repo.monthCalls.length;
    await t.tap(find.byKey(const Key('my_att_next')));
    await settle(t);
    expect(repo.monthCalls.length, before);
    await t.tap(find.byKey(const Key('my_att_prev')));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await settle(t);
    expect(find.text('September 2026'), findsOneWidget);
    expect(repo.monthCalls.last, (9, 2026));
    expect(c.canGoNext, isTrue);
  });

  testWidgets('empty month: "No attendance records for <month>"', (t) async {
    await boot(t);
    expect(find.byKey(const Key('screen_empty')), findsOneWidget);
    expect(find.text('No attendance records for October 2026'), findsOneWidget);
  });

  testWidgets('error with retry', (t) async {
    repo.month = (m, y) async => failSelf(500);
    final c = await boot(t);
    expect(find.byKey(const Key('screen_error')), findsOneWidget);
    repo.month = (m, y) async => [dayRow('2026-10-01')];
    await t.tap(find.text('Try again'));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await settle(t);
    expect(c.rows.length, 1);
  });

  testWidgets('no linked staff record: plain explanation, no list, no action bar', (t) async {
    repo.month = (m, y) async => failNoStaff();
    repo.corrections = () async => failNoStaff();
    await boot(t);
    expect(find.byKey(const Key('my_att_no_staff')), findsOneWidget);
    expect(find.text("Your account isn't linked to a staff record yet. Ask your school admin to link it."), findsOneWidget);
    expect(find.byKey(const Key('my_att_new_correction')), findsNothing);
    expect(find.byKey(const Key('my_att_summary')), findsNothing);
  });

  testWidgets('Requests tab: rows with status chips; empty state', (t) async {
    data();
    final c = await boot(t);
    await t.tap(find.text('Requests'));
    await settle(t);
    expect(find.byKey(const ValueKey('my_att_req_p1')), findsOneWidget);
    expect(find.text('PENDING'), findsNothing);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Rejected'), findsOneWidget);
    expect(find.text('Late to Present'), findsOneWidget);
    repo.corrections = () async => [];
    await t.runAsync(() => c.loadRequests(userInitiated: true));
    await settle(t);
    expect(find.text('No correction requests yet'), findsOneWidget);
  });

  testWidgets('tapping a day opens the sheet with times and Request correction, which opens the form for that date', (t) async {
    data();
    await boot(t);
    await t.tap(find.byKey(const ValueKey('my_att_day_d2026-10-03')));
    await settle(t);
    expect(find.byKey(const Key('detail_sheet')), findsOneWidget);
    expect(find.text('08:25'), findsOneWidget);
    expect(find.text('Bus delay'), findsOneWidget);
    expect(find.text('A correction request for this day is waiting for a decision.'), findsOneWidget);
    await t.tap(find.byKey(const Key('my_att_request_correction')));
    await settle(t);
    expect(find.text('went:${Routes.myAttendanceCorrect}'), findsOneWidget);
  });

  test('sheet data: day and request (current vs requested, reviewer)', () {
    final d = attendanceDaySheetData(dayRow('2026-10-03', status: 'late', checkIn: '08:25', late: 25));
    expect(d.title, 'Sat 3 Oct 2026');
    expect(d.statusLabel, 'Late');
    expect(_value(d, 'Late by'), '25 min late');
    final r = correctionSheetData(corrRow('r1', day: '2026-10-01', status: 'rejected', current: 'absent', requested: 'sick_leave', reviewer: 'Hina HR', notes: 'Please apply for leave.'));
    expect(r.statusLabel, 'Rejected');
    final all = [for (final s in r.sections) ...s.fields.map((f) => '${s.title}/${f.label}=${f.value}')];
    expect(all, containsAll(['Recorded/Status=Absent', 'You asked for/Status=Sick leave', 'Decision/Decided by=Hina HR', 'Decision/Note=Please apply for leave.']));
    expect(r.longText, contains('biometric'));
    final pend = correctionSheetData(corrRow('p'));
    expect(pend.sections.any((s) => s.title == 'Decision'), isFalse);
    expect(pend.sections.first.fields.first.value, 'No record');
  });

  testWidgets('day sheet fits its content and keeps the request button tappable', (t) async {
    await show(t, Builder(builder: (c) => TextButton(onPressed: () => showAttendanceDaySheet(c, dayRow('2026-10-27', status: 'present', checkIn: '08:02')), child: const Text('open'))));
    await t.tap(find.text('open'));
    await settle(t);
    expect(t.getSize(find.byKey(const Key('detail_sheet'))).height, lessThan(400));
    expectNoLayoutError(t);
    await t.tap(find.byKey(const Key('my_att_request_correction')));
    await settle(t);
    expect(find.text('went:${Routes.myAttendanceCorrect}'), findsOneWidget);
  });

  group('correction form', () {
    Future<AttendanceCorrectionController> form(WidgetTester t, {DateTime? date, double width = 390, double scale = 1.0}) async {
      final list = Get.put(MyAttendanceController(repository: repo, clock: () => now));
      final c = Get.put(AttendanceCorrectionController(repository: repo, list: list, initialDate: date, clock: () => now));
      await show(t, const AttendanceCorrectionScreen(), width: width, scale: scale);
      await settle(t);
      return c;
    }

    testWidgets('lays out at 320dp x 1.3; date prefilled; counter shown', (t) async {
      await form(t, date: DateTime(2026, 10, 3), width: 320, scale: 1.3);
      expectNoLayoutError(t);
      expect(find.text('Sat 3 Oct 2026'), findsOneWidget);
      expectInsideScreen(t, find.byKey(const Key('corr_submit')), 320);
      expect(find.byKey(const Key('corr_counter')), findsOneWidget);
    });

    testWidgets('status picker offers exactly the eight statuses (no holiday / weekend)', (t) async {
      await form(t, date: DateTime(2026, 10, 3));
      await t.tap(find.byKey(const Key('corr_status')));
      await settle(t);
      for (final s in StaffDayStatus.requestableValues) {
        expect(find.byKey(Key('corr_status_${s.wire}')), findsOneWidget, reason: s.wire);
      }
      expect(find.byKey(const Key('corr_status_holiday')), findsNothing);
      expect(find.byKey(const Key('corr_status_weekend')), findsNothing);
      await t.tap(find.byKey(const Key('corr_status_half_day')));
      await settle(t);
      expect(find.text('Half day'), findsOneWidget);
    });

    testWidgets('short reason blocked client-side: no request, error shown', (t) async {
      final c = await form(t, date: DateTime(2026, 10, 3));
      c.setStatus(StaffDayStatus.present);
      await t.enterText(find.byKey(const Key('corr_reason')), 'too short');
      await t.pump();
      await t.tap(find.byKey(const Key('corr_submit')));
      await settle(t);
      expect(repo.submitCount, 0);
      expect(find.textContaining('at least 10 characters'), findsWidgets);
    });

    testWidgets('valid form sends, confirms and closes; the list switches to Requests', (t) async {
      final c = await form(t, date: DateTime(2026, 10, 3));
      c.setStatus(StaffDayStatus.present);
      c.setCheckIn('07:55');
      await t.enterText(find.byKey(const Key('corr_reason')), 'The reader was down this morning.');
      await t.pump();
      await t.runAsync(() async {
        await c.submit();
      });
      await settle(t);
      expect(repo.lastSubmit!.toJson()['requestedCheckInTime'], '07:55');
      expect(Get.find<MyAttendanceController>().tab.value, MyAttendanceTab.requests);
    });

    testWidgets('400 server text is shown in the banner; 404 no staff shows the dedicated state', (t) async {
      final c = await form(t, date: DateTime(2026, 10, 3));
      c.setStatus(StaffDayStatus.present);
      c.reasonC.text = 'The reader was down this morning.';
      repo.submit0 = (b) async => failSelf(400, 'reason is required');
      await t.runAsync(() => c.submit());
      await settle(t);
      expect(find.text('reason is required'), findsWidgets);
      expect(find.byKey(const Key('corr_submit_error')), findsOneWidget);
      repo.submit0 = (b) async => failNoStaff();
      await t.runAsync(() => c.submit());
      await settle(t);
      expect(find.byKey(const Key('corr_no_staff')), findsOneWidget);
    });
  });
}
