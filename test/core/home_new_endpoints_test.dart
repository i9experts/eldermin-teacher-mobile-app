import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:eldermin_teacher_app/core/models/home/messaging.dart';
import 'package:eldermin_teacher_app/core/models/home/pending_grading.dart';
import 'package:eldermin_teacher_app/core/models/home/summaries.dart';
import 'package:eldermin_teacher_app/core/models/home/timetable.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/network/base_client.dart';
import 'package:eldermin_teacher_app/core/services/home_repository.dart';
import 'package:eldermin_teacher_app/core/utils/home_time.dart';
import 'package:flutter_test/flutter_test.dart';

// Fixtures = the JSON examples of eldermin-teacher-app-docs/phase4/backend-additions.md, which the backend
// author derived from staff-teaching.service.ts pendingGrading() :58-117 and timetable() :153-225
// (plus a split-only slot, :179-182, and a null sectionName, :109 / schema). "A/B" variants :184.
dynamic fx(String n) => jsonDecode(File('test/fixtures/home/$n.json').readAsStringSync());

class _Client extends BaseClient {
  final Object? Function(String path, Map<String, dynamic>? q) handler;
  final calls = <(String, Map<String, dynamic>?)>[];
  _Client(this.handler);

  @override
  Future<Response> get(String url,
      {Map<String, dynamic>? queryParameters, bool requiresAuth = true, Map<String, String>? headers}) async {
    final path = Uri.parse(url).path.replaceFirst('/api/v1', '');
    calls.add((path, queryParameters));
    final ro = RequestOptions(path: url);
    final body = handler(path, queryParameters);
    if (body is int) {
      throw DioException(
          requestOptions: ro,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: ro, statusCode: body, data: {'statusCode': body, 'message': 'boom'}));
    }
    return Response(requestOptions: ro, statusCode: 200, data: body);
  }
}

