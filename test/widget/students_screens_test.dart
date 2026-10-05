import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:eldermin_teacher_app/app/modules/classes/controllers/classes_controller.dart';
import 'package:eldermin_teacher_app/app/modules/classes/views/classes_screen.dart';
import 'package:eldermin_teacher_app/app/modules/students/controllers/student_detail_controller.dart';
import 'package:eldermin_teacher_app/app/modules/students/controllers/students_controller.dart';
import 'package:eldermin_teacher_app/app/modules/students/views/student_detail_screen.dart';
import 'package:eldermin_teacher_app/app/modules/students/views/students_screen.dart';
import 'package:eldermin_teacher_app/core/models/classroom/attendance_models.dart';
import 'package:eldermin_teacher_app/core/models/classroom/student_360.dart';
import 'package:eldermin_teacher_app/core/models/classroom/student_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_classroom_repositories.dart';

Student360 fx360([Map<String, dynamic> patch = const {}]) {
  final raw = jsonDecode(File('test/fixtures/classroom/student_360.json').readAsStringSync()) as Map<String, dynamic>;
  raw['student'] = {...(raw['student'] as Map<String, dynamic>), ...patch};
  return Student360.fromJson(raw);
}

void main() {
  late FakeStudentsRepository repo;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakeStudentsRepository();
  });
  tearDown(Get.reset);

  Future<StudentsController> bootList(WidgetTester t, {bool classTeacher = true, List<Map<String, Object?>> assignments = const [], List<String>? permissions}) async {
    final h = (await t.runAsync(() async {
      final h = await signedIn(classTeacher: classTeacher, permissions: permissions);
      h.api.assignments = assignments;
      await h.auth.refreshProfile(force: true);
      return h;
    }))!;
    final c = Get.put(StudentsController(repository: repo, auth: h.auth, permissions: h.perms));
    await t.binding.setSurfaceSize(const Size(430, 1800));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: const StudentsScreen()));
    await t.pump();
    await c.load();
    await t.pump();
    return c;
  }

  group('My students', () {
    testWidgets('lists the class roster with roll numbers and a count; search narrows it', (t) async {
      repo.roster = (_) async => [for (var i = 1; i <= 4; i++) student(i)];
      await bootList(t);
      expect(find.text('First1 Last1'), findsOneWidget);
      expect(find.text('Roll 3 · '.trim()), findsNothing); // roll + GR only when GR exists
      expect(find.text('Roll 3'), findsOneWidget);
      expect(find.byKey(const Key('students_count')), findsOneWidget);
      expect(find.text('4 students'), findsOneWidget);
      await t.enterText(find.byKey(const Key('students_search')), 'First2');
      await t.pump();
      expect(find.text('First2 Last2'), findsOneWidget);
      expect(find.text('First1 Last1'), findsNothing);
      expect(find.text('1 of 4 students'), findsOneWidget);
      await t.enterText(find.byKey(const Key('students_search')), 'nope');
      await t.pump();
      expect(find.byKey(const Key('students_search_empty')), findsOneWidget);
    });

    testWidgets('several classes: chips switch the roster; class teacher class is labelled', (t) async {
      repo.roster = (cls) async => cls.grade == 'Grade 5' ? [student(1)] : [student(2, grade: 'Grade 6', section: 'B')];
      await bootList(t, assignments: [
        {'gradeLevel': 'Grade 6', 'sectionName': 'B', 'subjectName': 'Science'}
      ]);
      expect(find.byKey(const Key('class_picker')), findsOneWidget);
      expect(find.text('Grade 5 - A · Class teacher'), findsOneWidget);
      expect(find.text('First1 Last1'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('class_chip_1')));
      await t.pump();
      await t.pump();
      expect(find.text('First2 Last2'), findsOneWidget);
      expect(find.text('First1 Last1'), findsNothing);
    });

    testWidgets('no assigned class: honest empty state, nothing requested', (t) async {
      await bootList(t, classTeacher: false);
      expect(find.text("You aren't assigned to any class yet"), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets('403, error + Try again, empty class, loading shimmer', (t) async {
      repo.roster = (_) async => throw ApiException('Forbidden', statusCode: 403);
      await bootList(t);
      expect(find.byKey(const Key('screen_forbidden')), findsOneWidget);
      expect(find.text("You don't have access"), findsOneWidget);

      Get.reset();
      Get.testMode = true;
      var fail = true;
      repo = FakeStudentsRepository()..roster = (_) async => fail ? throw ApiException('boom', statusCode: 500) : [student(1)];
      await bootList(t);
      expect(find.byKey(const Key('screen_error')), findsOneWidget);
      fail = false;
      await t.tap(find.text('Try again'));
      await t.pump();
      await t.pump();
      expect(find.text('First1 Last1'), findsOneWidget);

      Get.reset();
      Get.testMode = true;
      repo = FakeStudentsRepository()..roster = (_) async => [];
      await bootList(t);
      expect(find.byKey(const Key('screen_empty')), findsOneWidget);

      Get.reset();
      Get.testMode = true;
      final gate = Completer<List<StudentSummary>>();
      repo = FakeStudentsRepository()..roster = (_) => gate.future;
      final h = (await t.runAsync(() => signedIn(classTeacher: true)))!;
      final c = Get.put(StudentsController(repository: repo, auth: h.auth, permissions: h.perms));
      await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: const StudentsScreen()));
      unawaited(c.load());
      await t.pump();
      expect(find.byKey(const Key('screen_loading')), findsOneWidget);
      gate.complete([student(1)]);
      await t.pump();
      await t.pump();
    });

    testWidgets('pull to refresh reloads the class', (t) async {
      repo.roster = (_) async => [student(1)];
      await bootList(t);
      await t.binding.setSurfaceSize(null);
      await t.pump();
      final before = repo.calls.where((e) => e.startsWith('roster:')).length;
      await t.fling(find.byType(ListView).first, const Offset(0, 300), 1000);
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      await t.pump(const Duration(seconds: 1));
      expect(repo.calls.where((e) => e.startsWith('roster:')).length, greaterThan(before));
    });
  });

  group('Student 360 screen', () {
    Future<StudentDetailController> bootDetail(WidgetTester t, {Student360? data, Object? error, bool classTeacher = true, List<String>? permissions}) async {
      final h = (await t.runAsync(() => signedIn(classTeacher: classTeacher, permissions: permissions)))!;
      repo.detail = (_) async => error != null ? throw error : data!;
      repo.summary = (_, __, ___) async => const StatusCounts(present: 12, late: 1, absent: 2);
      final c = Get.put(StudentDetailController('sid', repository: repo, auth: h.auth, permissions: h.perms, clock: () => DateTime(2026, 10, 5)), tag: 'sid');
      await t.binding.setSurfaceSize(const Size(430, 3000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: const StudentDetailScreen(studentId: 'sid')));
      await t.pump();
      await c.load();
      await t.pump();
      return c;
    }

    String allText(WidgetTester t) => t.widgetList<Text>(find.byType(Text)).map((e) => e.data ?? '').join(' | ');

    testWidgets('shows the whitelisted sections and NO fee / contact / income data', (t) async {
      await bootDetail(t, data: fx360({'currentGrade': 'Grade 5', 'currentSection': 'A'}));
      expect(find.byKey(const Key('student_profile')), findsOneWidget);
      expect(find.byKey(const Key('student_attendance')), findsOneWidget);
      expect(find.byKey(const Key('attendance_percentage')), findsOneWidget);
      expect(find.byKey(const Key('student_behaviour')), findsOneWidget);
      expect(find.textContaining('helping'), findsOneWidget);
      expect(find.byKey(const Key('student_results')), findsOneWidget);
      expect(find.text('Unit 1 test (DUMMY)'), findsOneWidget);
      expect(find.byKey(const Key('student_guardians')), findsOneWidget);
      expect(find.text('Father'), findsOneWidget);
      expect(find.text('Mother'), findsOneWidget);
      expect(find.byKey(const Key('month_counts')), findsOneWidget);
      expect(find.byKey(const Key('student_privacy_note')), findsOneWidget);
      final text = allText(t);
      for (final bad in ['monthlyTuitionFee', '18500', '21000', '0300-555', '00000-0000000', 'example.test', '250000', '180000', 'DUMMY ADDRESS', 'POL-DUMMY', 'tuition', 'CNIC', 'pending']) {
        expect(text.contains(bad), isFalse, reason: 'screen text must not contain "$bad"');
      }
    });

    testWidgets('allergy flag is prominent when present', (t) async {
      await bootDetail(t, data: fx360({'currentGrade': 'Grade 5', 'currentSection': 'A', 'medical': {'allergies': ['Peanuts (DUMMY)'], 'doctorPhone': '0300-5550003'}}));
      expect(find.byKey(const Key('student_allergies')), findsOneWidget);
      expect(find.text('Peanuts (DUMMY)'), findsOneWidget);
      expect(allText(t).contains('0300-555'), isFalse);
    });

    testWidgets('a student outside my classes shows nothing but an explanation', (t) async {
      await bootDetail(t, data: fx360({'currentGrade': 'Grade 9', 'currentSection': 'Z'}));
      expect(find.byKey(const Key('student_out_of_scope')), findsOneWidget);
      expect(find.byKey(const Key('student_profile')), findsNothing);
      expect(find.byKey(const Key('student_guardians')), findsNothing);
    });

    testWidgets('403, 404 and 500 states (no crash); this-month failure keeps the rest', (t) async {
      await bootDetail(t, error: ApiException('Forbidden', statusCode: 403));
      expect(find.byKey(const Key('screen_forbidden')), findsOneWidget);

      Get.reset();
      Get.testMode = true;
      repo = FakeStudentsRepository();
      await bootDetail(t, error: ApiException('Student not found', statusCode: 404));
      expect(find.text('Student not found'), findsOneWidget);

      Get.reset();
      Get.testMode = true;
      repo = FakeStudentsRepository();
      await bootDetail(t, error: ApiException('x', statusCode: 500));
      expect(find.byKey(const Key('screen_error')), findsOneWidget);

      Get.reset();
      Get.testMode = true;
      repo = FakeStudentsRepository();
      final c = await bootDetail(t, data: fx360({'currentGrade': 'Grade 5', 'currentSection': 'A'}));
      repo.summary = (_, __, ___) async => throw ApiException('x', statusCode: 500);
      await c.load();
      await t.pump();
      expect(find.byKey(const Key('student_profile')), findsOneWidget);
      expect(find.byKey(const Key('month_error')), findsOneWidget);
    });
  });

  group('Classes tab', () {
    Future<void> bootClasses(WidgetTester t, {bool classTeacher = true, List<String>? permissions}) async {
      (await t.runAsync(() => signedIn(classTeacher: classTeacher, permissions: permissions)));
      Get.put(ClassesController());
      await t.binding.setSurfaceSize(const Size(430, 1600));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: const Scaffold(body: ClassesScreen())));
      await t.pump();
    }

    testWidgets('class teacher: grid with built modules plain and unbuilt ones labelled Coming soon; my classes', (t) async {
      await bootClasses(t);
      expect(find.byKey(const Key('classes_grid')), findsOneWidget);
      expect(find.byKey(const ValueKey('module_students')), findsOneWidget);
      expect(find.byKey(const ValueKey('module_attendance')), findsOneWidget);
      expect(find.byKey(const ValueKey('module_homework')), findsOneWidget);
      expect(find.text('Coming soon'), findsNWidgets(3)); // lesson plans, syllabus, assessments (homework and behaviour are live since 5b)
      expect(find.text('Grade 5 - A'), findsOneWidget);
    });

    testWidgets('subject teacher: no Attendance entry; students entry only with students:view', (t) async {
      await bootClasses(t, classTeacher: false);
      expect(find.byKey(const ValueKey('module_attendance')), findsNothing);
      expect(find.byKey(const ValueKey('module_students')), findsOneWidget);
      Get.reset();
      Get.testMode = true;
      await bootClasses(t, classTeacher: false, permissions: ['teaching:view']);
      expect(find.byKey(const ValueKey('module_students')), findsNothing);
      expect(find.byKey(const ValueKey('module_homework')), findsOneWidget);
    });
  });
}
