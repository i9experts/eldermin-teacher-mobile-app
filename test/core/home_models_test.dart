import 'dart:convert';
import 'dart:io';
import 'package:eldermin_teacher_app/core/models/home/class_snapshot.dart';
import 'package:eldermin_teacher_app/core/models/home/messaging.dart';
import 'package:eldermin_teacher_app/core/models/home/summaries.dart';
import 'package:eldermin_teacher_app/core/models/home/teaching.dart';
import 'package:eldermin_teacher_app/core/models/home/timetable.dart';
import 'package:eldermin_teacher_app/core/models/json_helpers.dart';
import 'package:eldermin_teacher_app/core/utils/home_time.dart';
import 'package:flutter_test/flutter_test.dart';

// Fixtures are the stub's exact response bodies (tool/dev/dump_home_fixtures.py), which mirror
// eldermin-teacher-app-docs/phase4/home-endpoint-shapes.md.
dynamic fx(String name) => jsonDecode(File('test/fixtures/home/$name.json').readAsStringSync());
List<Map<String, dynamic>> fxList(String name) => asJsonMapList(fx(name));

void main() {
  const teacher = '64a0000000000000000000a1';
  const colleague = '64a0000000000000000000a9';

  test('readDate tolerates ISO, extended JSON, epoch, junk', () {
    expect(readDate('2026-10-05T00:00:00.000Z'), DateTime.utc(2026, 10, 5));
    expect(readDate({r'$date': '2026-10-05T00:00:00.000Z'}), DateTime.utc(2026, 10, 5));
    expect(readDate(0)?.millisecondsSinceEpoch, 0);
    expect(readDate('not a date'), isNull);
    expect(readDate(''), isNull);
    expect(readDate(null), isNull);
  });

  group('timetable', () {
    final docs = fxList('timetable').map(TimetableDoc.fromJson).toList();
    test('parses whole-class docs', () {
      expect(docs, hasLength(2));
      expect(docs[0].classLabel, 'Grade 5 - A');
      expect(docs[0].weekCycleEnabled, isFalse);
      expect(docs[0].cycleAnchor, isNull);
      expect(docs[1].weekCycleEnabled, isTrue);
      expect(docs[1].cycleAnchor, isNotNull);
      final split = docs[0].periods.firstWhere((p) => p.splitGroups.isNotEmpty);
      expect(split.teacherId, '');
      expect(split.splitGroupOf(teacher)?.roomNo, 'Lab 1');
    });
    test('contains other teachers; filtering keeps only mine', () {
      expect(docs[0].periods.any((p) => p.teacherId == colleague), isTrue);
      final mine = teacherPeriodsOf(docs, teacher);
      expect(mine, isNotEmpty);
      // The colleague's English period (09:00) must not be there.
      expect(mine.where((p) => p.subject == 'English'), isEmpty);
      // Split lab appears with my group's room.
      expect(mine.any((p) => p.splitLabel == 'Group 1' && p.room == 'Lab 1'), isTrue);
      // A/B periods carry the cycle tag.
      expect(mine.where((p) => p.weekCycleTag != null).map((p) => p.weekCycleTag).toSet(), {'A', 'B'});
    });
    test('missing optional fields do not crash', () {
      final d = TimetableDoc.fromJson({'_id': 'x', 'periods': [{'day': 1}, 'junk', {}]});
      expect(d.periods, hasLength(2));
      expect(d.periods.first.weekCycle, 'both');
    });
  });

  test('roster + attendance meta.total', () {
    expect(RosterCount.fromJson(asJsonMap(fx('roster'))).activeCount, 30);
    expect(attendanceTotalFromJson(asJsonMap(fx('attendance_list'))), 27);
    expect(attendanceTotalFromJson({}), 0);
  });

  test('ClassAttendanceSnapshot state/percent', () {
    ClassAttendanceSnapshot s(int roster, int marked) => ClassAttendanceSnapshot(label: 'x', grade: 'g', section: 's', rosterSize: roster, markedCount: marked);
    expect(s(30, 0).state, AttendanceMarkState.notMarked);
    expect(s(30, 12).state, AttendanceMarkState.partial);
    expect(s(30, 30).state, AttendanceMarkState.complete);
    expect(s(30, 15).percent, 50);
    expect(s(0, 0).percent, 0);
  });

  group('homework', () {
    final list = fxList('assignments').map(HomeworkAssignment.fromJson).toList();
    test('parses assignments', () {
      expect(list, hasLength(4));
      expect(list.first.title, contains('Chapter 3'));
      expect(list.first.dueDate, isNotNull);
      expect(list.first.submissionsCount, 4);
    });
    test('candidates: own, not draft/graded, with submissions, newest due first, capped', () {
      final sel = selectGradingCandidates(list, teacher);
      expect(sel.picked.map((a) => a.status), isNot(contains('draft')));
      expect(sel.picked.first.title, contains('Chapter 3'));
      expect(sel.picked, hasLength(3));
      final capped = selectGradingCandidates(list, teacher, cap: 2);
      expect(capped.picked, hasLength(2));
      expect(capped.candidates, 3);
      // somebody else's assignments are ignored client-side even if the server sent them
      expect(selectGradingCandidates(list, colleague).picked, isEmpty);
    });
    test('submissions: ungraded = submitted|late', () {
      final subs = asJsonMapList(asJsonMap(fx('submissions'))['submissions']).map(HomeworkSubmission.fromJson).toList();
      expect(subs.where((s) => s.isUngraded), hasLength(3));
    });
  });

  group('lesson plans', () {
    final plans = fxList('lesson_plans').map(LessonPlan.fromJson).toList();
    test('uses topic; rejectionReason only for rejected', () {
      final rejected = plans.firstWhere((p) => p.status == 'rejected');
      expect(rejected.topic, 'Fractions (DUMMY)');
      expect(rejected.rejectionReason, contains('assessment'));
      // submitted plan carrying a stale reason must not expose it
      final stale = plans.firstWhere((p) => p.topic.startsWith('Percentages'));
      expect(stale.status, 'submitted');
      expect(stale.rejectionReason, isNull);
    });
  });

  test('ptm', () {
    final m = fxList('ptm_upcoming').map(PtmMeeting.fromJson).toList();
    expect(m, hasLength(2));
    expect(m.first.timeRange, '10:00 - 10:20');
    expect(m.first.teacherId, teacher);
    expect(m.first.scheduledDate, isNotNull);
  });

  group('substitutions', () {
    test('covering vs covered', () {
      final cov = splitSubstitutions(fxList('fixtures_covering').map(Substitution.fromJson).toList(), teacher);
      expect(cov.covering, hasLength(1));
      expect(cov.covered, isEmpty);
      expect(cov.covering.single.originalTeacherName, contains('Other Teacher'));
      const clara = '64a0000000000000000000a2';
      final away = splitSubstitutions(fxList('fixtures_covered').map(Substitution.fromJson).toList(), clara);
      expect(away.covered, hasLength(1));
      expect(away.covering, isEmpty);
    });
    test('cancelled and open-for-others are ignored; open own period stays "covered"', () {
      Substitution s(String st, {String? orig, String? sub}) => Substitution(id: st, originalTeacherId: orig, substituteTeacherId: sub, status: st);
      final r = splitSubstitutions([
        s('cancelled', orig: teacher, sub: colleague),
        s('open', orig: teacher),
        s('open', orig: colleague, sub: teacher), // open + me as substitute is not "assigned"
      ], teacher);
      expect(r.covering, isEmpty);
      expect(r.covered, hasLength(1));
    });
  });

  test('threads: own unread count from staffHasUnread; flags the 100-row cap', () {
    final t = ThreadsResult.fromJson(asJsonMap(fx('threads')));
    expect(t.items, hasLength(3));
    expect(t.unreadCount, 2);
    expect(t.serverUnreadCount, 2);
    expect(t.mayUndercount, isFalse);
    final big = ThreadsResult(items: List.generate(100, (i) => MessageThread(id: '$i', staffHasUnread: true)));
    expect(big.mayUndercount, isTrue);
  });
}
