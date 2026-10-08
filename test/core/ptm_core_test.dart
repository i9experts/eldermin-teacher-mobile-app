import 'package:eldermin_teacher_app/core/models/ptm/ptm_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/network/response_shape.dart';
import 'package:eldermin_teacher_app/core/services/ptm_repository.dart';
import 'package:eldermin_teacher_app/core/utils/ptm_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/fake_phase7b_repositories.dart';

void main() {
  group('models parsed from the stub fixtures (shapes copied from ptm-meeting.schema.ts)', () {
    test('the list parses; status, guardian NAME, times, points and items are typed', () {
      final rows = (fx7b('ptm_list') as List).map((e) => ParentMeeting.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      expect(rows, hasLength(8));
      expect(rows.every((m) => m.id.isNotEmpty && m.teacherId == myStaff && m.guardianName.isNotEmpty), isTrue);
      expect(rows.map((m) => m.status).toSet(), containsAll([PtmStatus.requested, PtmStatus.confirmed, PtmStatus.completed, PtmStatus.cancelled, PtmStatus.noShow]));
      final done = rows.firstWhere((m) => m.status == PtmStatus.completed);
      expect(done.actionItems, hasLength(2));
      expect(done.actionItems.map((a) => a.done), [false, true]);
      expect(done.parentAttended, isTrue);
      expect(done.meetingNotes, isNotEmpty);
      expect(done.day, isNotNull);
      final cancelled = rows.firstWhere((m) => m.status == PtmStatus.cancelled);
      expect(cancelled.cancelledReason, 'Parent is travelling');
    });

    test('guardian phone and email are never held, even if a server sent them', () {
      final m = ParentMeeting.fromJson({'_id': 'a', 'guardianName': 'Mr A', 'guardianPhone': '0300-1', 'guardianEmail': 'a@b.c', 'status': 'confirmed'});
      expect(m.guardianName, 'Mr A');
      final dump = '${m.guardianName}|${m.studentName}|${m.requestedBy}|${m.cancelledBy}|${m.meetingNotes}';
      expect(dump, isNot(contains('0300')));
      expect(dump, isNot(contains('@')));
    });

    test('unknown status is kept as unknown; blank discussion points dropped; items without an id dropped', () {
      final m = ParentMeeting.fromJson({'_id': 'a', 'status': 'rescheduled', 'discussionPoints': ['x', ' ', ''], 'actionItems': [{'description': 'no id'}, {'_id': 'i1', 'description': 'ok', 'status': 'done'}]});
      expect(m.status, PtmStatus.unknown);
      expect(m.discussionPoints, ['x']);
      expect(m.actionItems.map((a) => a.id), ['i1']);
      expect(PtmStatus.parse(null), PtmStatus.unknown);
      expect(PtmStatus.parse('no_show'), PtmStatus.noShow);
    });

    test('scheduledDate is a calendar day: the UTC components of the stored instant, whatever the device zone', () {
      final m = meeting('a', day: '2026-10-12');
      expect(m.day, DateTime(2026, 10, 12));
    });

    test('request bodies: create sends a YYYY-MM-DD, trims points; outcome keeps only non-blank items', () {
      final r = PtmCreateRequest(studentId: 's', teacherId: myStaff, day: DateTime(2026, 12, 1), startTime: '10:00', endTime: '10:30', academicYear: '2026-27', discussionPoints: [' Maths ', '', ' ']);
      expect(r.toJson(), {'studentId': 's', 'teacherId': myStaff, 'scheduledDate': '2026-12-01', 'startTime': '10:00', 'endTime': '10:30', 'academicYear': '2026-27', 'discussionPoints': ['Maths']});
      final o = PtmOutcomeRequest(parentAttended: false, meetingNotes: '  hi  ', actionItems: [
        const ActionItemDraft(description: ' Read ', assignedTo: ' Parent ', dueDay: null),
        ActionItemDraft(description: 'Sign', dueDay: DateTime(2026, 12, 3)),
        const ActionItemDraft(),
      ]);
      expect(o.toJson(), {
        'parentAttended': false,
        'meetingNotes': 'hi',
        'actionItems': [
          {'description': 'Read', 'assignedTo': 'Parent', 'status': 'pending'},
          {'description': 'Sign', 'dueDate': '2026-12-03', 'status': 'pending'},
        ],
      });
    });
  });

  group('allowed actions per status (UI gating: the server has no ownership check on confirm / cancel / action items)', () {
    // status -> what a teacher may do with HER meeting
    const table = <String, Set<PtmAction>>{
      'requested': {PtmAction.confirm, PtmAction.reschedule, PtmAction.recordOutcome, PtmAction.cancel, PtmAction.messageGuardian},
      'confirmed': {PtmAction.reschedule, PtmAction.recordOutcome, PtmAction.cancel, PtmAction.messageGuardian},
      'completed': {PtmAction.toggleActionItems, PtmAction.messageGuardian},
      'no_show': {PtmAction.toggleActionItems, PtmAction.messageGuardian},
      'cancelled': {},
      'weird': {},
    };
    for (final e in table.entries) {
      test('${e.key}: mine', () {
        final m = meeting('a', status: e.key, items: [item('i1')]);
        expect(allowedPtmActions(m, myStaff), e.value);
      });
      test('${e.key}: someone else\'s meeting -> nothing at all', () {
        final m = meeting('a', status: e.key, teacherId: otherStaff, items: [item('i1')]);
        expect(allowedPtmActions(m, myStaff), isEmpty);
      });
    }
    test('toggling items needs items; unknown/absent staff id never matches', () {
      expect(allowedPtmActions(meeting('a', status: 'completed'), myStaff), {PtmAction.messageGuardian});
      expect(allowedPtmActions(meeting('a'), null), isEmpty);
      expect(allowedPtmActions(meeting('a'), ''), isEmpty);
      expect(allowedPtmActions(meeting('a', teacherId: ''), ''), isEmpty);
    });
    test('a completed meeting can never be cancelled or re-recorded from the app (the server would allow it)', () {
      final a = allowedPtmActions(meeting('a', status: 'completed'), myStaff);
      expect(a.contains(PtmAction.cancel) || a.contains(PtmAction.recordOutcome) || a.contains(PtmAction.confirm) || a.contains(PtmAction.reschedule), isFalse);
    });
  });

  group('tabs: Upcoming / Today / Past / Cancelled with the Home agenda semantics', () {
    // "now" = Thu 8 Oct 2026 13:00 device time
    final now = DateTime(2026, 10, 8, 13, 0);
    final all = [
      meeting('up1', status: 'confirmed', day: '2026-10-10'),
      meeting('up0', status: 'requested', day: '2026-10-09', start: '09:00'),
      meeting('t_ahead', status: 'requested', day: '2026-10-08', start: '15:00', end: '15:30'),
      meeting('t_over', status: 'confirmed', day: '2026-10-08', start: '09:00', end: '09:30'),
      meeting('t_done', status: 'completed', day: '2026-10-08', start: '08:00', end: '08:30'),
      meeting('t_cancelled', status: 'cancelled', day: '2026-10-08', start: '16:00', end: '16:30'),
      meeting('p_done', status: 'completed', day: '2026-10-05'),
      meeting('p_noshow', status: 'no_show', day: '2026-09-28'),
      meeting('p_open', status: 'requested', day: '2026-10-06'),
      meeting('c_old', status: 'cancelled', day: '2026-10-07'),
      meeting('up1', status: 'confirmed', day: '2026-10-10'), // duplicate id: counted once
    ];

    test('every meeting lands in exactly one tab, in the right order', () {
      final t = buildPtmTabs(all, now);
      List<String> ids(List<ParentMeeting> l) => l.map((m) => m.id).toList();
      expect(ids(t.upcoming), ['up0', 'up1'], reason: 'soonest first');
      expect(ids(t.todayRemaining), ['t_ahead']);
      expect(ids(t.todayEarlier), ['t_done', 't_over'], reason: 'by start time; "Earlier today" = over by end time or closed');
      expect(ids(t.past), ['p_open', 'p_done', 'p_noshow'], reason: 'newest first');
      expect(ids(t.cancelled), ['t_cancelled', 'c_old'], reason: 'newest first, today included');
      final placed = [...ids(t.upcoming), ...ids(t.todayRemaining), ...ids(t.todayEarlier), ...ids(t.past), ...ids(t.cancelled)];
      expect(placed.toSet().length, placed.length);
      expect(placed.length, 10);
      expect(t.countOf(PtmTab.today), 3);
    });

    test('an open meeting whose day has passed is Past and flagged overdue; a done one is not', () {
      final t = buildPtmTabs(all, now);
      expect(t.past.map((m) => m.id), contains('p_open'));
      expect(isOverdueOpen(all.firstWhere((m) => m.id == 'p_open'), now), isTrue);
      expect(isOverdueOpen(all.firstWhere((m) => m.id == 'p_done'), now), isFalse);
      expect(isOverdueOpen(all.firstWhere((m) => m.id == 't_ahead'), now), isFalse, reason: 'today is not over yet');
    });

    test('empty input -> empty tabs', () => expect(buildPtmTabs(const [], now).isEmpty, isTrue));
  });

  group('timezone safety (run under TZ=UTC, Pacific/Auckland, America/Los_Angeles, Asia/Karachi)', () {
    test('a picked day is written as its own YYYY-MM-DD and read back as the same calendar day in every zone', () {
      for (final d in [DateTime(2026, 10, 8), DateTime(2026, 10, 8, 23, 59), DateTime(2026, 3, 29), DateTime(2026, 12, 31, 0, 0, 1)]) {
        final wire = PtmCreateRequest(studentId: 's', teacherId: 't', day: d, startTime: '10:00', endTime: '10:30', academicYear: 'y').toJson()['scheduledDate'] as String;
        expect(wire, '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
        final stored = ParentMeeting.fromJson({'_id': 'a', 'scheduledDate': '${wire}T00:00:00.000Z'});
        expect(stored.day, DateTime(d.year, d.month, d.day), reason: 'the UTC components of the stored midnight ARE the day');
      }
    });

    test('"today" follows the device calendar date: one instant, four zones, the expected tab is derived from the local date', () {
      final instant = DateTime.utc(2026, 10, 8, 3, 0); // 07 Oct evening in LA, 08 Oct elsewhere
      final now = instant.toLocal();
      final m = meeting('a', status: 'confirmed', day: '2026-10-08', start: '23:00', end: '23:30');
      final t = buildPtmTabs([m], now);
      final localIsOct8 = now.year == 2026 && now.month == 10 && now.day == 8;
      expect(t.todayCount, localIsOct8 ? 1 : 0, reason: 'local date ${now.year}-${now.month}-${now.day}');
      expect(t.upcoming.length, localIsOct8 ? 0 : 1);
      // the day AFTER, stored at midnight UTC, is never "today" even when the local clock is behind UTC (the midnight-UTC guard)
      final tomorrow = meeting('b', status: 'confirmed', day: '2026-10-09');
      expect(buildPtmTabs([tomorrow], DateTime(2026, 10, 8, 20, 0)).todayCount, 0);
      expect(buildPtmTabs([tomorrow], DateTime(2026, 10, 8, 20, 0)).upcoming.length, 1);
    });

    test('the list windows are UTC instants that cover the local and the UTC calendar day of now', () {
      for (final now in [DateTime(2026, 10, 8, 0, 5), DateTime(2026, 10, 8, 23, 55), DateTime.utc(2026, 10, 8, 3).toLocal()]) {
        final w = ptmWindows(now);
        final startOfLocalDay = DateTime(now.year, now.month, now.day).toUtc();
        final startOfUtcDay = DateTime.utc(now.year, now.month, now.day);
        expect(w.aheadFrom.isAfter(startOfLocalDay), isFalse);
        expect(w.aheadFrom.isAfter(startOfUtcDay), isFalse);
        expect(w.aheadFrom.isUtc, isTrue);
      }
    });
  });

  group('windows and validation', () {
    test('the two list windows meet without a gap or overlap', () {
      final w = ptmWindows(DateTime(2026, 10, 8, 13));
      expect(w.pastTo.isBefore(w.aheadFrom), isTrue);
      expect(w.aheadFrom.difference(w.pastTo), const Duration(milliseconds: 1));
    });

    test('times: both needed, HH:mm, end after start; reschedule of a meeting with no times may stay without', () {
      expect(validatePtmTimes('10:00', '10:30'), isEmpty);
      expect(validatePtmTimes(null, null).keys, containsAll(['start', 'end']));
      expect(validatePtmTimes('10:00', '09:59')['end'], 'The end time must be after the start time');
      expect(validatePtmTimes('10:00', '10:00')['end'], isNotNull);
      expect(validatePtmTimes('25:00', '26:00').keys, containsAll(['start', 'end']));
      expect(validatePtmTimes('9:00', '10:00')['start'], isNotNull, reason: 'the picker always sends zero-padded HH:mm');
      expect(validatePtmTimes('', '', allowBothEmpty: true), isEmpty);
      expect(validatePtmTimes('10:00', '', allowBothEmpty: true)['end'], isNotNull);
    });

    test('day: required, today or later (device calendar)', () {
      final now = DateTime(2026, 10, 8, 23, 59);
      expect(validatePtmDay(null, now), 'Choose a date');
      expect(validatePtmDay(DateTime(2026, 10, 7), now), 'Choose today or a later date');
      expect(validatePtmDay(DateTime(2026, 10, 8), now), isNull);
      expect(validatePtmDay(DateTime(2026, 10, 9), now), isNull);
    });

    test('outcome: blank items are ignored, a described one passes, an item without a description fails, limits hold', () {
      expect(validateOutcome(const PtmOutcomeRequest(parentAttended: true)), isEmpty);
      expect(validateOutcome(const PtmOutcomeRequest(parentAttended: true, actionItems: [ActionItemDraft()])), isEmpty);
      expect(validateOutcome(const PtmOutcomeRequest(parentAttended: true, actionItems: [ActionItemDraft(assignedTo: 'Parent')])).keys, ['item0']);
      expect(validateOutcome(PtmOutcomeRequest(parentAttended: true, meetingNotes: 'x' * (kPtmNotesMax + 1)))['notes'], isNotNull);
      expect(validateOutcome(PtmOutcomeRequest(parentAttended: true, actionItems: [ActionItemDraft(description: 'x' * (kPtmActionDescriptionMax + 1))])).keys, ['item0']);
    });
  });

  group('repository: what is sent and what is refused', () {
    const id = '64d000000000000000001001';
    test('request shapes', () async {
      final c = RecordingClient([]);
      final r = PtmRepository(c);
      await r.fetchMeetings(staffId: myStaff, from: DateTime.utc(2026, 10, 8, 0, 0), to: DateTime.utc(2026, 10, 9), status: 'confirmed');
      expect(c.calls.last.url, endsWith('/teaching/ptm'));
      expect(c.calls.last.query, {'teacherId': myStaff, 'from': '2026-10-08T00:00:00.000Z', 'to': '2026-10-09T00:00:00.000Z', 'status': 'confirmed'});
      await r.fetchMeetings(staffId: myStaff);
      expect(c.calls.last.query, {'teacherId': myStaff});
      c.body = [];
      await r.fetchStudentHistory('s1');
      expect(c.calls.last.url, endsWith('/teaching/ptm/student/s1/history'));

      c.body = {'_id': id, 'status': 'confirmed'};
      expect((await r.fetchMeeting(id)).id, id);
      expect(c.calls.last.url, endsWith('/teaching/ptm/$id'));
      await r.confirm(id);
      expect(c.calls.last.method, 'PATCH');
      expect(c.calls.last.url, endsWith('/teaching/ptm/$id/confirm'));
      await r.reschedule(id, day: DateTime(2026, 12, 5), startTime: '09:00', endTime: '09:20');
      expect(c.calls.last.method, 'PATCH');
      expect(c.calls.last.data, {'scheduledDate': '2026-12-05', 'startTime': '09:00', 'endTime': '09:20'});
      await r.reschedule(id, day: DateTime(2026, 12, 5));
      expect(c.calls.last.data, {'scheduledDate': '2026-12-05'}, reason: 'omitted times clear the stored ones on the server: the app only omits them when the meeting had none');
      await r.recordOutcome(id, const PtmOutcomeRequest(parentAttended: true, meetingNotes: 'ok'));
      expect(c.calls.last.url, endsWith('/$id/outcome'));
      expect(c.calls.last.data, {'parentAttended': true, 'meetingNotes': 'ok', 'actionItems': []});
      await r.setActionItem(id, 'i1', done: true);
      expect(c.calls.last.url, endsWith('/$id/action-items/i1'));
      expect(c.calls.last.data, {'status': 'done'});
      await r.setActionItem(id, 'i1', done: false);
      expect(c.calls.last.data, {'status': 'pending'});
      await r.cancel(id, '  Travelling ');
      expect(c.calls.last.url, endsWith('/$id/cancel'));
      expect(c.calls.last.data, {'reason': 'Travelling'});
      await r.create(PtmCreateRequest(studentId: 's', teacherId: myStaff, day: DateTime(2026, 12, 1), startTime: '10:00', endTime: '10:30', academicYear: '2026-27'));
      expect(c.calls.last.method, 'POST');
      expect(c.calls.last.url, endsWith('/teaching/ptm'));
    });

    test('wrong shapes are UnexpectedResponseShape, never an empty list', () async {
      final c = RecordingClient({'data': 'x'});
      final r = PtmRepository(c);
      for (final bad in <Object?>[{'meetings': []}, 'oops', null, 5, [1, 2], {'data': {}}]) {
        c.body = bad;
        await expectLater(r.fetchMeetings(staffId: myStaff), throwsA(isA<UnexpectedResponseShape>()), reason: '$bad');
        await expectLater(r.fetchStudentHistory('s'), throwsA(isA<UnexpectedResponseShape>()));
      }
      for (final bad in <Object?>[[], 'oops', null, 5]) {
        c.body = bad;
        await expectLater(r.fetchMeeting(id), throwsA(isA<UnexpectedResponseShape>()), reason: '$bad');
        await expectLater(r.confirm(id), throwsA(isA<UnexpectedResponseShape>()));
        await expectLater(r.cancel(id, 'x'), throwsA(isA<UnexpectedResponseShape>()));
      }
      c.body = {'status': 'requested'}; // no _id
      await expectLater(r.create(PtmCreateRequest(studentId: 's', teacherId: myStaff, day: DateTime(2026, 12, 1), startTime: '10:00', endTime: '10:30', academicYear: 'y')), throwsA(isA<UnexpectedResponseShape>()));
      c.body = [];
      expect(await r.fetchMeetings(staffId: myStaff), isEmpty, reason: 'a valid empty list is just empty');
    });

    test('HTTP errors keep their status', () async {
      final c = RecordingClient()..failStatus = 403;
      final r = PtmRepository(c);
      for (final status in [403, 404, 409, 500]) {
        c.failStatus = status;
        c.failMessage = 'msg $status';
        await expectLater(r.confirm(id), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', status).having((e) => e.message, 'message', 'msg $status')));
      }
    });
  });
}
