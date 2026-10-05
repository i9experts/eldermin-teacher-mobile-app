// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';
import 'package:eldermin_teacher_app/app/modules/behaviour/controllers/behaviour_controller.dart';
import 'package:eldermin_teacher_app/app/modules/behaviour/controllers/behaviour_log_controller.dart';
import 'package:eldermin_teacher_app/app/modules/behaviour/controllers/behaviour_student_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/models/section_state.dart';
import 'package:eldermin_teacher_app/core/models/behaviour/behaviour_models.dart';
import 'package:eldermin_teacher_app/core/models/classroom/student_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_classroom_repositories.dart';
import '../support/fake_phase5b_repositories.dart';

BehaviourRecord rec(String id,
        {String student = 'Zara',
        String sid = 'st1',
        String grade = 'Grade 5',
        String section = 'A',
        String type = 'positive',
        String by = 'Someone',
        String? byId,
        String day = '2026-10-01',
        int points = 0,
        String category = 'helping_others',
        String title = 'T'}) =>
    BehaviourRecord.fromJson({
      '_id': id, 'studentId': sid, 'studentName': student, 'grade': grade, 'section': section, 'type': type, 'category': category,
      'title': title, 'description': 'd', 'date': '${day}T00:00:00.000Z', 'points': points, 'reportedBy': by, if (byId != null) 'reportedById': byId,
    });

