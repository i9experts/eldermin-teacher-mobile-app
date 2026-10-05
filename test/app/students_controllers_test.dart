// ignore_for_file: invalid_use_of_protected_member
import 'dart:convert';
import 'dart:io';
import 'package:eldermin_teacher_app/app/modules/home/models/section_state.dart';
import 'package:eldermin_teacher_app/app/modules/students/controllers/student_detail_controller.dart';
import 'package:eldermin_teacher_app/app/modules/students/controllers/students_controller.dart';
import 'package:eldermin_teacher_app/core/models/classroom/attendance_models.dart';
import 'package:eldermin_teacher_app/core/models/classroom/student_360.dart';
import 'package:eldermin_teacher_app/core/models/classroom/student_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_classroom_repositories.dart';

Student360 fx360(Map<String, dynamic> studentPatch) {
  final raw = jsonDecode(File('test/fixtures/classroom/student_360.json').readAsStringSync()) as Map<String, dynamic>;
  raw['student'] = {...(raw['student'] as Map<String, dynamic>), ...studentPatch};
  return Student360.fromJson(raw);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeStudentsRepository repo;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakeStudentsRepository();
  });
  tearDown(Get.reset);

  group('StudentsController (roster scoping)', () {
    Future<StudentsController> make({bool classTeacher = false, List<String>? permissions, List<Map<String, Object?>> assignments = const []}) async {
      final h = await signedIn(classTeacher: classTeacher, permissions: permissions);
      h.api.assignments = assignments;
      await h.auth.refreshProfile(force: true);
      return StudentsController(repository: repo, auth: h.auth, permissions: h.perms);
    }

    test('class teacher: the roster of the class-teacher class only', () async {
      repo.roster = (cls) async => [student(1), student(2)];
      final c = await make(classTeacher: true);
      expect(c.classes.map((x) => x.label), ['Grade 5 - A']);
      await c.load();
      expect(repo.calls, contains('roster:Grade 5 - A'));
      expect(c.state.data, hasLength(2));
    });

    test('subject teacher with several assignments: one class at a time, lazily, cached per class', () async {
      repo.roster = (cls) async => [student(cls.grade.length)];
      final c = await make(assignments: [
        {'gradeLevel': 'Grade 5', 'sectionName': 'A', 'subjectName': 'Maths'},
        {'gradeLevel': 'Grade 6', 'sectionName': 'B', 'subjectName': 'Science'},
      ]);
      expect(c.classes.map((x) => x.label), ['Grade 5 - A', 'Grade 6 - B']);
      await c.load();
      expect(repo.calls.where((e) => e.startsWith('roster:')), ['roster:Grade 5 - A']);
      c.selectClass(1);
      await Future<void>.delayed(Duration.zero);
      expect(repo.calls.where((e) => e.startsWith('roster:')), ['roster:Grade 5 - A', 'roster:Grade 6 - B']);
      c.selectClass(0); // cached: no new request
      await c.load();
      expect(repo.calls.where((e) => e.startsWith('roster:')), hasLength(2));
      expect(repo.calls.where((e) => e == 'grades'), hasLength(1));
    });

    test('no class at all (no flag, no assignments): empty state and NO student request', () async {
      final c = await make();
      expect(c.classes, isEmpty);
      expect(c.state.status, SectionStatus.empty);
      await c.load();
      expect(repo.calls, isEmpty);
    });

    test('without students:view: forbidden and no request', () async {
      final c = await make(classTeacher: true, permissions: ['teaching:view']);
      expect(c.state.status, SectionStatus.forbidden);
      await c.load();
      expect(repo.calls, isEmpty);
    });

    test('search by name, preferred name, roll number (exact) and GR no; clearing on class change', () async {
      repo.roster = (_) async => [
            const StudentSummary(id: 'a', firstName: 'Aarav', lastName: 'Khan', rollNumber: '1', grNo: 'GR-77'),
            const StudentSummary(id: 'b', firstName: 'Zara', lastName: 'Malik', rollNumber: '12', preferredName: 'Zee'),
          ];
      final c = await make(classTeacher: true);
      await c.load();
      c.query.value = 'zar';
      expect(c.visible.map((s) => s.id), ['b']);
      c.query.value = '1'; // roll numbers match exactly: "1" is Aarav, not "12"
      expect(c.visible.map((s) => s.id), ['a']);
      c.query.value = 'gr-7';
      expect(c.visible.map((s) => s.id), ['a']);
      c.query.value = 'zee';
      expect(c.visible.map((s) => s.id), ['b']);
      c.query.value = 'nobody';
      expect(c.visible, isEmpty);
    });

    test('errors: 403 -> forbidden (no crash), 500 -> error then retry works, empty class -> empty', () async {
      final c = await make(classTeacher: true);
      repo.roster = (_) async => throw ApiException('Forbidden', statusCode: 403);
      await c.load();
      expect(c.state.status, SectionStatus.forbidden);
      repo.roster = (_) async => throw ApiException('x', statusCode: 500);
      await c.load(force: true);
      expect(c.state.status, SectionStatus.error);
      repo.roster = (_) async => [student(1)];
      await c.load(force: true);
      expect(c.state.status, SectionStatus.data);
      repo.roster = (_) async => [];
      await c.load(force: true);
      expect(c.state.status, SectionStatus.empty);
    });

    test('grades-sections failure is non-fatal', () async {
      repo.grades = () async => throw ApiException('no', statusCode: 403);
      repo.roster = (_) async => [student(1)];
      final c = await make(classTeacher: true);
      await c.load();
      expect(c.state.status, SectionStatus.data);
    });
  });

  group('StudentDetailController (360 scope + independence)', () {
    Future<StudentDetailController> make({bool classTeacher = true, List<String>? permissions}) async {
      final h = await signedIn(classTeacher: classTeacher, permissions: permissions);
      return StudentDetailController('sid', repository: repo, auth: h.auth, permissions: h.perms, clock: () => DateTime(2026, 10, 5));
    }

    test('student of my class: 360 shown, this-month counts requested for the current month', () async {
      repo.detail = (_) async => fx360({'currentGrade': 'Grade 5', 'currentSection': 'A'});
      repo.summary = (id, y, m) async => const StatusCounts(present: 3, absent: 1);
      final c = await make();
      await c.load();
      expect(c.outOfScope.value, isFalse);
      expect(c.detail.value.status, SectionStatus.data);
      expect(c.month.value.data!.present, 3);
      expect(repo.calls, ['360:sid', 'summary:sid:2026-10']);
    });

    test('tolerant class match: "5"/"a" is still my class', () async {
      repo.detail = (_) async => fx360({'currentGrade': '5', 'currentSection': 'a'});
      final c = await make();
      await c.load();
      expect(c.outOfScope.value, isFalse);
    });

    test('student of ANOTHER class: nothing shown, parsed data dropped, no further request is made', () async {
      repo.detail = (_) async => fx360({'currentGrade': 'Grade 5', 'currentSection': 'B'});
      final c = await make();
      await c.load();
      expect(c.outOfScope.value, isTrue);
      expect(c.detail.value.hasData, isFalse);
      expect(repo.calls, ['360:sid']); // the attendance summary was NOT requested
    });

    test('a teacher with no classes cannot open any 360', () async {
      repo.detail = (_) async => fx360({});
      final c = await make(classTeacher: false);
      await c.load();
      expect(c.outOfScope.value, isTrue);
    });

    test('the monthly summary failing does not hide the 360', () async {
      repo.detail = (_) async => fx360({'currentGrade': 'Grade 5', 'currentSection': 'A'});
      repo.summary = (_, __, ___) async => throw ApiException('boom', statusCode: 500);
      final c = await make();
      await c.load();
      expect(c.detail.value.status, SectionStatus.data);
      expect(c.month.value.status, SectionStatus.error);
    });

    test('403 / 404 / 500 states and retry; permission missing is forbidden without a request', () async {
      final c = await make();
      repo.detail = (_) async => throw ApiException('Forbidden', statusCode: 403);
      await c.load();
      expect(c.detail.value.status, SectionStatus.forbidden);
      repo.detail = (_) async => throw ApiException('Student not found', statusCode: 404);
      await c.load();
      expect(c.detail.value.status, SectionStatus.empty); // 'Student not found'
      repo.detail = (_) async => throw ApiException('x', statusCode: 500);
      await c.load();
      expect(c.detail.value.status, SectionStatus.error);
      repo.detail = (_) async => fx360({'currentGrade': 'Grade 5', 'currentSection': 'A'});
      await c.load();
      expect(c.detail.value.status, SectionStatus.data);

      Get.reset();
      Get.testMode = true;
      repo = FakeStudentsRepository();
      final denied = await make(permissions: ['teaching:view']);
      await denied.load();
      expect(denied.detail.value.status, SectionStatus.forbidden);
      expect(repo.calls, isEmpty);
    });

    test('empty id is an error, never a request', () async {
      final h = await signedIn(classTeacher: true);
      final c = StudentDetailController('', repository: repo, auth: h.auth, permissions: h.perms);
      await c.load();
      expect(c.detail.value.status, SectionStatus.error);
      expect(repo.calls, isEmpty);
    });
  });
}
