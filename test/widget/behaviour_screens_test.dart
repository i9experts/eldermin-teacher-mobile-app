// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';
import 'package:eldermin_teacher_app/app/modules/behaviour/controllers/behaviour_controller.dart';
import 'package:eldermin_teacher_app/app/modules/behaviour/controllers/behaviour_log_controller.dart';
import 'package:eldermin_teacher_app/app/modules/behaviour/controllers/behaviour_student_controller.dart';
import 'package:eldermin_teacher_app/app/modules/behaviour/views/behaviour_new_screen.dart';
import 'package:eldermin_teacher_app/app/modules/behaviour/views/behaviour_screen.dart';
import 'package:eldermin_teacher_app/app/modules/behaviour/views/behaviour_student_screen.dart';
import 'package:eldermin_teacher_app/core/models/behaviour/behaviour_models.dart';
import 'package:eldermin_teacher_app/core/models/classroom/student_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_classroom_repositories.dart';
import '../support/fake_phase5b_repositories.dart';

final now = DateTime(2026, 10, 5, 9, 30);
const cls5a = {'gradeLevel': 'Grade 5', 'sectionName': 'A', 'subjectName': 'Mathematics'};
const cls6b = {'gradeLevel': 'Grade 6', 'sectionName': 'B', 'subjectName': 'Science'};

BehaviourRecord rec(String id,
        {String student = 'Zara Malik',
        String sid = 'st1',
        String grade = 'Grade 5',
        String section = 'A',
        String type = 'positive',
        String by = 'Someone',
        String? byId,
        String day = '2026-10-01',
        int points = 5,
        String category = 'helping_others',
        String title = 'Helped a classmate',
        String severity = 'low',
        bool resolved = false}) =>
    BehaviourRecord.fromJson({
      '_id': id, 'studentId': sid, 'studentName': student, 'grade': grade, 'section': section, 'type': type, 'category': category,
      'title': title, 'description': 'Details of $title', 'date': '${day}T00:00:00.000Z', 'points': points, 'reportedBy': by,
      'severity': severity, 'resolved': resolved, if (byId != null) 'reportedById': byId,
    });

