// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';
import 'package:eldermin_teacher_app/app/common/action_failure.dart';
import 'package:eldermin_teacher_app/app/modules/home/models/section_state.dart';
import 'package:eldermin_teacher_app/app/modules/my_attendance/controllers/attendance_correction_controller.dart';
import 'package:eldermin_teacher_app/app/modules/my_attendance/controllers/my_attendance_controller.dart';
import 'package:eldermin_teacher_app/core/models/attendance/self_attendance_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/fake_self_attendance_repositories.dart';

void main() {
  late FakeSelfAttendanceRepository repo;
  final now = DateTime(2026, 10, 8, 13);

  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakeSelfAttendanceRepository();
  });
  tearDown(Get.reset);

  MyAttendanceController list() => MyAttendanceController(repository: repo, clock: () => now);

  group('MyAttendanceController', () {
    test('opens on the current month; loads that month and the requests', () async {
      repo.month = (m, y) async => [dayRow('2026-10-02', status: 'late'), dayRow('2026-10-01')];
      repo.corrections = () async => [corrRow('c1')];
      final c = list();
      await c.reload();
      expect(c.month.value, DateTime(2026, 10));
      expect(repo.monthCalls, [(10, 2026)]);
      expect(c.days.value.status, SectionStatus.data);
      expect(c.rows.length, 2);
      expect(c.requests.value.data!.single.id, 'c1');
      expect(c.noStaffRecord.value, isFalse);
      expect((c.summary.present, c.summary.late), (1, 1));
    });

    test('previous / next month reload that month; next is blocked at the current month', () async {
      final c = list();
      await c.reload();
      expect(c.canGoNext, isFalse);
      await c.nextMonth();
      expect(c.month.value, DateTime(2026, 10));
      expect(repo.monthCalls.length, 1, reason: 'no request for a future month');
      await c.previousMonth();
      expect(c.month.value, DateTime(2026, 9));
      expect(repo.monthCalls.last, (9, 2026));
      expect(c.canGoNext, isTrue);
      await c.nextMonth();
      expect(c.month.value, DateTime(2026, 10));
      await c.setMonth(DateTime(2027, 3)); // clamped
      expect(c.month.value, DateTime(2026, 10));
    });

    test('previous month across a year boundary', () async {
      final c = MyAttendanceController(repository: repo, clock: () => DateTime(2026, 1, 20));
      await c.previousMonth();
      expect(c.month.value, DateTime(2025, 12));
      expect(repo.monthCalls.single, (12, 2025));
    });

    test('empty month is the empty state; a month change does not show the old month while loading', () async {
      repo.month = (m, y) async => m == 10 ? [dayRow('2026-10-01')] : [];
      final c = list();
      await c.loadDays();
      expect(c.days.value.status, SectionStatus.data);
      final gate = Completer<List<StaffAttendanceDay>>();
      repo.month = (m, y) => gate.future;
      final f = c.previousMonth();
      expect(c.days.value.status, SectionStatus.loading);
      gate.complete([]);
      await f;
      expect(c.days.value.status, SectionStatus.empty);
    });

    test('a slow earlier month answer never overwrites a later month', () async {
      final slow = Completer<List<StaffAttendanceDay>>();
      repo.month = (m, y) => m == 10 ? slow.future : Future.value([dayRow('2026-09-01')]);
      final c = list();
      final first = c.loadDays();
      await c.previousMonth();
      slow.complete([dayRow('2026-10-01')]);
      await first;
      expect(c.rows.single.id, 'd2026-09-01');
    });

    test('refresh failure keeps the rows (stale) unless user-initiated; first failure is an error with retry', () async {
      final c = list();
      repo.month = (m, y) async => failSelf(500);
      await c.loadDays();
      expect(c.days.value.status, SectionStatus.error);
      repo.month = (m, y) async => [dayRow('2026-10-01')];
      await c.loadDays();
      repo.month = (m, y) async => failSelf(500);
      await c.loadDays();
      expect(c.rows.length, 1);
      await c.loadDays(userInitiated: true);
      expect(c.days.value.isStale, isTrue);
    });

    test('404 "no staff record" on both reads turns the dedicated state on (not "unavailable")', () async {
      repo.month = (m, y) async => failNoStaff();
      repo.corrections = () async => failNoStaff();
      final c = list();
      await c.reload();
      expect(c.noStaffRecord.value, isTrue);
      expect(c.days.value.status, SectionStatus.empty);
      expect(c.requests.value.status, SectionStatus.empty);
      repo.month = (m, y) async => [dayRow('2026-10-01')];
      repo.corrections = () async => [];
      await c.reload(userInitiated: true);
      expect(c.noStaffRecord.value, isFalse, reason: 'linked in the meantime');
    });

    test('403 / plain 404 are classified like every other section', () async {
      repo.month = (m, y) async => failSelf(403);
      repo.corrections = () async => failSelf(404, 'Cannot GET /x');
      final c = list();
      await c.reload();
      expect(c.days.value.status, SectionStatus.forbidden);
      expect(c.requests.value.status, SectionStatus.unavailable);
      expect(c.noStaffRecord.value, isFalse);
    });

    test('submitted() shows the request first, switches to Requests and re-reads the list', () async {
      repo.corrections = () async => [corrRow('c1')];
      final c = list();
      await c.reload();
      repo.corrections = () async => [corrRow('new1'), corrRow('c1')];
      c.submitted(corrRow('new1'));
      expect(c.tab.value, MyAttendanceTab.requests);
      expect(c.requests.value.data!.map((r) => r.id), ['new1', 'c1']);
      await Future<void>.delayed(Duration.zero);
      expect(repo.calls.where((x) => x == 'corrections').length, 2);
    });

    test('pendingFor finds a pending request on that day only', () async {
      repo.corrections = () async => [corrRow('p', day: '2026-10-03'), corrRow('r', day: '2026-10-04', status: 'rejected')];
      final c = list();
      await c.loadRequests();
      expect(c.pendingFor(DateTime(2026, 10, 3))?.id, 'p');
      expect(c.pendingFor(DateTime(2026, 10, 4)), isNull);
    });
  });

  group('AttendanceCorrectionController', () {
    AttendanceCorrectionController form({MyAttendanceController? l, DateTime? date}) {
      final c = AttendanceCorrectionController(repository: repo, list: l, initialDate: date, clock: () => now);
      c.onInit();
      return c;
    }

    test('prefilled date; status options are exactly the eight (no holiday / weekend)', () {
      final c = form(date: DateTime(2026, 10, 3, 17));
      expect(c.date.value, DateTime(2026, 10, 3));
      expect(c.wireDate, '2026-10-03');
      expect(c.statusOptions.map((s) => s.wire), ['present', 'absent', 'late', 'half_day', 'on_leave', 'sick_leave', 'remote', 'extra_day']);
      expect(c.statusOptions.map((s) => s.wire), isNot(contains('holiday')));
      expect(c.statusOptions.map((s) => s.wire), isNot(contains('weekend')));
    });

    test('reason shorter than 10 characters is blocked client-side: no request is sent', () async {
      final c = form(date: DateTime(2026, 10, 3));
      c.setStatus(StaffDayStatus.present);
      c.reasonC.text = 'too short';
      final r = await c.submit();
      expect(r, isA<CorrectionInvalid>());
      expect(c.errors['reason'], isNotNull);
      expect(repo.submitCount, 0);
      expect(c.reasonLength.value, 9);
    });

    test('missing date / status / future date are blocked', () async {
      final c = form();
      c.reasonC.text = 'A perfectly good reason';
      final r = await c.submit() as CorrectionInvalid;
      expect(r.errors.keys, ['date', 'status']);
      c.setDate(DateTime(2026, 10, 9));
      c.setStatus(StaffDayStatus.late);
      expect((await c.submit() as CorrectionInvalid).errors.keys, ['date']);
      expect(repo.submitCount, 0);
    });

    test('success: sends the exact body, refreshes the list, switches the list to Requests, then ignores a second submit', () async {
      repo.corrections = () async => [corrRow('new1')];
      final l = list();
      Get.put(l);
      final c = form(l: l, date: DateTime(2026, 10, 3));
      c.setStatus(StaffDayStatus.present);
      c.setCheckIn('07:55');
      c.setCheckOut('14:30');
      c.reasonC.text = '  The reader was down this morning.  ';
      final r = await c.submit();
      expect(r, isA<CorrectionDone>());
      expect(repo.lastSubmit!.toJson(), {'attendanceDate': '2026-10-03', 'requestedStatus': 'present', 'requestedCheckInTime': '07:55', 'requestedCheckOutTime': '14:30', 'reason': 'The reader was down this morning.'});
      expect(l.tab.value, MyAttendanceTab.requests);
      expect(l.requests.value.data!.first.id, 'new1');
      await Future<void>.delayed(Duration.zero);
      expect(repo.calls, contains('corrections'));
      expect(await c.submit(), isA<CorrectionIgnored>());
      expect(repo.submitCount, 1);
      expect(c.saving.value, isFalse);
    });

    test('double submit while in flight is ignored (one request)', () async {
      final gate = Completer<AttendanceCorrectionRequest>();
      repo.submit0 = (b) => gate.future;
      final c = form(date: DateTime(2026, 10, 3));
      c.setStatus(StaffDayStatus.absent);
      c.reasonC.text = 'I was ill all week long';
      final first = c.submit();
      expect(c.saving.value, isTrue);
      expect(await c.submit(), isA<CorrectionIgnored>());
      gate.complete(corrRow('n'));
      await first;
      expect(repo.submitCount, 1);
    });

    test('400: the server text is surfaced as is and the form stays editable (not done)', () async {
      repo.submit0 = (b) async => failSelf(400, 'reason is required, requestedStatus must be one of: present');
      final c = form(date: DateTime(2026, 10, 3));
      c.setStatus(StaffDayStatus.present);
      c.reasonC.text = 'A perfectly good reason';
      final r = await c.submit() as CorrectionFailed;
      expect(r.text, 'reason is required, requestedStatus must be one of: present');
      expect(r.failure.kind, ActionFailureKind.validation);
      expect(c.failureText.value, r.text);
      expect(c.saving.value, isFalse);
      repo.submit0 = (b) async => corrRow('ok');
      expect(await c.submit(), isA<CorrectionDone>(), reason: 'a fixed form can be sent again');
    });

    test('404 no staff record: the dedicated failure; 500 and offline give calm texts', () async {
      repo.submit0 = (b) async => failNoStaff();
      final c = form(date: DateTime(2026, 10, 3));
      c.setStatus(StaffDayStatus.present);
      c.reasonC.text = 'A perfectly good reason';
      final r = await c.submit() as CorrectionFailed;
      expect(r.noStaffRecord, isTrue);
      expect(c.noStaffRecord.value, isTrue);
      expect(r.text, contains('linked to a staff record'));
      repo.submit0 = (b) async => failSelf(500);
      final s = await c.submit() as CorrectionFailed;
      expect(s.failure.kind, ActionFailureKind.server);
      repo.submit0 = (b) async => failSelf(null, 'No internet');
      expect((await c.submit() as CorrectionFailed).failure.kind, ActionFailureKind.offline);
    });
  });
}