void main() {
  group('pending-grading parsing', () {
    final p = PendingGrading.fromJson(fx('pending_grading') as Map<String, dynamic>);
    test('total, items, null section and null oldestSubmittedAt', () {
      expect(p.total, 7);
      expect(p.items, hasLength(2));
      expect(p.items[0].submittedCount, 5);
      expect(p.items[0].totalSubmissions, 28);
      expect(p.items[0].classLabel, 'Grade 5 - A');
      expect(p.items[0].oldestSubmittedAt, DateTime.utc(2026, 9, 30, 7, 12));
      expect(p.items[1].sectionName, '');
      expect(p.items[1].classLabel, 'Grade 6');
      expect(p.items[1].oldestSubmittedAt, isNull);
      expect(p.generatedAt, DateTime.utc(2026, 10, 5, 8));
    });
    test('display model trusts the server total and flags unlisted work', () {
      final h = HomeworkToGrade.fromPending(p);
      expect(h.source, GradingSource.endpoint);
      expect(h.totalUngraded, 7);
      expect(h.items.map((i) => i.ungraded), [5, 2]);
      expect(h.unlistedUngraded, 0);
      final limited = HomeworkToGrade.fromPending(PendingGrading(total: 10, items: p.items));
      expect(limited.unlistedUngraded, 3);
    });
    test('missing/odd fields do not crash; rows without an id are dropped', () {
      final q = PendingGrading.fromJson({'items': [{'assignmentId': 'x'}, {'title': 'no id'}, 'junk']});
      expect(q.total, 0);
      expect(q.items.single.assignmentId, 'x');
      expect(PendingGrading.fromJson(const {}).items, isEmpty);
    });
  });

  group('my timetable parsing', () {
    final t = MyTimetable.fromJson(fx('my_timetable_day') as Map<String, dynamic>);
    test('normal slot, A/B tags, split group, null section', () {
      expect(t.from, '2026-10-05');
      expect(t.days, hasLength(1));
      final d = t.days.single;
      expect(d.dayOfWeek, 1);
      expect(d.weekCycle, isNull); // always null: A/B parity undeterminable (U1)
      expect(d.slots, hasLength(4));
      expect(d.slots[0].weekCycle, 'both');
      expect(d.slots[0].splitGroup, isNull);
      expect(d.slots[1].weekCycle, 'A');
      expect(d.slots[1].splitGroup!.name, 'French');
      expect(d.slots[2].weekCycle, 'B');
      expect(d.slots[3].sectionName, '');
      expect(d.slots[3].classLabel, 'Grade 8');
    });
    test('periods: both -> untagged, A/B -> tagged, split label shown, never guessing the week', () {
      final periods = teacherPeriodsFromTimetable(t);
      expect(periods, hasLength(4));
      expect(periods[0].weekCycleTag, isNull);
      expect(periods[1].weekCycleTag, 'A');
      expect(periods[2].weekCycleTag, 'B');
      expect(periods[1].splitLabel, 'French');
      expect(periods[3].splitLabel, 'Group 2'); // a split-group-only slot
      expect(periods[3].room, 'Lab 2');
      expect(periods[0].startMinutes, 480);
      // Monday 5 Oct 2026: all four are "today", ordered by start time.
      final today = todayPeriods(periods, DateTime(2026, 10, 5, 8, 10));
      expect(today.map((e) => e.period.periodNo), [1, 3, 3, 5]);
      expect(today.first.phase, PeriodPhase.current);
    });
    test('empty day and unknown day index', () {
      final e = MyTimetable.fromJson({'from': '2026-10-06', 'to': '2026-10-06', 'days': [{'date': '2026-10-06', 'dayOfWeek': 2, 'weekCycle': null, 'slots': []}]});
      expect(teacherPeriodsFromTimetable(e), isEmpty);
      // dayOfWeek missing -> derived from the date string (6 Oct 2026 is a Tuesday = 2)
      final derived = MyTimetable.fromJson({'days': [{'date': '2026-10-06', 'slots': [{'periodNo': 1, 'startTime': '08:00', 'endTime': '08:40'}]}]});
      expect(teacherPeriodsFromTimetable(derived).single.day, 2);
      expect(teacherPeriodsFromTimetable(MyTimetable.fromJson({'days': [{'slots': [{}]}]})), isEmpty);
    });
  });

  group('repository requests', () {
    test('getMyTimetable sends date= for one day and from/to for a range (calendar dates, no time)', () async {
      final c = _Client((_, __) => fx('my_timetable_day'));
      final r = HomeRepository(c);
      await r.getMyTimetable(DateTime(2026, 10, 5, 23, 30), DateTime(2026, 10, 5, 1));
      expect(c.calls.last.$1, '/staff-portal/timetable');
      expect(c.calls.last.$2, {'date': '2026-10-05'});
      await r.getMyTimetable(DateTime(2026, 10, 5), DateTime(2026, 10, 11));
      expect(c.calls.last.$2, {'from': '2026-10-05', 'to': '2026-10-11'});
    });

    test('getPendingGrading parses and passes limit only when given', () async {
      final c = _Client((_, __) => fx('pending_grading'));
      final r = HomeRepository(c);
      expect((await r.getPendingGrading()).total, 7);
      expect(c.calls.last.$1, '/staff-portal/homework/pending-grading');
      expect(c.calls.last.$2, <String, dynamic>{});
      await r.getPendingGrading(limit: 20);
      expect(c.calls.last.$2, {'limit': 20});
    });

    test('404 from the new endpoints surfaces as ApiException(404)', () async {
      final r = HomeRepository(_Client((_, __) => 404));
      for (final f in [() => r.getPendingGrading(), () => r.getMyTimetable(DateTime(2026, 10, 5), DateTime(2026, 10, 5))]) {
        await expectLater(f(), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)));
      }
    });

    test('fetchPtmsInRange sends teacherId + ISO UTC from/to to /teaching/ptm', () async {
      final c = _Client((_, __) => [
            {'_id': 'p1', 'teacherId': 'me', 'scheduledDate': '2026-10-05T00:00:00.000Z', 'startTime': '08:00', 'endTime': '08:20', 'status': 'completed'}
          ]);
      final list = await HomeRepository(c).fetchPtmsInRange('me', from: DateTime.utc(2026, 10, 5), to: DateTime.utc(2026, 10, 5, 23, 59, 59, 999));
      expect(c.calls.last.$1, '/teaching/ptm');
      expect(c.calls.last.$2, {'teacherId': 'me', 'from': '2026-10-05T00:00:00.000Z', 'to': '2026-10-05T23:59:59.999Z'});
      expect(list.single.status, 'completed');
    });

    test('threads are requested with status=open (staff-portal.service.ts:220)', () async {
      final c = _Client((_, __) => {'items': [], 'unreadCount': 0});
      await HomeRepository(c).fetchOpenThreads();
      expect(c.calls.last.$1, '/staff-portal/threads');
      expect(c.calls.last.$2, {'status': 'open'});
    });
  });

  test('unread messages count open threads only, even if a closed row slipped through', () {
    final r = ThreadsResult.fromJson({
      'items': [
        {'_id': 'a', 'status': 'open', 'staffHasUnread': true},
        {'_id': 'b', 'status': 'closed', 'staffHasUnread': true},
        {'_id': 'c', 'status': 'open', 'staffHasUnread': false},
      ],
    });
    expect(r.unreadCount, 1);
    expect(r.unreadThreads.single.id, 'a');
    // The 'N+' cap note stays tied to the 100-row server limit.
    final cap = ThreadsResult(items: List.generate(100, (i) => MessageThread(id: '$i', staffHasUnread: true, status: 'open')));
    expect(cap.mayUndercount, isTrue);
    expect(cap.unreadCount, 100);
  });
}