void main() {
  late FakeBehaviourRepository repo;
  late FakeStudentsRepository students;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakeBehaviourRepository();
    students = FakeStudentsRepository()
      ..grades = (() async => const GradesSections(grades: ['Grade 5', 'Grade 6'], sections: ['A', 'B']))
      ..roster = (cls) async => cls.grade == 'Grade 5' ? [student(1), student(2), student(3)] : [student(30, grade: 'Grade 6', section: 'B')];
  });
  tearDown(Get.reset);

  Future<dynamic> signIn(WidgetTester t, {List<Map<String, Object?>> assignments = const [cls5a], List<String>? permissions}) async {
    return (await t.runAsync(() async {
      final h = await signedIn(permissions: permissions);
      h.api.assignments = assignments;
      await h.auth.refreshProfile(force: true);
      return h;
    }))!;
  }

  Future<void> open(WidgetTester t, Widget screen, {Size size = const Size(430, 3000)}) async {
    await t.binding.setSurfaceSize(size);
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: const Scaffold(body: Text('root'))));
    unawaited(Get.to(() => screen));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }

  Future<void> settle(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
  }

  group('Behaviour home', () {
    Future<BehaviourController> boot(WidgetTester t, {List<Map<String, Object?>> assignments = const [cls5a], List<String>? permissions}) async {
      final h = await signIn(t, assignments: assignments, permissions: permissions);
      final c = Get.put(BehaviourController(repository: repo, students: students, auth: h.auth, permissions: h.perms));
      await open(t, const BehaviourScreen());
      await c.load();
      await settle(t);
      return c;
    }

    testWidgets('my entries first; the parents-can-see notice; other classes\' records never appear', (t) async {
      repo.gradeRecords = (g) async => [
            rec('r1', by: 'Tess Teacher', byId: 'u', title: 'Great teamwork'),
            rec('r2', by: 'Omar Colleague', title: 'Colleague entry', student: 'Hamza Raza'),
            rec('r3', section: 'B', title: 'Other class entry', student: 'Not Mine'),
          ];
      await boot(t);
      expect(find.byKey(const Key('parent_visible_note')), findsOneWidget);
      expect(find.text('Great teamwork'), findsOneWidget);
      expect(find.text('Zara Malik'), findsOneWidget);
      expect(find.text('Colleague entry'), findsNothing); // not mine
      expect(find.text('Other class entry'), findsNothing);
      expect(find.text('My entries (1)'), findsOneWidget);
      expect(find.text('My classes (2)'), findsOneWidget);
      await t.tap(find.text('My classes (2)'));
      await settle(t);
      expect(find.text('Colleague entry'), findsOneWidget);
      expect(find.text('Other class entry'), findsNothing); // never, in any segment
      expect(find.text('You'), findsNothing);
    });

    testWidgets('tile shows points, demerit severity, resolved flag; tap opens the student history route', (t) async {
      repo.gradeRecords = (g) async => [
            rec('r1', by: 'Tess Teacher', byId: 'u', type: 'negative', category: 'misconduct', title: 'Disrupted the lesson', points: -5, severity: 'high', resolved: true),
          ];
      await boot(t);
      expect(find.text('-5'), findsOneWidget);
      expect(find.text('HIGH'), findsOneWidget);
      expect(find.text('RESOLVED'), findsOneWidget);
      expect(find.text('MISCONDUCT'), findsOneWidget);
    });

    testWidgets('class chips appear with several classes and narrow the list; search narrows by student', (t) async {
      repo.gradeRecords = (g) async => g == 'Grade 6'
          ? [rec('b6', grade: 'Grade 6', section: 'B', by: 'Tess Teacher', byId: 'u', student: 'Yusuf Baig', title: 'Six B entry')]
          : [rec('a1', by: 'Tess Teacher', byId: 'u', student: 'Zara Malik', title: 'Five A entry')];
      await boot(t, assignments: [cls5a, cls6b]);
      expect(find.text('Six B entry'), findsOneWidget);
      expect(find.text('Five A entry'), findsOneWidget);
      await t.tap(find.byKey(const Key('chip_cls_1')));
      await settle(t);
      expect(find.text('Five A entry'), findsNothing);
      await t.tap(find.byKey(const Key('chip_cls_all')));
      await t.enterText(find.byKey(const Key('beh_search')), 'zara');
      await settle(t);
      expect(find.text('Five A entry'), findsOneWidget);
      expect(find.text('Six B entry'), findsNothing);
      await t.enterText(find.byKey(const Key('beh_search')), 'nobody');
      await settle(t);
      expect(find.byKey(const Key('beh_filter_empty')), findsOneWidget);
    });

    testWidgets('states: empty, error + Try again, 403, no class; loading shimmer; FAB only with behaviour:manage', (t) async {
      final h = await signIn(t);
      final gate = Completer<List<BehaviourRecord>>();
      repo.gradeRecords = (g) => gate.future;
      final c = Get.put(BehaviourController(repository: repo, students: students, auth: h.auth, permissions: h.perms));
      await open(t, const BehaviourScreen());
      unawaited(c.load());
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('screen_loading')), findsOneWidget);
      gate.complete([]);
      await settle(t);
      await settle(t);
      expect(find.byKey(const Key('screen_empty')), findsOneWidget);
      expect(find.text('No behaviour recorded yet'), findsOneWidget);
      expect(find.byKey(const Key('beh_new_fab')), findsOneWidget);
      repo.gradeRecords = (g) async => throw ApiException('Internal server error', statusCode: 500);
      await c.load(force: true);
      await settle(t);
      expect(find.byKey(const Key('screen_error')), findsOneWidget);
      repo.gradeRecords = (g) async => [rec('r1', by: 'Tess Teacher', byId: 'u', title: 'Back')];
      await t.tap(find.text('Try again'));
      await settle(t);
      await settle(t);
      expect(find.text('Back'), findsOneWidget);
      repo.gradeRecords = (g) async => throw ApiException('Forbidden resource', statusCode: 403);
      await c.load(force: true);
      await settle(t);
      expect(find.text("You don't have access"), findsOneWidget);
    });

    testWidgets('no class assigned: honest empty page; view-only permission hides the log button', (t) async {
      await boot(t, assignments: const []);
      expect(find.text("You aren't assigned to any class yet"), findsOneWidget);
      expect(find.byKey(const Key('beh_new_fab')), findsNothing);
      expect(repo.calls, isEmpty);
    });

    testWidgets('view-only teacher sees records but no log button', (t) async {
      repo.gradeRecords = (g) async => [rec('r1', by: 'Tess Teacher', byId: 'u')];
      await boot(t, permissions: ['behaviour:view']);
      expect(find.text('Helped a classmate'), findsOneWidget);
      expect(find.byKey(const Key('beh_new_fab')), findsNothing);
    });

    testWidgets('pull to refresh reloads', (t) async {
      repo.gradeRecords = (g) async => [rec('r1', by: 'Tess Teacher', byId: 'u')];
      await boot(t);
      await t.binding.setSurfaceSize(null);
      await t.pump();
      final before = repo.calls.length;
      await t.fling(find.byType(ListView).first, const Offset(0, 300), 1000);
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      await t.pump(const Duration(seconds: 1));
      expect(repo.calls.length, greaterThan(before));
    });
  });

  group('Quick log', () {
    Future<BehaviourLogController> boot(WidgetTester t, {List<Map<String, Object?>> assignments = const [cls5a], StudentSummary? initial, List<String>? permissions}) async {
      final h = await signIn(t, assignments: assignments, permissions: permissions);
      final list = Get.put(BehaviourController(repository: repo, students: students, auth: h.auth, permissions: h.perms));
      final c = Get.put(BehaviourLogController(repository: repo, students: students, auth: h.auth, permissions: h.perms, list: list, clock: () => now, initialStudent: initial));
      await open(t, const BehaviourNewScreen());
      await settle(t);
      return c;
    }

    testWidgets('pristine submit lists what is missing and sends nothing', (t) async {
      await boot(t);
      await t.tap(find.byKey(const Key('beh_submit')));
      await settle(t);
      expect(find.text('Choose a student'), findsWidgets);
      expect(find.text('Choose a category'), findsWidgets);
      expect(find.text('Enter a title'), findsWidgets);
      expect(find.text('Describe what happened'), findsWidgets);
      expect(repo.bodies, isEmpty);
      expect(find.byKey(const Key('parent_visible_note')), findsOneWidget);
    });

    testWidgets('picker: only my classes, class chips, search, tap selects; then the whole flow saves and leaves', (t) async {
      final c = await boot(t, assignments: [cls5a, cls6b]);
      await t.tap(find.byKey(const Key('beh_student_picker')));
      await settle(t);
      expect(find.text('Choose a student'), findsWidgets);
      expect(find.byKey(const Key('class_picker')), findsOneWidget);
      expect(find.text('First1 Last1'), findsOneWidget);
      await t.enterText(find.byKey(const Key('beh_picker_search')), 'first3');
      await t.pump();
      expect(find.text('First1 Last1'), findsNothing);
      expect(find.text('First3 Last3'), findsOneWidget);
      await t.enterText(find.byKey(const Key('beh_picker_search')), 'zzz');
      await t.pump();
      expect(find.byKey(const Key('picker_search_empty')), findsOneWidget);
      await t.enterText(find.byKey(const Key('beh_picker_search')), '');
      await t.tap(find.byKey(const ValueKey('class_chip_1')));
      await settle(t);
      await settle(t);
      expect(find.text('First30 Last30'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('class_chip_0')));
      await settle(t);
      await t.tap(find.text('First2 Last2'));
      await settle(t);
      expect(find.byKey(const Key('beh_selected_student')), findsOneWidget);
      expect(find.text('First2 Last2'), findsOneWidget);
      await t.tap(find.byKey(const Key('cat_leadership')));
      await t.pump();
      expect(c.titleC.text, 'Leadership');
      await t.enterText(find.byKey(const Key('beh_description')), 'Led the group well');
      await t.tap(find.byKey(const Key('pts_3')));
      await t.pump();
      await t.tap(find.byKey(const Key('beh_submit')));
      await settle(t);
      await t.pump(const Duration(seconds: 3));
      expect(repo.bodies.single['points'], 3);
      expect(repo.bodies.single['category'], 'leadership');
      expect(repo.bodies.single['studentName'], 'First2 Last2');
      expect(find.text('root'), findsOneWidget);
    });

    testWidgets('picker states: loading shimmer, error + Try again, empty class', (t) async {
      final gate = Completer<List<StudentSummary>>();
      students.roster = (_) => gate.future;
      await boot(t);
      await t.tap(find.byKey(const Key('beh_student_picker')));
      await t.pump();
      expect(find.byKey(const Key('picker_loading')), findsOneWidget);
      gate.completeError(ApiException('boom', statusCode: 500));
      await settle(t);
      expect(find.byKey(const Key('screen_error')), findsNothing); // the picker has its own error view
      expect(find.text('Try again'), findsOneWidget);
      students.roster = (_) async => [];
      await t.tap(find.text('Try again'));
      await settle(t);
      expect(find.byKey(const Key('picker_empty')), findsOneWidget);
    });

    testWidgets('demerit shows severity and negative points; merit has none of that', (t) async {
      await boot(t, initial: student(1));
      expect(find.byKey(const Key('sev_low')), findsNothing);
      expect(find.text('+5'), findsOneWidget);
      await t.tap(find.text('Demerit'));
      await t.pump();
      expect(find.byKey(const Key('sev_high')), findsOneWidget);
      expect(find.text('-5'), findsOneWidget);
      expect(find.byKey(const Key('cat_bullying')), findsOneWidget);
      await t.tap(find.text('Note'));
      await t.pump();
      expect(find.byKey(const Key('sev_high')), findsNothing);
      expect(find.byKey(const Key('pts_5')), findsNothing);
    });

    testWidgets('server 500 shows a calm message in a banner and keeps what was typed', (t) async {
      repo.onCreate = (b) async => throw ApiException('Internal server error', statusCode: 500);
      final c = await boot(t, initial: student(1));
      await t.tap(find.byKey(const Key('cat_leadership')));
      await t.enterText(find.byKey(const Key('beh_description')), 'Typed text survives');
      await t.tap(find.byKey(const Key('beh_submit')));
      await settle(t);
      expect(find.byKey(const Key('beh_submit_error')), findsOneWidget);
      expect(find.text('Typed text survives'), findsOneWidget);
      expect(c.saving.value, isFalse);
    });

    testWidgets('403 from the server is shown as "You can\'t save this entry"', (t) async {
      repo.onCreate = (b) async => throw ApiException('Forbidden resource', statusCode: 403);
      await boot(t, initial: student(1));
      await t.tap(find.byKey(const Key('cat_leadership')));
      await t.enterText(find.byKey(const Key('beh_description')), 'x');
      await t.tap(find.byKey(const Key('beh_submit')));
      await settle(t);
      expect(find.textContaining("You can't save this entry"), findsWidgets);
    });

    testWidgets('without behaviour:manage the screen explains instead of showing a form', (t) async {
      await boot(t, permissions: ['behaviour:view']);
      expect(find.byKey(const Key('beh_no_access')), findsOneWidget);
      expect(find.byKey(const Key('beh_submit')), findsNothing);
    });

    testWidgets('no class: explains', (t) async {
      await boot(t, assignments: const []);
      expect(find.byKey(const Key('beh_no_classes')), findsOneWidget);
    });
  });

  group('Student history', () {
    Future<BehaviourStudentController> boot(WidgetTester t, {StudentSummary? initial, String id = 'st1'}) async {
      final h = await signIn(t);
      final c = Get.put(BehaviourStudentController(studentId: id, initial: initial, repository: repo, students: students, auth: h.auth, permissions: h.perms));
      await open(t, const BehaviourStudentScreen());
      await c.load();
      await settle(t);
      return c;
    }

    const mine = StudentSummary(id: 'st1', firstName: 'Zara', lastName: 'Malik', grade: 'Grade 5', section: 'A', rollNumber: '6');

    testWidgets('records, points and Tarbiyah are shown; log button present', (t) async {
      repo.studentRecords = (id) async => [rec('r1', byId: 'u', by: 'Tess Teacher', points: 5), rec('r2', type: 'negative', points: -2, title: 'Late to class', category: 'late_coming', severity: 'medium')];
      repo.tarbiyah = (id) async => [
            TarbiyahAssessment.fromJson({
              '_id': 't1', 'studentId': 'st1', 'period': 'Term 1 2026-27', 'overallPercentage': 75, 'overallRating': 'good',
              'traits': [{'traitKey': 'sidq', 'score': 5}], 'teacherObservations': 'Kind and thoughtful', 'assessedBy': 'Clara Classteacher',
              'assessmentDate': '2026-09-15T00:00:00.000Z'
            })
          ];
      await boot(t, initial: mine);
      expect(find.text('Zara Malik'), findsOneWidget);
      expect(find.text('Grade 5 - A · Roll 6'), findsOneWidget);
      expect(find.text('Helped a classmate'), findsOneWidget);
      expect(find.text('Late to class'), findsOneWidget);
      expect(find.text('+3'), findsOneWidget); // total points
      expect(find.text('Term 1 2026-27'), findsOneWidget);
      expect(find.text('GOOD'), findsOneWidget);
      expect(find.text('Truthfulness (Sidq)'), findsOneWidget);
      expect(find.byKey(const Key('beh_student_log')), findsOneWidget);
    });

    testWidgets('empty history says so; tarbiyah empty explains it is created on the web', (t) async {
      await boot(t, initial: mine);
      expect(find.byKey(const Key('student_no_records')), findsOneWidget);
      expect(find.byKey(const Key('student_no_tarbiyah')), findsOneWidget);
    });

    testWidgets('a student outside my classes: refusal page, no record request', (t) async {
      await boot(t, initial: const StudentSummary(id: 'st9', firstName: 'Other', grade: 'Grade 7', section: 'C'), id: 'st9');
      expect(find.text("This student isn't in one of your classes"), findsOneWidget);
      expect(repo.calls, isEmpty);
      expect(find.byKey(const Key('beh_student_log')), findsNothing);
    });

    testWidgets('one section failing does not hide the other; retry reloads', (t) async {
      repo.studentRecords = (id) async => [rec('r1')];
      repo.tarbiyah = (id) async => throw ApiException('Internal server error', statusCode: 500);
      await boot(t, initial: mine);
      expect(find.text('Helped a classmate'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      repo.tarbiyah = (id) async => [];
      await t.tap(find.text('Try again'));
      await settle(t);
      await settle(t);
      expect(find.byKey(const Key('student_no_tarbiyah')), findsOneWidget);
    });
  });
}
