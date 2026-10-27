// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';
import 'package:eldermin_teacher_app/app/modules/attendance/controllers/attendance_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/models/section_state.dart';
import 'package:eldermin_teacher_app/core/models/classroom/attendance_models.dart';
import 'package:eldermin_teacher_app/core/models/classroom/student_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_classroom_repositories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeStudentsRepository students;
  late FakeAttendanceRepository attendance;
  late DateTime now;
  late List<StudentSummary> roster;

  // Stored instant for "day" on a UTC server (midnight UTC).
  DateTime stored(DateTime day) => DateTime.utc(day.year, day.month, day.day);

  setUp(() {
    Get.reset();
    Get.testMode = true;
    students = FakeStudentsRepository();
    attendance = FakeAttendanceRepository();
    now = DateTime(2026, 10, 5, 9, 0); // Monday
    roster = [for (var i = 1; i <= 4; i++) student(i)];
    students.roster = (_) async => roster;
  });
  tearDown(Get.reset);

  Future<AttendanceController> make({bool classTeacher = true, List<String>? permissions, List<Map<String, Object?>>? assignments, String token = 'tok'}) async {
    final h = await signedIn(classTeacher: classTeacher, permissions: permissions, classTeacherAssignments: assignments, token: token);
    return AttendanceController(students: students, attendance: attendance, auth: h.auth, permissions: h.perms, clock: () => now);
  }

  group('access gating', () {
    test('only class teachers are allowed; others never load anything', () async {
      final c = await make(classTeacher: false);
      expect(c.allowed, isFalse);
      await c.load();
      expect(students.calls, isEmpty);
      expect(attendance.rangeCalls, isEmpty);
    });

    test('class teacher without students:view is not allowed (UI gating)', () async {
      final c = await make(permissions: ['teaching:view']);
      expect(c.allowed, isFalse);
    });

    test('class teacher: roster for MY class from /me, class strings used for the day query', () async {
      final c = await make();
      expect(c.allowed, isTrue);
      await c.load();
      expect(students.calls, contains('roster:Grade 5 - A'));
      final call = attendance.rangeCalls.single;
      expect((call.grade, call.section), ('Grade 5', 'A'));
      expect(call.first, DateTime(2026, 10, 5));
      expect(call.last, DateTime(2026, 10, 5));
      expect(c.roster.value.status, SectionStatus.data);
    });
  });

  group('load', () {
    test('existing records pre-fill marks; unmarked count; not dirty; nothing to submit yet', () async {
      attendance.range = (_, __, ___, ____) async => [record(roster[0], stored(DateTime(2026, 10, 5)), 'present'), record(roster[1], stored(DateTime(2026, 10, 5)), 'late')];
      final c = await make();
      await c.load();
      expect(c.marks[roster[0].id], AttendanceStatus.present);
      expect(c.marks[roster[1].id], AttendanceStatus.late);
      expect(c.unmarked.map((s) => s.id), [roster[2].id, roster[3].id]);
      expect(c.markedCount, 2);
      expect(c.dirty, isFalse);
      expect(c.canSubmit, isFalse);
      expect(c.hasServerRecords, isTrue);
    });

    test('records of other days / students outside the roster are ignored', () async {
      final stranger = student(99, section: 'B');
      attendance.range = (_, __, ___, ____) async => [
            record(roster[0], stored(DateTime(2026, 10, 4)), 'absent'), // yesterday
            record(stranger, stored(DateTime(2026, 10, 5)), 'absent'), // not in my roster
            record(roster[1], stored(DateTime(2026, 10, 5)), 'present'),
          ];
      final c = await make();
      await c.load();
      expect(c.marks.keys, [roster[1].id]);
    });

    test('a server in UTC+5 stores local midnight (previous day 19:00Z): still found for that calendar day', () async {
      attendance.range = (_, __, ___, ____) async => [record(roster[0], DateTime.utc(2026, 10, 4, 19), 'present')];
      final c = await make();
      await c.load();
      expect(c.marks[roster[0].id], AttendanceStatus.present);
    });

    test('a record whose status is outside the enum is shown as a hint and counts as NOT marked', () async {
      attendance.range = (_, __, ___, ____) async => [record(roster[0], stored(DateTime(2026, 10, 5)), 'holiday')];
      final c = await make();
      await c.load();
      expect(c.marks.containsKey(roster[0].id), isFalse);
      expect(c.legacyStatus[roster[0].id], 'holiday');
      expect(c.unmarked, hasLength(4));
    });

    test('403 -> forbidden, error -> error + retry works, empty roster -> empty', () async {
      var c = await make();
      students.roster = (_) async => throw ApiException('Forbidden', statusCode: 403);
      await c.load();
      expect(c.roster.value.status, SectionStatus.forbidden);
      students.roster = (_) async => throw ApiException('boom', statusCode: 500);
      await c.load();
      expect(c.roster.value.status, SectionStatus.error);
      students.roster = (_) async => roster;
      await c.retry();
      expect(c.roster.value.status, SectionStatus.data);
      students.roster = (_) async => [];
      await c.load();
      expect(c.roster.value.status, SectionStatus.empty);
    });

    test('an attendance-list failure fails the whole screen (never lets you overwrite blindly)', () async {
      attendance.range = (_, __, ___, ____) async => throw ApiException('x', statusCode: 500);
      final c = await make();
      await c.load();
      expect(c.roster.value.status, SectionStatus.error);
    });

    test('grades-sections failure is non-fatal', () async {
      students.grades = () async => throw ApiException('x', statusCode: 403);
      final c = await make();
      await c.load();
      expect(c.roster.value.status, SectionStatus.data);
    });
  });

  group('explicit status gating, mark all, edit', () {
    test('submit with unmarked students is BLOCKED: nothing is sent, nobody becomes absent, rows flag', () async {
      final c = await make();
      await c.load();
      c.setStatus(roster[0].id, AttendanceStatus.present);
      final r = await c.submit();
      expect(r, isA<SubmitBlocked>().having((b) => b.notMarked, 'notMarked', 3));
      expect(attendance.submitted, isEmpty);
      expect(c.showUnmarked.value, isTrue);
      expect(c.canSubmit, isFalse);
      expect(c.marks.length, 1);
    });

    test('markRemainingPresent only fills students without a status; explicit choices survive', () async {
      final c = await make();
      await c.load();
      c.setStatus(roster[1].id, AttendanceStatus.absent);
      c.setStatus(roster[2].id, AttendanceStatus.late);
      c.markRemainingPresent();
      expect(c.marks[roster[0].id], AttendanceStatus.present);
      expect(c.marks[roster[1].id], AttendanceStatus.absent);
      expect(c.marks[roster[2].id], AttendanceStatus.late);
      expect(c.marks[roster[3].id], AttendanceStatus.present);
      expect(c.allMarked, isTrue);
      expect(c.canSubmit, isTrue);
    });

    test('complete submit sends one explicit record per student: class strings, noon-UTC date, enum values, academic year', () async {
      final c = await make();
      await c.load();
      c.markRemainingPresent();
      c.setStatus(roster[1].id, AttendanceStatus.excused);
      c.setStatus(roster[3].id, AttendanceStatus.halfDay);
      final r = await c.submit();
      expect(r, isA<SubmitSaved>());
      final sent = attendance.submitted.single;
      expect(sent, hasLength(4));
      expect(sent.map((w) => w.status.wire), ['present', 'excused', 'present', 'half_day']);
      expect(sent.every((w) => w.grade == 'Grade 5' && w.section == 'A'), isTrue);
      expect(sent.first.toJson()['date'], '2026-10-05T12:00:00.000Z');
      expect(attendance.years.single, '2026-27');
      expect((r as SubmitSaved).counts.excused, 1);
      expect(c.dirty, isFalse);
      expect(c.lastSaved.value, now);
      expect(c.savedMarks, c.marks);
    });

    test('students stored with other grade strings ("5"/"a") are still sent with the class teacher strings', () async {
      roster = [student(1, grade: '5', section: 'a'), student(2)];
      students.roster = (_) async => roster;
      final c = await make();
      await c.load();
      c.markRemainingPresent();
      await c.submit();
      expect(attendance.submitted.single.map((w) => (w.grade, w.section)).toSet(), {('Grade 5', 'A')});
    });

    test('editing a same-day record: dirty after a change, submit re-sends everyone, then clean again', () async {
      attendance.range = (_, __, ___, ____) async => [for (final s in roster) record(s, stored(DateTime(2026, 10, 5)), 'present')];
      final c = await make();
      await c.load();
      expect(c.allMarked, isTrue);
      expect(c.dirty, isFalse);
      expect(c.canSubmit, isFalse);
      c.setStatus(roster[2].id, AttendanceStatus.absent);
      expect(c.dirty, isTrue);
      expect(c.canSubmit, isTrue);
      c.setStatus(roster[2].id, AttendanceStatus.present); // changed back: no longer dirty
      expect(c.dirty, isFalse);
      c.setStatus(roster[2].id, AttendanceStatus.absent);
      await c.submit();
      expect(attendance.submitted.single, hasLength(4));
      expect(attendance.submitted.single[2].status, AttendanceStatus.absent);
      expect(c.dirty, isFalse);
      expect(c.savedMarks[roster[2].id], AttendanceStatus.absent);
    });
  });

  group('failures keep the marked state; retry', () {
    Future<AttendanceController> ready() async {
      final c = await make();
      await c.load();
      c.markRemainingPresent();
      c.setStatus(roster[1].id, AttendanceStatus.absent);
      return c;
    }

    for (final tc in <(String, ApiException, SubmitFailureKind)>[
      ('offline', ApiException("Couldn't reach Eldermin. Check your internet connection."), SubmitFailureKind.offline),
      ('403', ApiException('Forbidden resource', statusCode: 403), SubmitFailureKind.forbidden),
      ('409', ApiException('Locked', statusCode: 409), SubmitFailureKind.conflict),
      ('400', ApiException('records.0.status must be one of the following values: present, absent, late, excused, half_day', statusCode: 400), SubmitFailureKind.validation),
      ('500', ApiException('Internal server error', statusCode: 500), SubmitFailureKind.server),
    ]) {
      test('${tc.$1}: marks untouched, failure kind ${tc.$3.name}, then a retry succeeds', () async {
        final c = await ready();
        final before = Map.of(c.marks);
        attendance.onSubmit = (_, __) async => throw tc.$2;
        final r = await c.submit();
        expect(r, isA<SubmitFailed>().having((f) => f.failure.kind, 'kind', tc.$3));
        expect(c.marks, before);
        expect(c.savedMarks, isEmpty);
        expect(c.dirty, isTrue);
        expect(c.submitting.value, isFalse);
        expect(c.submitFailure.value!.message, isNotEmpty);
        if (tc.$3 == SubmitFailureKind.offline) expect(c.submitFailure.value!.message, contains('marks are kept'));
        if (tc.$3 == SubmitFailureKind.forbidden) expect(c.submitFailure.value!.message, contains('Forbidden resource'));
        attendance.onSubmit = (_, __) async {};
        final again = await c.submit();
        expect(again, isA<SubmitSaved>());
        expect(c.submitFailure.value, isNull);
        expect(c.dirty, isFalse);
        expect(attendance.submitted, hasLength(2));
        expect(attendance.submitted.last.map((w) => w.status), attendance.submitted.first.map((w) => w.status));
      });
    }

    test('403 "class teacher of your own assigned class only" maps to the staleClass kind and blocks that class until re-login', () async {
      final c = await ready();
      attendance.onSubmit = (_, __) async => throw ApiException('Access denied. You are the class teacher of your own assigned class only.', statusCode: 403);
      final r = await c.submit();
      expect(r, isA<SubmitFailed>().having((f) => f.failure.kind, 'kind', SubmitFailureKind.staleClass));
      expect(c.classStale, isTrue);
      expect(c.canSubmit, isFalse);
      expect(c.marks, isNotEmpty); // marks untouched
      expect(c.submitFailure.value, isNull); // the sign-out banner replaces the generic error
      expect(await c.submit(), isA<SubmitIgnored>());
    });

    test('changing a mark clears the failure banner; the marks are still there', () async {
      final c = await ready();
      attendance.onSubmit = (_, __) async => throw ApiException('x', statusCode: 500);
      await c.submit();
      expect(c.submitFailure.value, isNotNull);
      c.setStatus(roster[0].id, AttendanceStatus.late);
      expect(c.submitFailure.value, isNull);
    });

    test('DOUBLE SUBMIT protection: a second call while saving sends nothing', () async {
      final c = await ready();
      final gate = Completer<void>();
      attendance.onSubmit = (_, __) => gate.future;
      final first = c.submit();
      await Future<void>.delayed(Duration.zero);
      expect(c.submitting.value, isTrue);
      final second = await c.submit();
      expect(second, isA<SubmitIgnored>());
      expect(c.canSubmit, isFalse);
      c.setStatus(roster[0].id, AttendanceStatus.late); // taps are ignored while saving
      expect(c.marks[roster[0].id], AttendanceStatus.present);
      gate.complete();
      expect(await first, isA<SubmitSaved>());
      expect(attendance.submitted, hasLength(1));
      expect(c.submitting.value, isFalse);
    });
  });

  group('days and the edit window', () {
    test('today and the previous $kAttendanceEditWindowDays days are editable; older and future are not', () async {
      final c = await make();
      expect(c.canEditDay(DateTime(2026, 10, 5)), isTrue);
      expect(c.canEditDay(DateTime(2026, 9, 28)), isTrue); // -7
      expect(c.canEditDay(DateTime(2026, 9, 27)), isFalse); // -8
      expect(c.canEditDay(DateTime(2026, 10, 6)), isFalse); // tomorrow
      expect(c.earliestEditable, DateTime(2026, 9, 28));
    });

    test('a read-only day ignores marks and submit', () async {
      final c = await make();
      await c.load();
      await c.openDay(DateTime(2026, 9, 1));
      expect(c.editable, isFalse);
      c.setStatus(roster[0].id, AttendanceStatus.present);
      c.markRemainingPresent();
      expect(c.marks, isEmpty);
      expect(await c.submit(), isA<SubmitIgnored>());
      expect(attendance.submitted, isEmpty);
    });

    test('openDay refuses to leave unsaved marks unless discard is true; then loads that day', () async {
      final c = await make();
      await c.load();
      c.markRemainingPresent();
      expect(await c.openDay(DateTime(2026, 10, 3)), isFalse);
      expect(c.day.value, DateTime(2026, 10, 5));
      expect(c.marks, hasLength(4));
      attendance.range = (_, __, first, ___) async => [record(roster[0], stored(first), 'late')];
      expect(await c.openDay(DateTime(2026, 10, 3), discard: true), isTrue);
      expect(c.day.value, DateTime(2026, 10, 3));
      expect(c.marks.keys, [roster[0].id]);
      expect(c.marks[roster[0].id], AttendanceStatus.late);
      expect(attendance.rangeCalls.last.first, DateTime(2026, 10, 3));
    });

    test('a stale day response never overwrites a newer selection', () async {
      final c = await make();
      await c.load();
      final slow = Completer<List<AttendanceRecord>>();
      attendance.range = (_, __, first, ___) => first.day == 2 ? slow.future : Future.value([record(roster[1], stored(first), 'absent')]);
      final a = c.openDay(DateTime(2026, 10, 2));
      await Future<void>.delayed(Duration.zero);
      await c.openDay(DateTime(2026, 10, 3));
      slow.complete([record(roster[0], stored(DateTime(2026, 10, 2)), 'present')]);
      await a;
      expect(c.day.value, DateTime(2026, 10, 3));
      expect(c.marks.keys, [roster[1].id]);
    });

    test('midnight edge: a wall clock just after local midnight is the NEW day', () async {
      now = DateTime(2026, 10, 6, 0, 1);
      final c = await make();
      expect(c.today, DateTime(2026, 10, 6));
      await c.load();
      expect(attendance.rangeCalls.single.first, DateTime(2026, 10, 6));
    });
  });

  test('academic year header: majority of the roster, none when unknown', () async {
    roster = [student(1, year: '2026-27'), student(2, year: '2026-27'), student(3, year: '2025-26'), student(4, year: null)];
    students.roster = (_) async => roster;
    var c = await make();
    await c.load();
    expect(c.academicYear, '2026-27');
    roster = [student(1, year: null)];
    c = await make();
    await c.load();
    expect(c.academicYear, isNull);
  });

  // ── Phase 9 hotfix D13: the school's attendance mode ─────────────────────────────────────────────
  // The web (AttendanceTab.tsx) reads GET /teaching/attendance-settings; in a subject-wise school it shows a subject
  // picker (first subject selected), reads the day with `subject`, and sends `subject: <name>` on every record.
  group('attendance mode (daily vs subject-wise)', () {
    DateTime d5() => stored(DateTime(2026, 10, 5));

    test('DAILY school (the default): no subject list is fetched, nothing is filtered, no `subject` is sent: unchanged behaviour', () async {
      final c = await make();
      await c.load();
      expect(attendance.modeCalls, 1);
      expect(attendance.subjectCalls, 0);
      expect(c.isSubjectWise, isFalse);
      expect(c.selectedSubject.value, isNull);
      expect(attendance.rangeCalls.single.subject, isNull);
      c.markRemainingPresent();
      expect((await c.submit()), isA<SubmitSaved>());
      final sent = attendance.submitted.single;
      expect(sent, hasLength(4));
      for (final w in sent) {
        expect(w.subject, isNull);
        expect(w.toJson().containsKey('subject'), isFalse);
      }
    });

    test('the mode cannot be read (server error): error state, roster not requested, nothing can be saved, never a guess (404/501 -> daily is the repository\'s job, tested there)', () async {
      attendance.mode = () async => throw ApiException('boom', statusCode: 500);
      final c = await make();
      await c.load();
      expect(c.roster.value.status, SectionStatus.error);
      expect(attendance.submitted, isEmpty);
      expect(students.calls, isEmpty);
    });

    test('mode failure: Retry works once the server answers', () async {
      var fail = true;
      attendance.mode = () async => fail ? throw ApiException('offline') : AttendanceMode.daily;
      final c = await make();
      await c.load();
      expect(c.roster.value.status, SectionStatus.error);
      fail = false;
      await c.retry();
      expect(c.roster.value.status, SectionStatus.data);
    });

    test('SUBJECT-WISE: subjects load, the FIRST is selected (as on the web), the day is read for that subject', () async {
      attendance.mode = () async => AttendanceMode.subjectWise;
      attendance.subjectNames = () async => ['English', 'Maths', 'Science'];
      final c = await make();
      await c.load();
      expect(c.isSubjectWise, isTrue);
      expect(c.subjects, ['English', 'Maths', 'Science']);
      expect(c.selectedSubject.value, 'English');
      expect(attendance.rangeCalls.single.subject, 'English');
    });

    test('SUBJECT-WISE submit: every record carries the selected subject (exactly the web body); marks are per subject', () async {
      attendance.mode = () async => AttendanceMode.subjectWise;
      attendance.subjectNames = () async => ['English', 'Maths'];
      final c = await make();
      await c.load();
      c.markRemainingPresent();
      expect(await c.submit(), isA<SubmitSaved>());
      for (final w in attendance.submitted.single) {
        expect(w.subject, 'English');
        expect(w.toJson()['subject'], 'English');
      }
      // switching subject reads THAT subject's records, and the next save carries it
      attendance.range = (_, __, ___, ____) async => [];
      expect(await c.selectSubject('Maths'), isTrue);
      expect(attendance.rangeCalls.last.subject, 'Maths');
      expect(c.marks, isEmpty);
      c.markRemainingPresent();
      await c.submit();
      expect(attendance.submitted.last.every((w) => w.subject == 'Maths'), isTrue);
    });

    test('SUBJECT-WISE: the existing marks of the selected subject prefill; another subject starts empty', () async {
      attendance.mode = () async => AttendanceMode.subjectWise;
      attendance.subjectNames = () async => ['English', 'Maths'];
      attendance.range = (_, __, ___, ____) async => attendance.rangeCalls.last.subject == 'English' ? [record(roster[0], d5(), 'late')] : [];
      final c = await make();
      await c.load();
      expect(c.marks[roster[0].id], AttendanceStatus.late);
      await c.selectSubject('Maths');
      expect(c.marks, isEmpty);
      expect(c.hasServerRecords, isFalse);
    });

    test('changing subject with unsaved marks is refused until the teacher agrees (discard)', () async {
      attendance.mode = () async => AttendanceMode.subjectWise;
      attendance.subjectNames = () async => ['English', 'Maths'];
      final c = await make();
      await c.load();
      c.setStatus(roster[0].id, AttendanceStatus.absent);
      expect(c.dirty, isTrue);
      expect(await c.selectSubject('Maths'), isFalse);
      expect(c.selectedSubject.value, 'English');
      expect(c.marks[roster[0].id], AttendanceStatus.absent);
      expect(await c.selectSubject('Maths', discard: true), isTrue);
      expect(c.selectedSubject.value, 'Maths');
      expect(c.marks, isEmpty);
    });

    test('changing the DAY keeps the subject and reads that day for it', () async {
      attendance.mode = () async => AttendanceMode.subjectWise;
      attendance.subjectNames = () async => ['English', 'Maths'];
      final c = await make();
      await c.load();
      await c.selectSubject('Maths');
      await c.openDay(DateTime(2026, 10, 3));
      expect(attendance.rangeCalls.last.subject, 'Maths');
      expect(attendance.rangeCalls.last.first, DateTime(2026, 10, 3));
    });

    test('SUBJECT-WISE with NO subjects set up: nothing is read or saved (like the web, Save needs a subject)', () async {
      attendance.mode = () async => AttendanceMode.subjectWise;
      attendance.subjectNames = () async => [];
      final c = await make();
      await c.load();
      expect(c.needsSubject, isTrue);
      expect(attendance.rangeCalls, isEmpty);
      c.markRemainingPresent();
      expect(c.canSubmit, isFalse);
      expect(await c.submit(), isA<SubmitIgnored>());
      expect(attendance.submitted, isEmpty);
    });

    test('an unknown subject name is ignored; a daily school ignores selectSubject', () async {
      attendance.mode = () async => AttendanceMode.subjectWise;
      attendance.subjectNames = () async => ['English'];
      var c = await make();
      await c.load();
      expect(await c.selectSubject('Chemistry'), isFalse);
      expect(c.selectedSubject.value, 'English');
      attendance.mode = () async => AttendanceMode.daily;
      c = await make();
      await c.load();
      expect(await c.selectSubject('English'), isFalse);
    });

    test('the school switching from subject-wise back to daily on the next load clears the subject (no stale `subject` is sent)', () async {
      attendance.mode = () async => AttendanceMode.subjectWise;
      attendance.subjectNames = () async => ['English'];
      final c = await make();
      await c.load();
      expect(c.selectedSubject.value, 'English');
      attendance.mode = () async => AttendanceMode.daily;
      await c.load();
      expect(c.selectedSubject.value, isNull);
      expect(c.subjects, isEmpty);
      expect(attendance.rangeCalls.last.subject, isNull);
      c.markRemainingPresent();
      await c.submit();
      expect(attendance.submitted.last.every((w) => w.subject == null && !w.toJson().containsKey('subject')), isTrue);
    });

    test('a failed subject list is an error state with Retry (not a silent daily save)', () async {
      attendance.mode = () async => AttendanceMode.subjectWise;
      attendance.subjectNames = () async => throw ApiException('boom', statusCode: 500);
      final c = await make();
      await c.load();
      expect(c.roster.value.status, SectionStatus.error);
      expect(attendance.submitted, isEmpty);
    });
  });

  group('multi-section class teacher', () {
    final twoSections = [
      {'gradeId': 'g5', 'gradeName': 'Grade 5', 'sectionId': 's1', 'sectionName': 'A', 'name': 'Grade 5 - A'},
      {'gradeId': 'g5', 'gradeName': 'Grade 5', 'sectionId': 's2', 'sectionName': 'B', 'name': 'Grade 5 - B'},
    ];
    final both = classTeacherJwt([(grade: 'Grade 5', section: 'A'), (grade: 'Grade 5', section: 'B')]);
    final onlyA = classTeacherJwt([(grade: 'Grade 5', section: 'A')]);

    test('classes lists every section, first selected by default; single-class teacher has no picker', () async {
      final c = await make(assignments: twoSections, token: both);
      expect([for (final x in c.classes) x.label], ['Grade 5 - A', 'Grade 5 - B']);
      expect(c.hasPicker, isTrue);
      await c.load();
      expect(c.selectedClass.value!.label, 'Grade 5 - A');
      final single = await make();
      expect(single.classes, hasLength(1));
      expect(single.hasPicker, isFalse);
    });

    test('picking a class reloads roster+day for it and every write carries THAT class grade/section', () async {
      final c = await make(assignments: twoSections, token: both);
      await c.load();
      expect(await c.selectClass(c.classes[1]), isTrue);
      expect(c.selectedClass.value!.label, 'Grade 5 - B');
      expect(students.calls.last, 'roster:Grade 5 - B');
      expect((attendance.rangeCalls.last.grade, attendance.rangeCalls.last.section), ('Grade 5', 'B'));
      c.markRemainingPresent();
      await c.submit();
      expect(attendance.submitted.single.map((w) => (w.grade, w.section)).toSet(), {('Grade 5', 'B')});
    });

    test('selection survives a controller rebuild in the same session (kept on AuthController, not on disk)', () async {
      final h = await signedIn(classTeacher: true, classTeacherAssignments: twoSections, token: both);
      AttendanceController mk() => AttendanceController(students: students, attendance: attendance, auth: h.auth, permissions: h.perms, clock: () => now);
      final a = mk();
      await a.load();
      await a.selectClass(a.classes[1]);
      final b = mk();
      await b.load();
      expect(b.selectedClass.value!.label, 'Grade 5 - B');
    });

    test('switching class with unsaved marks needs discard; the marks of the old class are then dropped', () async {
      final c = await make(assignments: twoSections, token: both);
      await c.load();
      c.setStatus(roster[0].id, AttendanceStatus.absent);
      expect(await c.selectClass(c.classes[1]), isFalse);
      expect(c.selectedClass.value!.label, 'Grade 5 - A');
      expect(c.marks, isNotEmpty);
      expect(await c.selectClass(c.classes[1], discard: true), isTrue);
      expect(c.selectedClass.value!.label, 'Grade 5 - B');
      expect(c.marks, isEmpty);
    });

    test('a class missing from the token is blocked; the class the token covers still submits', () async {
      final c = await make(assignments: twoSections, token: onlyA);
      await c.load();
      expect(c.classStale, isFalse);
      c.markRemainingPresent();
      expect(await c.submit(), isA<SubmitSaved>());
      await c.selectClass(c.classes[1]);
      expect(c.classStale, isTrue);
      c.markRemainingPresent();
      expect(c.canSubmit, isFalse);
      expect(await c.submit(), isA<SubmitIgnored>());
      expect(attendance.submitted, hasLength(1)); // only class A was ever sent
      await c.selectClass(c.classes[0], discard: true);
      expect(c.classStale, isFalse);
    });

    test('a section assigned AFTER sign-in turns stale on the next /me refresh (and the banner state clears on logout)', () async {
      final h = await signedIn(classTeacher: true, classTeacherAssignments: [twoSections[0]], token: onlyA);
      expect(h.auth.reauthRequired, isFalse);
      h.api.classTeacherAssignments = twoSections;
      await h.auth.refreshProfile(force: true);
      expect(h.auth.staleClassKeys.toList(), ['5|b']);
      await h.auth.logout();
      expect(h.auth.staleClassKeys, isEmpty);
      expect(h.auth.attendanceClassKey.value, isNull);
    });

    test('a token with NO class claims never prompts (the backend is unrestricted then)', () async {
      final c = await make(assignments: twoSections, token: fakeJwt({'sub': 'u'}));
      expect(c.auth.reauthRequired, isFalse);
      await c.load();
      await c.selectClass(c.classes[1]);
      c.markRemainingPresent();
      expect(await c.submit(), isA<SubmitSaved>());
    });
  });
}
