import 'package:eldermin_teacher_app/core/models/home/teaching.dart';
import 'package:eldermin_teacher_app/core/models/leave/leave_models.dart';
import 'package:eldermin_teacher_app/core/network/response_shape.dart';
import 'package:eldermin_teacher_app/core/services/fixtures_repository.dart';
import 'package:eldermin_teacher_app/core/services/leave_repository.dart';
import 'package:eldermin_teacher_app/core/utils/fixture_rules.dart';
import 'package:eldermin_teacher_app/core/utils/leave_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/fake_phase7b_repositories.dart';

void main() {
  group('fixtures: tabs, role, mark-complete gating', () {
    final cover = fixture('c1'); // I am the substitute
    final coverDone = fixture('c2', status: 'completed');
    final covered = fixture('o1', original: myStaff, substitute: otherStaff);
    final open = fixture('o2', original: myStaff, substitute: null, status: 'open');
    final third = fixture('x1', original: otherStaff, substitute: '64a0000000000000000000a8');
    final all = [cover, coverDone, covered, open, third];

    test('tabs cut by which side I am on; a fixture of two other teachers belongs to neither', () {
      expect(rowsFor(FixtureTab.covering, all, myStaff).map((s) => s.id), ['c1', 'c2']);
      expect(rowsFor(FixtureTab.covered, all, myStaff).map((s) => s.id), ['o1', 'o2']);
      expect(rowsFor(FixtureTab.covering, all, null), isEmpty);
    });

    test('Mark complete ONLY for my assigned cover (UI gating: the server would complete anyone\'s)', () {
      expect(canMarkComplete(cover, myStaff), isTrue);
      for (final s in [coverDone, fixture('a', status: 'open'), fixture('b', status: 'cancelled'), covered, open, third]) {
        expect(canMarkComplete(s, myStaff), isFalse, reason: '${s.id} ${s.status}');
      }
      expect(canMarkComplete(cover, null), isFalse);
      expect(canMarkComplete(cover, ''), isFalse);
    });

    test('grouping: today and later first (soonest), then earlier days (newest first); inside a day by period; undated kept apart', () {
      final now = DateTime(2026, 10, 8, 13);
      final g = groupFixtures([
        fixture('p3', day: '2026-10-08', period: 3),
        fixture('p1', day: '2026-10-08', period: 1),
        fixture('later', day: '2026-10-12'),
        fixture('old1', day: '2026-10-01'),
        fixture('old2', day: '2026-10-06'),
        Substitution.fromJson({'_id': 'nodate', 'status': 'assigned'}),
      ], now);
      expect(g.days.map((d) => d.day), [DateTime(2026, 10, 8), DateTime(2026, 10, 12), DateTime(2026, 10, 6), DateTime(2026, 10, 1)]);
      expect(g.days.map((d) => d.upcoming), [true, true, false, false]);
      expect(g.days.first.rows.map((s) => s.id), ['p1', 'p3']);
      expect(g.undated.map((s) => s.id), ['nodate']);
    });

    test('the date is the stored calendar day (UTC components), not shifted by the device zone', () {
      expect(fixtureDay(fixture('a', day: '2026-10-08')), DateTime(2026, 10, 8));
    });

    test('window starts 14 days back at a UTC midnight', () {
      expect(fixturesFrom(DateTime(2026, 10, 8, 23)), DateTime.utc(2026, 9, 24));
    });

    test('model reads reason and notes; parses the stub fixture; copyWithStatus only changes the status', () {
      final rows = (fx7b('fixtures') as List).map((e) => Substitution.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      expect(rows, hasLength(6));
      expect(rows.map((s) => s.status).toSet(), {'assigned', 'open', 'completed', 'cancelled'});
      final open = rows.firstWhere((s) => s.status == 'open');
      expect(open.substituteTeacherId, isNull);
      expect(open.reason, 'training');
      final changed = cover.copyWithStatus('completed');
      expect((changed.status, changed.subject, changed.periodNo, changed.substituteTeacherId), ('completed', cover.subject, cover.periodNo, cover.substituteTeacherId));
    });

    test('repository: request, complete, wrong shapes', () async {
      final c = RecordingClient([]);
      final r = FixturesRepository(c);
      await r.fetchFixtures(staffId: myStaff, from: DateTime.utc(2026, 9, 24));
      expect(c.calls.last.url, endsWith('/teaching/fixtures'));
      expect(c.calls.last.query, {'teacherId': myStaff, 'from': '2026-09-24T00:00:00.000Z'});
      c.body = {'_id': 'f1', 'status': 'completed'};
      expect((await r.complete('f1')).status, 'completed');
      expect(c.calls.last.method, 'PATCH');
      expect(c.calls.last.url, endsWith('/teaching/fixtures/f1/complete'));
      for (final bad in <Object?>[{'fixtures': []}, 'x', null, 3]) {
        c.body = bad;
        await expectLater(r.fetchFixtures(staffId: myStaff), throwsA(isA<UnexpectedResponseShape>()), reason: '$bad');
      }
      for (final bad in <Object?>[[], 'x', null, {'status': 'completed'}]) {
        c.body = bad;
        await expectLater(r.complete('f1'), throwsA(isA<UnexpectedResponseShape>()), reason: '$bad');
      }
    });
  });

  group('leave: models from the stub fixtures', () {
    test('balance: six tracked types with entitled / used / remaining; hasPolicy', () {
      final b = LeaveBalanceSummary.fromJson(Map<String, dynamic>.from(fx7b('leave_balance') as Map));
      expect(b.hasPolicy, isTrue);
      expect(b.buckets.map((k) => k.type.wire), ['annual', 'sick', 'casual', 'maternity', 'paternity', 'hajj']);
      final annual = b.of(StaffLeaveType.annual)!;
      expect((annual.entitled, annual.used, annual.remaining), (21, 4, 17));
      expect(b.shown.map((k) => k.type), isNot(contains(StaffLeaveType.hajj)), reason: 'entitled 0 and used 0: no card');
      expect(b.of(StaffLeaveType.emergency), isNull);
    });

    test('no policy: hasPolicy false (every number is a meaningless 0); a missing hasPolicy defaults to true; remaining is derived when absent', () {
      final b = LeaveBalanceSummary.fromJson(Map<String, dynamic>.from(fx7b('leave_balance_nopolicy') as Map));
      expect(b.hasPolicy, isFalse);
      expect(b.shown, isEmpty);
      final c = LeaveBalanceSummary.fromJson({'annual': {'entitled': 10, 'used': 3}});
      expect(c.hasPolicy, isTrue);
      expect(c.of(StaffLeaveType.annual)!.remaining, 7);
      expect(LeaveBalanceSummary.fromJson(const {}).buckets, isEmpty);
    });

    test('history: statuses, half day, dates as calendar days; the populated approver (with its EMAIL) is never read', () {
      final raw = (fx7b('leave_history') as List);
      expect(raw.any((e) => (e as Map)['approvedBy'] is Map && (e['approvedBy'] as Map).containsKey('email')), isTrue, reason: 'the fixture carries the approver email like the real server');
      final rows = raw.map((e) => StaffLeaveRequest.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      expect(rows.map((l) => l.status).toSet(), {StaffLeaveStatus.approved, StaffLeaveStatus.rejected, StaffLeaveStatus.pending});
      final rejected = rows.firstWhere((l) => l.status == StaffLeaveStatus.rejected);
      expect((rejected.approverName, rejected.approverNote, rejected.rejectionReason), ('Hina HR (DUMMY)', 'Exam week: please pick another day.', 'Exam week'));
      expect(rows.first.firstDay, isNotNull);
      final dump = rows.map((l) => '${l.approverName}${l.approverNote}${l.rejectionReason}${l.reason}${l.leaveNo}').join();
      expect(dump, isNot(contains('@')));
      expect(StaffLeaveStatus.parse('on_hold'), StaffLeaveStatus.onHold);
      expect(StaffLeaveStatus.parse('zzz'), StaffLeaveStatus.unknown);
      expect(StaffLeaveStatus.pending.isLive && StaffLeaveStatus.approved.isLive && StaffLeaveStatus.onHold.isLive, isTrue);
      expect(StaffLeaveStatus.rejected.isLive || StaffLeaveStatus.cancelled.isLive, isFalse);
    });

    test('request body: leaveType, YYYY-MM-DD dates, trimmed reason, half-day session only when half day; no totalDays, no identity', () {
      final full = StaffLeaveRequestBody(type: StaffLeaveType.sick, from: DateTime(2026, 11, 2), to: DateTime(2026, 11, 4), reason: '  Fever and rest  ');
      expect(full.toJson(), {'leaveType': 'sick', 'fromDate': '2026-11-02', 'toDate': '2026-11-04', 'reason': 'Fever and rest', 'isHalfDay': false});
      final half = StaffLeaveRequestBody(type: StaffLeaveType.annual, from: DateTime(2026, 11, 2), to: DateTime(2026, 11, 2), reason: 'Dentist visit', halfDay: true, halfDaySession: 'afternoon');
      expect(half.toJson(), {'leaveType': 'annual', 'fromDate': '2026-11-02', 'toDate': '2026-11-02', 'reason': 'Dentist visit', 'isHalfDay': true, 'halfDaySession': 'afternoon'});
      for (final k in ['totalDays', 'staffId', 'status', 'staffName']) {
        expect(full.toJson().containsKey(k), isFalse);
      }
    });

    test('leave types: the ten schema values, six tracked', () {
      expect(StaffLeaveType.values.map((t) => t.wire), ['annual', 'sick', 'casual', 'maternity', 'paternity', 'hajj', 'emergency', 'unpaid', 'study', 'other']);
      expect(StaffLeaveType.values.where((t) => t.tracked), hasLength(6));
      expect(StaffLeaveType.parse('nope'), isNull);
    });

    test('repository: requests and shapes', () async {
      final c = RecordingClient({'annual': {}});
      final r = LeaveRepository(c);
      await r.fetchBalance();
      expect(c.calls.last.url, endsWith('/hr/leave/self/balance'));
      c.body = [];
      expect(await r.fetchHistory(), isEmpty);
      expect(c.calls.last.url, endsWith('/hr/leave/self/history'));
      c.body = {'_id': 'l1', 'status': 'pending', 'leaveType': 'sick'};
      final l = await r.apply(StaffLeaveRequestBody(type: StaffLeaveType.sick, from: DateTime(2026, 11, 2), to: DateTime(2026, 11, 3), reason: 'Feeling unwell today'));
      expect((l.id, c.calls.last.method), ('l1', 'POST'));
      expect(c.calls.last.url, endsWith('/hr/leave/self'));
      for (final bad in <Object?>[[], 'x', null]) {
        c.body = bad;
        await expectLater(r.fetchBalance(), throwsA(isA<UnexpectedResponseShape>()), reason: '$bad');
      }
      for (final bad in <Object?>[{'items': []}, 'x', null, {'data': 3}]) {
        c.body = bad;
        await expectLater(r.fetchHistory(), throwsA(isA<UnexpectedResponseShape>()), reason: '$bad');
      }
      c.body = {'status': 'pending'};
      await expectLater(r.apply(StaffLeaveRequestBody(type: StaffLeaveType.sick, from: DateTime(2026, 11, 2), to: DateTime(2026, 11, 3), reason: 'Feeling unwell today')), throwsA(isA<UnexpectedResponseShape>()));
    });
  });

  group('leave rules: validation and hints (the server decides; hints never block)', () {
    final d1 = DateTime(2026, 11, 2), d3 = DateTime(2026, 11, 4);
    const ok = 'Family wedding out of town';
    LeaveFormInput input({StaffLeaveType? type = StaffLeaveType.annual, DateTime? from, DateTime? to, String reason = ok, bool half = false}) =>
        LeaveFormInput(type: type, from: from, to: to, reason: reason, halfDay: half);

    test('valid input has no errors', () => expect(validateLeave(input(from: d1, to: d3)), isEmpty));

    test('required fields', () {
      final e = validateLeave(input(type: null, reason: ''));
      expect(e.keys, containsAll(['type', 'from', 'to', 'reason']));
    });

    test('end before start, half day over two days, span limit', () {
      expect(validateLeave(input(from: d3, to: d1))['to'], 'The last day must be on or after the first day');
      expect(validateLeave(input(from: d1, to: d3, half: true))['to'], 'A half day is a single day');
      expect(validateLeave(input(from: d1, to: d1, half: true)), isEmpty);
      expect(validateLeave(input(from: d1, to: DateTime(2028, 1, 1)))['to'], contains('at most'));
      expect(validateLeave(input(from: d1, to: d1)), isEmpty, reason: 'one day is fine');
    });

    test('reason: >= 10 characters (web parity) and <= 500, trimmed', () {
      expect(validateLeave(input(from: d1, to: d3, reason: 'too short'))['reason'], isNotNull);
      expect(validateLeave(input(from: d1, to: d3, reason: '   short   '))['reason'], isNotNull);
      expect(validateLeave(input(from: d1, to: d3, reason: 'x' * 501))['reason'], isNotNull);
      expect(validateLeave(input(from: d1, to: d3, reason: '  ten chars!  ')), isEmpty);
    });

    test('calendar span is inclusive and DST-safe', () {
      expect(spanDays(DateTime(2026, 11, 2), DateTime(2026, 11, 4)), 3);
      expect(spanDays(DateTime(2026, 10, 24), DateTime(2026, 11, 2)), 10, reason: 'across the end of DST in many zones');
      expect(spanDays(DateTime(2026, 3, 28), DateTime(2026, 3, 30)), 3);
      expect(spanDays(d1, d1), 1);
    });

    test('hints: days text, balance warning (informational), overlap', () {
      expect(spanHint(d1, d3, halfDay: false), contains('3 calendar days'));
      expect(spanHint(d1, d1, halfDay: false), contains('1 calendar day '));
      expect(spanHint(null, null, halfDay: false), contains('The school calculates'));
      expect(spanHint(d1, d1, halfDay: true), startsWith('Half day'));
      final b = balanceOf(annualUsed: 19); // 2 left
      expect(balanceWarning(b, StaffLeaveType.annual, d1, d3, halfDay: false), contains('more than the 2 annual days'));
      expect(balanceWarning(b, StaffLeaveType.annual, d1, d1, halfDay: false), isNull);
      expect(balanceWarning(b, StaffLeaveType.annual, d1, d1, halfDay: true), isNull);
      expect(balanceWarning(b, StaffLeaveType.study, d1, d3, halfDay: false), isNull, reason: 'untracked type');
      expect(balanceWarning(balanceOf(hasPolicy: false), StaffLeaveType.annual, d1, d3, halfDay: false), isNull, reason: 'no policy: zeros are not balances');
      expect(balanceWarning(null, StaffLeaveType.annual, d1, d3, halfDay: false), isNull);
      final hist = [leaveRow('a', status: 'pending', from: '2026-11-03', to: '2026-11-03'), leaveRow('b', status: 'rejected', from: '2026-11-03', to: '2026-11-03'), leaveRow('c', status: 'approved', from: '2026-12-01', to: '2026-12-02')];
      expect(overlapping(hist, d1, d3).map((l) => l.id), ['a'], reason: 'a rejected request does not count, a later one does not overlap');
    });
  });
}
