import 'dart:convert';
import 'dart:io';
import 'package:eldermin_teacher_app/core/models/attendance/self_attendance_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/network/response_shape.dart';
import 'package:eldermin_teacher_app/core/services/self_attendance_repository.dart';
import 'package:eldermin_teacher_app/core/utils/self_attendance_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/fake_phase7b_repositories.dart' show RecordingClient;

dynamic fx(String n) => jsonDecode(File('test/fixtures/self_attendance/$n.json').readAsStringSync());

void main() {
  group('StaffDayStatus', () {
    test('every wire value parses; unknown / null / empty fall back to unknown', () {
      for (final w in ['present', 'absent', 'late', 'half_day', 'on_leave', 'sick_leave', 'holiday', 'weekend', 'remote', 'extra_day']) {
        final s = StaffDayStatus.parse(w);
        expect(s, isNot(StaffDayStatus.unknown), reason: w);
        expect(s.wire, w);
      }
      for (final w in [null, '', 'teleporting', 'PRESENT']) {
        expect(StaffDayStatus.parse(w), StaffDayStatus.unknown, reason: '$w');
      }
    });

    test('exactly the eight DTO statuses are requestable (no holiday, no weekend, no unknown)', () {
      expect(StaffDayStatus.requestableValues.map((s) => s.wire), ['present', 'absent', 'late', 'half_day', 'on_leave', 'sick_leave', 'remote', 'extra_day']);
    });

    test('statusText keeps an unknown server value readable and never empty', () {
      expect(statusText(StaffDayStatus.unknown, 'compensatory_off'), 'Compensatory off');
      expect(statusText(StaffDayStatus.unknown, ''), 'Not recorded');
      expect(statusText(StaffDayStatus.sickLeave, 'sick_leave'), 'Sick leave');
    });
  });

  group('StaffAttendanceDay', () {
    final rows = (fx('month') as List).map((e) => StaffAttendanceDay.fromJson(Map<String, dynamic>.from(e as Map))).toList();

    test('parses times, lateness, notes; a populated staffId object is ignored', () {
      final d = rows.first;
      expect(d.id, '64e000000000000000000003');
      expect(d.status, StaffDayStatus.late);
      expect(d.checkIn, '08:25');
      expect(d.checkOut, '14:30');
      expect(d.lateByMins, 25);
      expect(d.workingHours, 6.1);
      expect(d.notes, 'Bus delay');
      expect(d.source, 'manual');
    });

    test('missing fields give empty text / null numbers, not errors', () {
      final d = rows[2];
      expect(d.status, StaffDayStatus.absent);
      expect(d.checkIn, '');
      expect(d.lateByMins, isNull);
      expect(d.notes, '');
    });

    test('an unknown status renders neutrally; garbage row does not throw', () {
      final d = StaffAttendanceDay.fromJson({'date': '2026-10-05T00:00:00.000Z', 'status': 'quantum'});
      expect(d.status, StaffDayStatus.unknown);
      expect(d.statusLabel, 'Quantum');
      final g = StaffAttendanceDay.fromJson({'date': 5, 'status': 7, 'checkInTime': null, 'lateByMins': 'x'});
      expect(g.day, isNotNull); // epoch ms number is a date
      expect(StaffAttendanceDay.fromJson({}).day, isNull);
    });

    test('the date is the stored UTC calendar day: UTC midnight never shifts a day, whatever the device zone', () {
      expect(StaffAttendanceDay.fromJson({'date': '2026-10-03T00:00:00.000Z'}).day, DateTime(2026, 10, 3));
      expect(StaffAttendanceDay.fromJson({'date': '2026-01-01T00:00:00.000Z'}).day, DateTime(2026, 1, 1));
      expect(StaffAttendanceDay.fromJson({'date': '2026-12-31T00:00:00.000Z'}).day, DateTime(2026, 12, 31));
      // a negative-offset spelling of the same instant is still read in UTC (Oct 2 19:00 -05:00 == Oct 3 00:00Z)
      expect(StaffAttendanceDay.fromJson({'date': '2026-10-02T19:00:00-05:00'}).day, DateTime(2026, 10, 3));
      // and a positive one (Oct 3 05:30 +05:30 == Oct 3 00:00Z)
      expect(StaffAttendanceDay.fromJson({'date': '2026-10-03T05:30:00+05:30'}).day, DateTime(2026, 10, 3));
    });
  });

  group('AttendanceCorrectionRequest', () {
    final rows = (fx('corrections') as List).map((e) => AttendanceCorrectionRequest.fromJson(Map<String, dynamic>.from(e as Map))).toList();

    test('pending request: current vs requested, times, reason', () {
      final r = rows.first;
      expect(r.status, CorrectionStatus.pending);
      expect(r.day, DateTime(2026, 10, 3));
      expect(r.currentStatus, StaffDayStatus.late);
      expect(r.requestedStatus, StaffDayStatus.present);
      expect(r.currentCheckIn, '08:25');
      expect(r.requestedCheckIn, '07:55');
      expect(r.requestedCheckOut, '14:30');
      expect(r.reviewerName, '');
    });

    test('rejected request: reviewer, date and notes; no current record -> "No record"', () {
      final r = rows[1];
      expect(r.status, CorrectionStatus.rejected);
      expect(r.reviewerName, 'Hina HR Manager');
      expect(r.reviewedAt, DateTime.utc(2026, 10, 2, 9));
      expect(r.reviewNotes, 'Please apply for leave instead.');
      expect(r.currentLabel, 'No record');
      expect(r.requestedLabel, 'Sick leave');
    });

    test('unknown request status / requested status are neutral', () {
      final r = AttendanceCorrectionRequest.fromJson({'_id': 'x', 'status': 'escalated', 'requestedStatus': 'mystery'});
      expect(r.status, CorrectionStatus.unknown);
      expect(r.requestedLabel, 'Mystery');
    });
  });

  group('AttendanceCorrectionBody', () {
    test('exact body: local calendar date, wire status, trimmed reason, empty times omitted', () {
      final b = AttendanceCorrectionBody(date: DateTime(2026, 3, 5, 23, 59), status: StaffDayStatus.halfDay, reason: '  Doctor visit in the morning  ');
      expect(b.toJson(), {'attendanceDate': '2026-03-05', 'requestedStatus': 'half_day', 'reason': 'Doctor visit in the morning'});
      final t = AttendanceCorrectionBody(date: DateTime(2026, 10, 3), status: StaffDayStatus.present, checkIn: '07:55', checkOut: '', reason: 'Reader was down all morning');
      expect(t.toJson(), {'attendanceDate': '2026-10-03', 'requestedStatus': 'present', 'requestedCheckInTime': '07:55', 'reason': 'Reader was down all morning'});
    });
  });

  group('rules', () {
    final today = DateTime(2026, 10, 8, 13);
    test('valid form has no problems', () {
      expect(validateCorrection(date: DateTime(2026, 10, 8), status: StaffDayStatus.present, reason: 'I was on site all day', today: today), isEmpty);
    });
    test('reason shorter than 10 (after trim) is blocked; 2001 chars blocked; 2000 ok', () {
      expect(validateCorrection(date: today, status: StaffDayStatus.present, reason: '  too short ', today: today).keys, ['reason']);
      expect(validateCorrection(date: today, status: StaffDayStatus.present, reason: 'x' * 2001, today: today).keys, ['reason']);
      expect(validateCorrection(date: today, status: StaffDayStatus.present, reason: 'x' * 2000, today: today), isEmpty);
    });
    test('future date, missing date / status, holiday and weekend are blocked', () {
      expect(validateCorrection(date: DateTime(2026, 10, 9), status: StaffDayStatus.present, reason: 'long enough reason', today: today).keys, ['date']);
      expect(validateCorrection(date: null, status: null, reason: 'long enough reason', today: today).keys, ['date', 'status']);
      for (final s in [StaffDayStatus.holiday, StaffDayStatus.weekend, StaffDayStatus.unknown]) {
        expect(validateCorrection(date: today, status: s, reason: 'long enough reason', today: today).keys, ['status']);
      }
    });
    test('month summary counts only what the records support', () {
      final days = (fx('month') as List).map((e) => StaffAttendanceDay.fromJson(Map<String, dynamic>.from(e as Map)));
      final s = MonthSummary.of(days);
      expect((s.present, s.late, s.absent, s.leave), (1, 1, 1, 0));
    });
  });

  group('SelfAttendanceRepository', () {
    test('fetchMonth: GET .../hr/attendance/self with month and year; bare array parsed, newest first, rows without a date dropped', () async {
      final raw = [...(fx('month') as List), {'_id': 'nodate', 'status': 'present'}];
      final c = RecordingClient(raw);
      final rows = await SelfAttendanceRepository(c).fetchMonth(10, 2026);
      expect(c.calls.single.method, 'GET');
      expect(c.calls.single.url, endsWith('/api/v1/hr/attendance/self'));
      expect(c.calls.single.query, {'month': 10, 'year': 2026});
      expect(rows.map((d) => d.day!.day), [4, 3, 2, 1]);
    });

    test('listCorrections: GET .../self/correction-requests', () async {
      final c = RecordingClient(fx('corrections'));
      final rows = await SelfAttendanceRepository(c).listCorrections();
      expect(c.calls.single.url, endsWith('/api/v1/hr/attendance/self/correction-requests'));
      expect(rows.map((r) => r.id), ['64f000000000000000000002', '64f000000000000000000001']);
    });

    test('submitCorrection: POST the exact body, returns the created request', () async {
      final c = RecordingClient({'_id': 'n1', 'attendanceDate': '2026-10-03T00:00:00.000Z', 'requestedStatus': 'present', 'reason': 'x', 'status': 'pending'});
      final r = await SelfAttendanceRepository(c).submitCorrection(AttendanceCorrectionBody(date: DateTime(2026, 10, 3), status: StaffDayStatus.present, checkIn: '07:55', reason: 'Reader was down all morning'));
      expect(c.calls.single.method, 'POST');
      expect(c.calls.single.url, endsWith('/api/v1/hr/attendance/self/correction-requests'));
      expect(c.calls.single.data, {'attendanceDate': '2026-10-03', 'requestedStatus': 'present', 'requestedCheckInTime': '07:55', 'reason': 'Reader was down all morning'});
      expect(r.id, 'n1');
      expect(r.status, CorrectionStatus.pending);
    });

    test('a created request without an id is a typed shape error', () async {
      await expectLater(SelfAttendanceRepository(RecordingClient({'status': 'pending'})).submitCorrection(AttendanceCorrectionBody(date: DateTime(2026, 10, 3), status: StaffDayStatus.present, reason: 'long enough reason')), throwsA(isA<UnexpectedResponseShape>()));
    });

    test('wrong shapes are typed errors, empty array is a valid empty result', () async {
      expect(await SelfAttendanceRepository(RecordingClient([])).fetchMonth(1, 2026), isEmpty);
      for (final bad in [<String, Object?>{'x': 1}, 'oops', null]) {
        await expectLater(SelfAttendanceRepository(RecordingClient(bad)).fetchMonth(1, 2026), throwsA(isA<UnexpectedResponseShape>()), reason: '$bad');
      }
    });

    test('404 "No staff record is linked..." maps to NoStaffRecord on all three calls; other 404 stays a plain 404', () async {
      for (final call in <Future<Object?> Function(SelfAttendanceRepository)>[
        (r) => r.fetchMonth(10, 2026),
        (r) => r.listCorrections(),
        (r) => r.submitCorrection(AttendanceCorrectionBody(date: DateTime(2026, 10, 3), status: StaffDayStatus.present, reason: 'long enough reason')),
      ]) {
        final c = RecordingClient([])
          ..failStatus = 404
          ..failMessage = 'No staff record is linked to your account. Contact HR to have your login connected to your employee record.';
        await expectLater(call(SelfAttendanceRepository(c)), throwsA(isA<NoStaffRecord>()));
      }
      final other = RecordingClient([])
        ..failStatus = 404
        ..failMessage = 'Cannot GET /api/v1/hr/attendance/self';
      await expectLater(SelfAttendanceRepository(other).fetchMonth(10, 2026), throwsA(allOf(isA<ApiException>(), isNot(isA<NoStaffRecord>()))));
    });

    test('400 keeps the server text; 403 / 500 keep their status', () async {
      final c = RecordingClient([])
        ..failStatus = 400
        ..failMessage = 'requestedStatus must be one of: present, absent';
      await expectLater(SelfAttendanceRepository(c).listCorrections(), throwsA(isA<ApiException>().having((e) => e.message, 'm', contains('requestedStatus must be one of'))));
      for (final s in [403, 500]) {
        final f = RecordingClient([])..failStatus = s;
        await expectLater(SelfAttendanceRepository(f).fetchMonth(1, 2026), throwsA(isA<ApiException>().having((e) => e.statusCode, 's', s)));
      }
    });
  });
}