final fixedNow = DateTime(2026, 10, 5, 9, 30);
const cls5a = {'gradeLevel': 'Grade 5', 'sectionName': 'A', 'subjectName': 'Mathematics'};
const cls6b = {'gradeLevel': 'Grade 6', 'sectionName': 'B', 'subjectName': 'Science'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeBehaviourRepository repo;
  late FakeStudentsRepository students;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakeBehaviourRepository();
    students = FakeStudentsRepository()
      ..grades = (() async => const GradesSections(grades: ['Grade 5', '5', 'Grade 6'], sections: ['A', 'a', 'B']));
  });
  tearDown(Get.reset);


  Future<BehaviourController> makeList({List<Map<String, Object?>> assignments = const [cls5a], List<String>? permissions}) async {
    final h = await signedIn(permissions: permissions);
    h.api.assignments = assignments;
    await h.auth.refreshProfile(force: true);
    return BehaviourController(repository: repo, students: students, auth: h.auth, permissions: h.perms);
  }

  group('BehaviourController (scoping)', () {
    test('asks once per distinct raw grade of my classes, never the whole campus', () async {
      repo.gradeRecords = (g) async => [];
      final c = await makeList(assignments: [cls5a, {'gradeLevel': 'Grade 5', 'sectionName': 'B', 'subjectName': 'X'}, cls6b]);
      await c.load();
      expect(repo.calls.where((x) => x.startsWith('grade:')).toSet(), {'grade:Grade 5', 'grade:5', 'grade:Grade 6'});
      expect(repo.calls.where((x) => x.startsWith('grade:')), hasLength(3)); // 5A and 5B share the grade fetch
    });

    test('records of other classes returned by the server are dropped (5B, 7C), "5"/"a" is kept as 5A', () async {
      repo.gradeRecords = (g) async => [
            rec('mine5a', section: 'A'),
            rec('odd', grade: '5', section: 'a'),
            rec('other5b', section: 'B', student: 'Other'),
            rec('g7', grade: 'Grade 7', section: 'C'),
          ];
      final c = await makeList();
      await c.load();
      expect(c.all.map((r) => r.id), unorderedEquals(['mine5a', 'odd']));
      expect(c.all.map((r) => r.id).toSet().length, c.all.length); // de-duplicated across grade variants
    });

    test('"my entries": reportedById wins, name is the fallback for web-made records; "my classes" shows everyone', () async {
      repo.gradeRecords = (g) async => [
            rec('byid', by: 'Whatever', byId: 'u'),
            rec('byname', by: 'tess teacher'),
            rec('colleague', by: 'Omar'),
            rec('otherid', by: 'Tess Teacher', byId: 'someone-else'),
          ];
      final c = await makeList();
      await c.load();
      expect(c.visible.map((r) => r.id), unorderedEquals(['byid', 'byname']));
      expect(c.countMine(), 2);
      c.setScope(BehaviourScope.classes);
      expect(c.visible, hasLength(4));
    });

    test('class filter, search, newest first', () async {
      repo.gradeRecords = (g) async => g == 'Grade 6'
          ? [rec('b6', grade: 'Grade 6', section: 'B', student: 'Yusuf', day: '2026-10-04')]
          : [rec('a1', student: 'Zara', day: '2026-10-02'), rec('a2', student: 'Omar', day: '2026-10-03', title: 'Late')];
      final c = await makeList(assignments: [cls5a, cls6b]);
      await c.load();
      c.setScope(BehaviourScope.classes);
      expect(c.visible.map((r) => r.id), ['b6', 'a2', 'a1']);
      c.setClassFilter(1);
      expect(c.visible.map((r) => r.id), ['b6']);
      c.setClassFilter(-1);
      c.query.value = 'zar';
      expect(c.visible.map((r) => r.id), ['a1']);
      c.query.value = 'late';
      expect(c.visible.map((r) => r.id), ['a2']);
    });

    test('no class assigned: empty state and NO request', () async {
      final c = await makeList(assignments: const []);
      await c.load();
      expect(c.state.value.status, SectionStatus.empty);
      expect(repo.calls, isEmpty);
    });

    test('without behaviour:view: forbidden, no request', () async {
      final c = await makeList(permissions: ['dashboard:view']);
      await c.load();
      expect(c.state.value.status, SectionStatus.forbidden);
      expect(repo.calls, isEmpty);
    });

    test('403 / 5xx / retry', () async {
      repo.gradeRecords = (g) async => throw ApiException('Forbidden resource', statusCode: 403);
      final c = await makeList();
      await c.load();
      expect(c.state.value.status, SectionStatus.forbidden);
      repo.gradeRecords = (g) async => throw ApiException('x', statusCode: 500);
      await c.load(force: true);
      expect(c.state.value.status, SectionStatus.error);
      repo.gradeRecords = (g) async => [rec('r1')];
      await c.load(force: true);
      expect(c.state.value.status, SectionStatus.data);
    });

    test('the grade list is optional: without it the class\'s own grade string is used', () async {
      students.grades = () async => throw ApiException('x', statusCode: 500);
      repo.gradeRecords = (g) async => [];
      final c = await makeList();
      await c.load();
      expect(repo.calls.where((x) => x.startsWith('grade:')), ['grade:Grade 5']);
    });

    test('addRecord shows a fresh entry on top without a re-fetch', () async {
      repo.gradeRecords = (g) async => [rec('old', day: '2026-09-01')];
      final c = await makeList();
      await c.load();
      c.addRecord(rec('new', day: '2026-10-05', by: 'x', byId: 'u'));
      expect(c.all.first.id, 'new');
      expect(repo.calls.where((x) => x.startsWith('grade:')), hasLength(2)); // Grade 5 + 5 from the single load
    });
  });

  group('BehaviourLogController (quick log)', () {
    Future<BehaviourLogController> make({List<Map<String, Object?>> assignments = const [cls5a], StudentSummary? initial, List<String>? permissions}) async {
      final h = await signedIn(permissions: permissions);
      h.api.assignments = assignments;
      await h.auth.refreshProfile(force: true);
      final list = BehaviourController(repository: repo, students: students, auth: h.auth, permissions: h.perms);
      final c = BehaviourLogController(repository: repo, students: students, auth: h.auth, permissions: h.perms, list: list, clock: () => fixedNow, initialStudent: initial);
      c.onInit();
      addTearDown(c.onClose);
      await Future<void>.delayed(Duration.zero);
      return c;
    }

    test('picker only offers MY classes\' students, loads each class lazily, searches by name and exact roll number', () async {
      students.roster = (cls) async => cls.grade == 'Grade 5' ? [student(1), student(2), student(12)] : [student(30, grade: 'Grade 6', section: 'B')];
      final c = await make(assignments: [cls5a, cls6b]);
      expect(c.classes.map((x) => x.label), ['Grade 5 - A', 'Grade 6 - B']);
      expect(students.calls.where((e) => e.startsWith('roster:')), ['roster:Grade 5 - A']);
      expect(c.pickerVisible, hasLength(3));
      c.pickerQuery.value = 'first2';
      expect(c.pickerVisible.map((s) => s.fullName), ['First2 Last2']);
      c.pickerQuery.value = '12';
      expect(c.pickerVisible.map((s) => s.rollNumber), ['12']);
      c.selectPickerClass(1);
      await Future<void>.delayed(Duration.zero);
      expect(students.calls.where((e) => e.startsWith('roster:')), ['roster:Grade 5 - A', 'roster:Grade 6 - B']);
      expect(c.pickerVisible.single.grade, 'Grade 6');
      c.selectPickerClass(0); // cached
      await c.loadPickerClass();
      expect(students.calls.where((e) => e.startsWith('roster:')), hasLength(2));
    });

    test('a preselected student outside my classes is refused; one inside is kept', () async {
      final c = await make(initial: student(1, grade: 'Grade 7', section: 'C'));
      expect(c.student.value, isNull);
      final d = await make(initial: student(1));
      expect(d.student.value, isNotNull);
    });

    test('picker error then retry; 403', () async {
      students.roster = (_) async => throw ApiException('boom', statusCode: 500);
      final c = await make();
      expect(c.pickerState.status, SectionStatus.error);
      students.roster = (_) async => [student(1)];
      await c.loadPickerClass(force: true);
      expect(c.pickerState.status, SectionStatus.data);
      students.roster = (_) async => throw ApiException('Forbidden', statusCode: 403);
      await c.loadPickerClass(force: true);
      expect(c.pickerState.status, SectionStatus.forbidden);
    });

    test('without behaviour:manage the picker never loads and logging is refused', () async {
      final c = await make(permissions: ['behaviour:view']);
      expect(c.canLog, isFalse);
      expect(students.calls.where((e) => e.startsWith('roster:')), isEmpty);
    });

    test('kind drives categories, points and severity', () async {
      students.roster = (_) async => [student(1)];
      final c = await make();
      expect(c.kind.value, BehaviourKind.merit);
      expect(c.categories, contains('helping_others'));
      expect(c.points, 5);
      c.setMagnitude(3);
      expect(c.points, 3);
      c.setKind(BehaviourKind.demerit);
      expect(c.categories, contains('bullying'));
      expect(c.points, -3);
      expect(c.category.value, isNull); // category reset on kind change
      c.setKind(BehaviourKind.note);
      expect(c.points, 0);
      expect(c.categories, contains('parent_meeting'));
    });

    test('category fills an empty title once; a typed title is never overwritten', () async {
      students.roster = (_) async => [student(1)];
      final c = await make();
      c.setCategory('helping_others');
      expect(c.titleC.text, 'Helping Others');
      c.setCategory('leadership');
      expect(c.titleC.text, 'Leadership'); // still the auto title
      c.titleC.text = 'My own words';
      c.setCategory('innovation');
      expect(c.titleC.text, 'My own words');
    });

    test('validation: student, category, title, description (server would answer a bare 500)', () async {
      students.roster = (_) async => [student(1)];
      final c = await make();
      var r = await c.submit() as LogInvalid;
      expect(r.errors.keys, containsAll(['student', 'category', 'title', 'description']));
      expect(repo.bodies, isEmpty);
      c.selectStudent(student(1));
      c.setCategory('helping_others');
      r = await c.submit() as LogInvalid;
      expect(r.errors.keys, ['description']);
      c.descriptionC.text = '   ';
      expect((await c.submit() as LogInvalid).errors['description'], isNotNull);
    });

    test('a student outside my classes (or without a grade) cannot be logged even if selected programmatically', () async {
      students.roster = (_) async => [student(1)];
      final c = await make();
      c.selectStudent(student(1, grade: 'Grade 7', section: 'C'));
      c.setCategory('helping_others');
      c.descriptionC.text = 'x';
      expect((await c.submit() as LogInvalid).errors['student'], contains('not in one of your classes'));
      c.selectStudent(student(1, grade: ''));
      expect((await c.submit() as LogInvalid).errors['student'], contains('no grade'));
    });

    test('create payload: exact keys, merit +points, parentNotified false, my id/name, student academic year', () async {
      students.roster = (_) async => [student(1)];
      final c = await make();
      c.selectStudent(student(6));
      c.setCategory('helping_others');
      c.descriptionC.text = ' Helped a friend ';
      c.setMagnitude(2);
      final r = await c.submit();
      expect(r, isA<LogSaved>());
      expect(repo.bodies.single, {
        'studentId': student(6).id,
        'studentName': 'First6 Last6',
        'grade': 'Grade 5',
        'section': 'A',
        'rollNumber': '6',
        'date': '2026-10-05',
        'type': 'positive',
        'category': 'helping_others',
        'title': 'Helping Others',
        'description': 'Helped a friend',
        'severity': 'low',
        'points': 2,
        'parentNotified': false,
        'followUpRequired': false,
        'reportedBy': 'Tess Teacher',
        'reportedById': 'u',
        'academicYear': '2026-27',
      });
      expect(c.list!.all.first.id, 'new1'); // shows up in the list without a refetch
    });

    test('demerit: negative points and the chosen severity; note: zero points, low severity', () async {
      students.roster = (_) async => [student(1)];
      final c = await make();
      c.selectStudent(student(1));
      c.setKind(BehaviourKind.demerit);
      c.setCategory('late_coming');
      c.descriptionC.text = 'Late twice';
      c.setSeverity('high');
      c.setMagnitude(3);
      await c.submit();
      expect(repo.bodies.last['type'], 'negative');
      expect(repo.bodies.last['points'], -3);
      expect(repo.bodies.last['severity'], 'high');
      c.setKind(BehaviourKind.note);
      c.setCategory('parent_meeting');
      await c.submit();
      expect(repo.bodies.last['type'], 'neutral');
      expect(repo.bodies.last['points'], 0);
      expect(repo.bodies.last['severity'], 'low');
    });

    test('date: defaults to today (device calendar day), the future is clamped to today', () async {
      final c = await make();
      expect(c.day.value, DateTime(2026, 10, 5));
      c.setDay(DateTime(2026, 10, 9));
      expect(c.day.value, DateTime(2026, 10, 5));
      c.setDay(DateTime(2026, 9, 30, 23, 59));
      expect(c.day.value, DateTime(2026, 9, 30));
    });

    test('double submit sends one request', () async {
      students.roster = (_) async => [student(1)];
      final gate = Completer<BehaviourRecord>();
      repo.onCreate = (b) => gate.future;
      final c = await make();
      c.selectStudent(student(1));
      c.setCategory('helping_others');
      c.descriptionC.text = 'x';
      final first = c.submit();
      await Future<void>.delayed(Duration.zero);
      expect(await c.submit(), isA<LogIgnored>());
      gate.complete(rec('n1'));
      await first;
      expect(repo.bodies, hasLength(1));
      expect(c.saving.value, isFalse);
    });

    test('server failures keep the form: 500 (mongoose validation is a bare 500), 403, offline', () async {
      students.roster = (_) async => [student(1)];
      final c = await make();
      c.selectStudent(student(1));
      c.setCategory('helping_others');
      c.descriptionC.text = 'Keep me';
      repo.onCreate = (b) async => throw ApiException('Internal server error', statusCode: 500);
      var f = (await c.submit() as LogFailed).failure;
      expect(f.kind.name, 'server');
      expect(f.message, contains('Your changes are kept'));
      expect(c.descriptionC.text, 'Keep me');
      repo.onCreate = (b) async => throw ApiException('Forbidden resource', statusCode: 403);
      expect((await c.submit() as LogFailed).failure.message, "You can't save this entry. Forbidden resource");
      repo.onCreate = (b) async => throw ApiException('No internet connection.');
      expect((await c.submit() as LogFailed).failure.message, contains('Reconnect'));
      repo.onCreate = (b) async => BehaviourRecord.fromJson({'_id': 'ok', ...b});
      expect(await c.submit(), isA<LogSaved>());
      expect(c.failure.value, isNull);
    });
  });

  group('BehaviourStudentController (history)', () {
    Future<BehaviourStudentController> make({String id = 'st1', StudentSummary? initial, List<Map<String, Object?>> assignments = const [cls5a]}) async {
      final h = await signedIn();
      h.api.assignments = assignments;
      await h.auth.refreshProfile(force: true);
      return BehaviourStudentController(studentId: id, initial: initial, repository: repo, students: students, auth: h.auth, permissions: h.perms);
    }

    StudentSummary st(String id, {String grade = 'Grade 5', String section = 'A'}) => StudentSummary(id: id, firstName: 'Z', lastName: 'M', grade: grade, section: section);

    test('given student in my class: records + tarbiyah load independently', () async {
      repo.studentRecords = (id) async => [rec('r1', byId: 'u', points: 5), rec('r2', points: -2)];
      repo.tarbiyah = (id) async => throw ApiException('boom', statusCode: 500);
      final c = await make(initial: st('st1'));
      await c.load();
      expect(c.records.value.status, SectionStatus.data);
      expect(c.tarbiyah.value.status, SectionStatus.error);
      expect(c.totalPoints, 3);
      expect(repo.calls, containsAll(['student:st1', 'tarbiyah:st1']));
    });

    test('student NOT in my classes: refused and NO record request is made', () async {
      final c = await make(initial: st('st9', grade: 'Grade 7', section: 'C'), id: 'st9');
      await c.load();
      expect(c.student.value.status, SectionStatus.empty);
      expect(repo.calls, isEmpty);
    });

    test('deep link without a student: resolved by scanning my class rosters, then loaded', () async {
      students.roster = (cls) async => [student(1), student(2)];
      repo.studentRecords = (id) async => [rec('r1', sid: id)];
      final c = await make(id: student(2).id);
      await c.load();
      expect(c.student.value.data!.id, student(2).id);
      expect(repo.calls, contains('student:${student(2).id}'));
    });

    test('deep link to a stranger: rosters scanned, not found, nothing requested from the behaviour API', () async {
      students.roster = (cls) async => [student(1)];
      final c = await make(id: 'someone-else');
      await c.load();
      expect(c.student.value.status, SectionStatus.empty);
      expect(repo.calls, isEmpty);
    });

    test('empty history, 403 on records, addRecord', () async {
      repo.studentRecords = (id) async => [];
      final c = await make(initial: st('st1'));
      await c.load();
      expect(c.records.value.status, SectionStatus.empty);
      expect(c.tarbiyah.value.status, SectionStatus.empty);
      c.addRecord(rec('n1', points: 4));
      expect(c.totalPoints, 4);
      repo.studentRecords = (id) async => throw ApiException('Forbidden resource', statusCode: 403);
      await c.load();
      expect(c.records.value.status, SectionStatus.forbidden);
    });
  });
}
