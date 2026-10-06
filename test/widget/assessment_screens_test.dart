// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';
import 'package:eldermin_teacher_app/app/modules/assessments/controllers/assessments_controller.dart';
import 'package:eldermin_teacher_app/app/modules/assessments/controllers/marks_entry_controller.dart';
import 'package:eldermin_teacher_app/app/modules/assessments/controllers/quiz_controllers.dart';
import 'package:eldermin_teacher_app/app/modules/assessments/controllers/report_remarks_controller.dart';
import 'package:eldermin_teacher_app/app/modules/assessments/views/assessment_detail_screen.dart';
import 'package:eldermin_teacher_app/app/modules/assessments/views/assessment_marks_screen.dart';
import 'package:eldermin_teacher_app/app/modules/assessments/views/assessment_report_remarks_screen.dart';
import 'package:eldermin_teacher_app/app/modules/assessments/views/assessments_screen.dart';
import 'package:eldermin_teacher_app/app/modules/assessments/views/quiz_attempt_detail_screen.dart';
import 'package:eldermin_teacher_app/app/modules/assessments/views/quiz_attempts_screen.dart';
import 'package:eldermin_teacher_app/app/components/custom_text.dart';
import 'package:eldermin_teacher_app/core/models/assessments/assessment_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/services/assessment_repository.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_assessment_repositories.dart';
import '../support/fake_classroom_repositories.dart';

const maths5a = {'gradeLevel': 'Grade 5', 'sectionName': 'A', 'subjectName': 'Mathematics'};

QuizAttempt attempt(String id, {String status = 'submitted', List<double?> awarded = const [null, null], double? obtained}) => QuizAttempt.fromJson({
      '_id': id,
      'studentName': 'Aarav Ahmed',
      'assessmentTitle': 'Online Quiz',
      'subject': 'Mathematics',
      'grade': 'Grade 5',
      'section': 'A',
      'totalMarks': 10,
      'autoGradedMarks': 2,
      'obtainedMarks': obtained,
      'status': status,
      'submittedAt': '2026-10-03T08:30:00.000Z',
      'answers': [
        {'questionId': 'q1', 'selectedOptionIndex': 0, 'needsManualGrading': false, 'isCorrect': true, 'marksAwarded': 2, 'question': {'_id': 'q1', 'type': 'mcq', 'questionText': 'What is 1/2 + 1/4?', 'marks': 2, 'options': [{'text': '3/4', 'isCorrect': true}, {'text': '2/6', 'isCorrect': false}]}},
        {'questionId': 'q2', 'textAnswer': 'Make the bottoms the same', 'needsManualGrading': true, 'marksAwarded': awarded[0], 'question': {'_id': 'q2', 'type': 'short', 'questionText': 'Explain adding fractions', 'marks': 4, 'correctAnswer': 'common denominator'}},
        {'questionId': 'q3', 'textAnswer': '3/8 left', 'needsManualGrading': true, 'marksAwarded': awarded[1], 'question': {'_id': 'q3', 'type': 'long', 'questionText': 'Pizza problem', 'marks': 4}},
      ],
    });

ReportCard card(String id, {bool published = false, String remarks = '', String principal = ''}) => ReportCard.fromJson({
      '_id': id,
      'studentName': 'Student $id',
      'rollNumber': '1',
      'grade': 'Grade 5',
      'section': 'A',
      'published': published,
      'classPosition': 1,
      'totalStudents': 12,
      'overallPercentage': 78.5,
      'overallGrade': 'B+',
      'classTeacherRemarks': remarks,
      'principalRemarks': principal,
    });

const adminWords = ['Publish results', 'Generate report', 'Verify marks', 'Verify all', 'Delete', 'Create assessment', 'New assessment', 'Cancel assessment', 'Start assessment', 'Issue book', 'Return book', 'Pay fine', 'Reserve'];

void main() {
  late FakeAssessmentRepository repo;
  late FakeStudentsRepository students;
  late Assessment a1;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakeAssessmentRepository();
    students = FakeStudentsRepository();
    a1 = asm('a1');
    repo.onOne = (_) async => a1;
    students.roster = (_) async => [for (var i = 1; i <= 5; i++) student(i)];
  });
  tearDown(Get.reset);

  Future<dynamic> signIn(WidgetTester t, {List<Map<String, Object?>> assignments = const [maths5a], bool classTeacher = false, List<String>? permissions}) async {
    return (await t.runAsync(() async {
      final h = await signedIn(classTeacher: classTeacher, permissions: permissions);
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

  Future<void> drain(WidgetTester t) async => t.pump(const Duration(seconds: 3));

  Future<void> goBack(WidgetTester t) async {
    await t.binding.handlePopRoute();
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    await t.pump(const Duration(milliseconds: 600));
  }

  void noAdminActions() {
    for (final w in adminWords) {
      expect(find.textContaining(w), findsNothing, reason: 'admin action "$w" must not be offered');
    }
  }

  AssessmentsController putList(dynamic h) => Get.put(AssessmentsController(repository: repo, auth: h.auth, permissions: h.perms));

  group('Assessments list', () {
    testWidgets('tiles with type, class, date, status tags, my subject; filter chips with counts; quiz card; no admin actions', (t) async {
      final h = await signIn(t);
      repo.onList = () async => AllPages([
            asm('a1', title: 'Unit Test 1', start: '2026-10-05'),
            asm('a2', title: 'Mid-Term', type: 'mid_term', status: 'completed', section: null, subjects: const [('Mathematics', 100, 40)], start: '2026-09-20'),
            asm('a3', title: 'Final', type: 'final_exam', status: 'scheduled', start: '2026-12-01'),
            asm('a4', title: 'Term 1', status: 'result_published', published: true, start: '2026-08-01'),
            asm('a5', title: 'Quiz online', type: 'quiz', online: true, paperOn: 'Mathematics', start: '2026-10-01'),
            asm('a6', title: 'Grade 9 test', grade: 'Grade 9'),
          ]);
      final c = putList(h);
      await open(t, const AssessmentsScreen());
      await c.load();
      await settle(t);
      expect(find.text('Unit Test 1'), findsOneWidget);
      expect(find.text('Grade 9 test'), findsNothing);
      expect(find.text('Unit test · Grade 5 - A · Term 1'), findsOneWidget);
      expect(find.text('5 Oct 2026'), findsOneWidget);
      expect(find.text('ONGOING'), findsWidgets);
      expect(find.text('Mathematics · out of 50'), findsNWidgets(2)); // Unit Test 1 and the online quiz
      expect(find.text('Marks open  3'), findsOneWidget);
      expect(find.text('Upcoming  1'), findsOneWidget);
      expect(find.text('Published  1'), findsOneWidget);
      expect(find.text('All  5'), findsOneWidget);
      expect(find.byKey(const Key('asm_quiz_card')), findsOneWidget);
      expect(find.byKey(const Key('asm_remarks_card')), findsNothing); // not a class teacher
      expect(find.text('Final'), findsNothing); // upcoming is not in the default filter
      await t.tap(find.byKey(const Key('chip_upcoming')));
      await settle(t);
      expect(find.text('Final'), findsOneWidget);
      expect(find.text('SCHEDULED'), findsOneWidget);
      await t.tap(find.byKey(const Key('chip_published')));
      await settle(t);
      expect(find.text('RESULTS PUBLISHED'), findsOneWidget);
      await t.tap(find.byKey(const Key('chip_all')));
      await settle(t);
      expect(find.text('ONLINE QUIZ'), findsOneWidget);
      noAdminActions();
    });

    testWidgets('class teacher sees the report-remarks card and a view-only tile', (t) async {
      final h = await signIn(t, assignments: const [], classTeacher: true);
      repo.onList = () async => AllPages([asm('a1', title: 'Unit Test 1')]);
      final c = putList(h);
      await open(t, const AssessmentsScreen());
      await c.load();
      await settle(t);
      expect(find.byKey(const Key('asm_remarks_card')), findsOneWidget);
      expect(find.text('View only · you are the class teacher'), findsOneWidget);
    });

    testWidgets('loading shimmer, empty, error + Try again, 403, truncated notice, empty filter, pull to refresh', (t) async {
      final h = await signIn(t);
      final gate = Completer<AllPages<Assessment>>();
      repo.onList = () => gate.future;
      final c = putList(h);
      await open(t, const AssessmentsScreen());
      unawaited(c.load());
      await t.pump();
      expect(find.byKey(const Key('screen_loading')), findsOneWidget);
      gate.complete(const AllPages([]));
      await settle(t);
      expect(find.text('No assessments for your classes yet'), findsOneWidget);
      repo.onList = () async => throw ApiException('Internal server error', statusCode: 500);
      await c.load(force: true);
      await settle(t);
      expect(find.byKey(const Key('screen_error')), findsOneWidget);
      repo.onList = () async => AllPages([asm('a1', title: 'Back again')], truncated: true);
      await t.tap(find.text('Try again'));
      await settle(t);
      expect(find.text('Back again'), findsOneWidget);
      expect(find.byKey(const Key('asm_truncated')), findsOneWidget);
      await t.tap(find.byKey(const Key('chip_published')));
      await settle(t);
      expect(find.byKey(const Key('asm_filter_empty')), findsOneWidget);
      final before = repo.calls.length;
      await t.binding.setSurfaceSize(null);
      await t.pump();
      await t.fling(find.byType(ListView).first, const Offset(0, 300), 1000);
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      await t.pump(const Duration(seconds: 1));
      expect(repo.calls.length, greaterThan(before));
      repo.onList = () async => throw ApiException('Forbidden resource', statusCode: 403);
      await c.load(force: true);
      await settle(t);
      expect(find.text("You don't have access"), findsOneWidget);
      expect(find.byKey(const Key('asm_quiz_card')), findsNothing);
    });
  });

  group('Assessment detail', () {
    Future<void> boot(WidgetTester t, Assessment a, {bool classTeacher = false, List<Map<String, Object?>> assignments = const [maths5a]}) async {
      final h = await signIn(t, classTeacher: classTeacher, assignments: assignments);
      repo.onList = () async => AllPages([a]);
      final l = putList(h);
      final d = Get.put(AssessmentDetailController(id: a.id, list: l, repository: repo));
      await open(t, const AssessmentDetailScreen());
      await d.load();
      await settle(t);
    }

    testWidgets('my subject: Enter marks; colleague\'s subject: no action; title, class, date, totals', (t) async {
      await boot(t, asm('a1', title: 'Unit Test 1', subjects: const [('Mathematics', 50, 20), ('English', 30, 12)]));
      expect(find.text('Unit Test 1'), findsOneWidget);
      expect(find.text('Out of 50 · pass 20'), findsOneWidget);
      expect(find.text('YOUR SUBJECT'), findsOneWidget);
      expect(find.byKey(const Key('asm_marks_Mathematics')), findsOneWidget);
      expect(find.byKey(const Key('asm_marks_English')), findsNothing);
      expect(find.byKey(const Key('asm_view_English')), findsNothing);
      noAdminActions();
    });

    testWidgets('results published: Enter marks stays available with a non-blocking warning', (t) async {
      await boot(t, asm('a1', status: 'result_published', published: true));
      expect(find.byKey(const Key('asm_marks_Mathematics')), findsOneWidget);
      expect(find.byKey(const Key('asm_warn_Mathematics')), findsOneWidget);
      expect(find.textContaining('Results are published; changes may affect published results'), findsOneWidget);
      expect(find.byKey(const Key('asm_locked_Mathematics')), findsNothing);
    });

    for (final status in ['scheduled', 'draft', 'ongoing']) {
      testWidgets('$status: Enter marks is offered, no gate text, no warning', (t) async {
        await boot(t, asm('a1', status: status));
        expect(find.byKey(const Key('asm_marks_Mathematics')), findsOneWidget);
        expect(find.byKey(const Key('asm_warn_Mathematics')), findsNothing);
        expect(find.textContaining('still scheduled'), findsNothing);
        expect(find.textContaining('once the assessment has started'), findsNothing);
      });
    }

    testWidgets('online quiz subject: review quiz answers instead of a grid', (t) async {
      await boot(t, asm('a1', online: true, paperOn: 'Mathematics', type: 'quiz'));
      expect(find.byKey(const Key('asm_quiz_Mathematics')), findsOneWidget);
      expect(find.byKey(const Key('asm_marks_Mathematics')), findsNothing);
    });

    testWidgets('report-card remarks entry only for the class teacher once cards exist', (t) async {
      await boot(t, asm('a1', cards: true, status: 'completed'), classTeacher: true);
      expect(find.byKey(const Key('asm_detail_remarks')), findsOneWidget);
    });

    testWidgets('an assessment that is not mine shows an explanation, nothing else', (t) async {
      final h = await signIn(t);
      repo.onList = () async => const AllPages([]);
      repo.onOne = (_) async => asm('zz', grade: 'Grade 9', section: 'Z');
      final l = putList(h);
      final d = Get.put(AssessmentDetailController(id: 'zz', list: l, repository: repo));
      await open(t, const AssessmentDetailScreen());
      await d.load();
      await settle(t);
      expect(find.text("This assessment isn't one of yours."), findsOneWidget);
    });
  });

  group('Marks entry screen', () {
    Future<MarksEntryController> boot(WidgetTester t, {List<MarkRecord> marks = const [], bool classTeacher = false, List<Map<String, Object?>> assignments = const [maths5a]}) async {
      final h = await signIn(t, classTeacher: classTeacher, assignments: assignments);
      repo.onMarks = (_, __) async => AllPages(marks);
      final c = Get.put(MarksEntryController(assessmentId: 'a1', subject: 'Mathematics', repository: repo, students: students, auth: h.auth, permissions: h.perms));
      await open(t, const AssessmentMarksScreen());
      await c.load();
      await settle(t);
      return c;
    }

    String idOf(int i) => student(i).id;

    testWidgets('roster rows with roll number and name, saved marks prefilled, absent / exempt toggles, header with total and pass mark', (t) async {
      final c = await boot(t, marks: [mark(student(1), 42.5), mark(student(2), null, absent: true)]);
      expect(find.text('Unit Test'), findsOneWidget);
      expect(find.textContaining('Mathematics · Grade 5 - A · out of 50 · pass 20 · 5 students'), findsOneWidget);
      expect(find.text('First1 Last1'), findsOneWidget);
      expect(find.text('First5 Last5'), findsOneWidget);
      expect(t.widget<TextField>(find.byKey(Key('marks_field_${idOf(1)}'))).controller!.text, '42.5');
      expect(t.widget<TextField>(find.byKey(Key('marks_field_${idOf(2)}'))).enabled, isFalse); // absent
      expect(find.byKey(Key('absent_${idOf(3)}')), findsOneWidget);
      expect(find.byKey(Key('exempt_${idOf(3)}')), findsOneWidget);
      expect(find.byKey(const Key('marks_dirty_count')), findsOneWidget);
      expect(find.text('No changes yet'), findsOneWidget);
      expect(c.editable, isTrue);
      noAdminActions();
    });

    testWidgets('typing marks updates the unsaved count; a mark below the pass mark is flagged; absent clears the field', (t) async {
      final c = await boot(t);
      await t.enterText(find.byKey(Key('marks_field_${idOf(1)}')), '12');
      await t.pump();
      expect(find.text('1 unsaved change'), findsOneWidget);
      expect(find.text('Below the pass mark'), findsOneWidget);
      await t.tap(find.byKey(Key('absent_${idOf(1)}')));
      await t.pump();
      expect(t.widget<TextField>(find.byKey(Key('marks_field_${idOf(1)}'))).controller!.text, '');
      expect(c.rows.first.absent, isTrue);
    });

    testWidgets('Save with a mark above the total: the error is shown on the row, a banner counts it, no summary, no request', (t) async {
      await boot(t);
      await t.enterText(find.byKey(Key('marks_field_${idOf(1)}')), '51');
      await t.enterText(find.byKey(Key('marks_field_${idOf(2)}')), '30');
      await t.pump();
      expect(find.byKey(Key('marks_error_${idOf(1)}')), findsNothing); // not before the first Save
      await t.tap(find.byKey(const Key('marks_save_button')));
      await settle(t);
      expect(find.text("Can't be more than 50."), findsOneWidget);
      expect(find.byKey(const Key('marks_invalid_banner')), findsOneWidget);
      expect(find.byKey(const Key('marks_confirm_save')), findsNothing);
      expect(repo.saves, isEmpty);
      await drain(t);
    });

    testWidgets('Save shows the summary (entered / absent / exempt / average / lowest / highest); Keep editing cancels; Save sends and reports', (t) async {
      final c = await boot(t, marks: [mark(student(1), 40)]);
      await t.enterText(find.byKey(Key('marks_field_${idOf(2)}')), '30');
      await t.tap(find.byKey(Key('absent_${idOf(3)}')));
      await t.tap(find.byKey(Key('exempt_${idOf(4)}')));
      await t.pump();
      await t.tap(find.byKey(const Key('marks_save_button')));
      await settle(t);
      expect(find.text('Before you save'), findsOneWidget);
      expect(t.widget<CustomText>(find.byKey(const Key('sum_entered'))).text, '2');
      expect(t.widget<CustomText>(find.byKey(const Key('sum_absent'))).text, '1');
      expect(t.widget<CustomText>(find.byKey(const Key('sum_exempt'))).text, '1');
      expect(t.widget<CustomText>(find.byKey(const Key('sum_missing'))).text, '1');
      expect(t.widget<CustomText>(find.byKey(const Key('sum_avg'))).text, '35');
      expect(t.widget<CustomText>(find.byKey(const Key('sum_min'))).text, '30');
      expect(t.widget<CustomText>(find.byKey(const Key('sum_max'))).text, '40');
      expect(find.textContaining('This saves 3 students (3 new, 0 changed)'), findsOneWidget);
      await t.tap(find.byKey(const Key('marks_cancel_save')));
      await settle(t);
      expect(repo.saves, isEmpty);
      expect(c.hasUnsavedChanges, isTrue);
      await t.tap(find.byKey(const Key('marks_save_button')));
      await settle(t);
      await t.tap(find.byKey(const Key('marks_confirm_save')));
      await settle(t);
      expect(repo.saves, hasLength(1));
      expect(repo.saves.single.marks, hasLength(3));
      expect(find.text('Saved marks for 3 students'), findsOneWidget);
      expect(find.text('No changes yet'), findsOneWidget);
      await drain(t);
    });

    testWidgets('save fails offline: the typed marks stay, a banner explains and Retry resends', (t) async {
      await boot(t);
      await t.enterText(find.byKey(Key('marks_field_${idOf(1)}')), '30');
      await t.pump();
      var fail = true;
      repo.onSave = (_) async {
        if (fail) throw ApiException('No internet connection.');
      };
      await t.tap(find.byKey(const Key('marks_save_button')));
      await settle(t);
      await t.tap(find.byKey(const Key('marks_confirm_save')));
      await settle(t);
      expect(find.byKey(const Key('marks_save_error')), findsOneWidget);
      expect(find.textContaining('Your marks are kept'), findsOneWidget);
      expect(t.widget<TextField>(find.byKey(Key('marks_field_${idOf(1)}'))).controller!.text, '30');
      fail = false;
      await t.tap(find.text('Retry'));
      await settle(t);
      expect(repo.saves, hasLength(2));
      expect(find.byKey(const Key('marks_save_error')), findsNothing);
      await drain(t);
    });

    testWidgets('server 400 names the row: the message appears on that student', (t) async {
      await boot(t);
      await t.enterText(find.byKey(Key('marks_field_${idOf(1)}')), '10');
      await t.enterText(find.byKey(Key('marks_field_${idOf(2)}')), '20');
      await t.pump();
      repo.onSave = (_) async => throw ApiException('marks.1.obtainedMarks must not be less than 0', statusCode: 400);
      await t.tap(find.byKey(const Key('marks_save_button')));
      await settle(t);
      await t.tap(find.byKey(const Key('marks_confirm_save')));
      await settle(t);
      expect(find.byKey(Key('marks_error_${idOf(2)}')), findsOneWidget);
      expect(find.byKey(Key('marks_error_${idOf(1)}')), findsNothing);
      await drain(t);
    });

    testWidgets('verified rows are locked and say so; the sheet note explains; typing is impossible', (t) async {
      await boot(t, marks: [mark(student(1), 40, verified: true), mark(student(2), 30)]);
      expect(find.byKey(const Key('marks_locked_note')), findsOneWidget);
      expect(find.textContaining('1 mark is verified'), findsOneWidget);
      expect(find.byKey(Key('marks_lock_${idOf(1)}')), findsOneWidget);
      expect(t.widget<TextField>(find.byKey(Key('marks_field_${idOf(1)}'))).enabled, isFalse);
      expect(t.widget<TextField>(find.byKey(Key('marks_field_${idOf(2)}'))).enabled, isTrue);
    });

    testWidgets('all verified: no Save button at all', (t) async {
      await boot(t, marks: [for (var i = 1; i <= 5; i++) mark(student(i), 20, verified: true)]);
      expect(find.byKey(const Key('marks_save_button')), findsNothing);
      expect(find.textContaining('All 5 marks are verified'), findsOneWidget);
    });

    testWidgets('results published: warning banner, fields stay editable, Save works', (t) async {
      a1 = asm('a1', status: 'result_published', published: true);
      await boot(t, marks: [mark(student(1), 40)]);
      expect(find.byKey(const Key('marks_status_warning')), findsOneWidget);
      expect(find.byKey(const Key('marks_access_note')), findsNothing);
      expect(find.textContaining('Results are published; changes may affect published results'), findsOneWidget);
      expect(t.widget<TextField>(find.byKey(Key('marks_field_${idOf(1)}'))).enabled, isTrue);
      await t.enterText(find.byKey(Key('marks_field_${idOf(1)}')), '41');
      await t.pump();
      expect(find.byKey(const Key('marks_save_button')), findsOneWidget);
      expect(find.text('Enter marks'), findsOneWidget); // app bar
    });

    testWidgets('a scheduled assessment: no gate, no warning, fields editable', (t) async {
      a1 = asm('a1', status: 'scheduled');
      await boot(t, marks: [mark(student(1), 40)]);
      expect(find.byKey(const Key('marks_status_warning')), findsNothing);
      expect(find.byKey(const Key('marks_access_note')), findsNothing);
      expect(t.widget<TextField>(find.byKey(Key('marks_field_${idOf(1)}'))).enabled, isTrue);
    });

    testWidgets('403 "verified and locked": message shown, the row locks, NO Retry button', (t) async {
      await boot(t, marks: [mark(student(2), 30)]);
      await t.enterText(find.byKey(Key('marks_field_${idOf(1)}')), '10');
      await t.pump();
      repo.onSave = (_) async => throw ApiException('Marks for 1 students are verified and locked: Student 1', statusCode: 403);
      repo.onMarks = (_, __) async => AllPages([mark(student(1), 25, verified: true)]);
      await t.tap(find.byKey(const Key('marks_save_button')));
      await settle(t);
      await t.tap(find.byKey(const Key('marks_confirm_save')));
      await settle(t);
      expect(find.byKey(const Key('marks_save_error')), findsOneWidget);
      expect(find.textContaining('verified and locked'), findsWidgets);
      expect(find.widgetWithText(TextButton, 'Retry'), findsNothing);
      expect(find.byKey(Key('marks_lock_${idOf(1)}')), findsOneWidget);
      await drain(t);
    });

    testWidgets('a saved mark already above the total shows a warning', (t) async {
      await boot(t, marks: [mark(student(1), 80)]);
      expect(find.byKey(Key('marks_warning_${idOf(1)}')), findsOneWidget);
    });

    testWidgets('empty roster, error + Try again, 403, shimmer', (t) async {
      final h = await signIn(t);
      final gate = Completer<List<dynamic>>();
      students.roster = (_) async => (await gate.future).cast();
      repo.onMarks = (_, __) async => const AllPages([]);
      final c = Get.put(MarksEntryController(assessmentId: 'a1', subject: 'Mathematics', repository: repo, students: students, auth: h.auth, permissions: h.perms));
      await open(t, const AssessmentMarksScreen());
      unawaited(c.load());
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('screen_loading')), findsOneWidget);
      gate.complete([]);
      await settle(t);
      expect(find.text('No students in this class'), findsOneWidget);
      students.roster = (_) async => throw ApiException('Internal server error', statusCode: 500);
      await c.load(force: true);
      await settle(t);
      expect(find.byKey(const Key('screen_error')), findsOneWidget);
      students.roster = (_) async => [student(1)];
      await t.tap(find.text('Try again'));
      await settle(t);
      expect(find.text('First1 Last1'), findsOneWidget);
      students.roster = (_) async => throw ApiException('Forbidden resource', statusCode: 403);
      await c.load(force: true);
      await settle(t);
      expect(find.text("You don't have access"), findsOneWidget);
    });

    testWidgets('unsaved-changes guard: back with edits asks first; Stay keeps the marks, Leave goes back; no edits = no question', (t) async {
      final c = await boot(t);
      await t.enterText(find.byKey(Key('marks_field_${idOf(1)}')), '10');
      await t.pump();
      await goBack(t);
      expect(find.text('Leave without saving?'), findsOneWidget);
      await t.tap(find.byKey(const Key('confirm_dialog_cancel')));
      await settle(t);
      expect(find.byType(AssessmentMarksScreen), findsOneWidget);
      expect(c.hasUnsavedChanges, isTrue);
      await goBack(t);
      await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
      await goBack(t);
      expect(find.byType(AssessmentMarksScreen), findsNothing);
    });

    testWidgets('no edits: back leaves at once', (t) async {
      await boot(t);
      await goBack(t);
      expect(find.text('Leave without saving?'), findsNothing);
      expect(find.byType(AssessmentMarksScreen), findsNothing);
    });

    testWidgets('several classes: chips switch; an unsaved edit asks before switching', (t) async {
      a1 = asm('a1', section: null);
      final h = await signIn(t, assignments: const [maths5a, {'gradeLevel': 'Grade 5', 'sectionName': 'B', 'subjectName': 'Mathematics'}]);
      students.roster = (cls) async => [student(cls.section == 'A' ? 1 : 2, section: cls.section)];
      repo.onMarks = (_, __) async => const AllPages([]);
      final c = Get.put(MarksEntryController(assessmentId: 'a1', subject: 'Mathematics', repository: repo, students: students, auth: h.auth, permissions: h.perms));
      await open(t, const AssessmentMarksScreen());
      await c.load();
      await settle(t);
      expect(find.text('Grade 5 - A'), findsWidgets);
      await t.enterText(find.byKey(Key('marks_field_${idOf(1)}')), '10');
      await t.tap(find.byKey(const Key('chip_class1')));
      await settle(t);
      expect(find.text('Switch class?'), findsOneWidget);
      await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
      await settle(t);
      expect(find.text('First2 Last2'), findsOneWidget);
      expect(c.hasUnsavedChanges, isFalse);
    });

    testWidgets('a 230-student class renders (lazily) and counts all', (t) async {
      students.roster = (_) async => [for (var i = 1; i <= 230; i++) student(i)];
      final c = await boot(t);
      expect(c.rows, hasLength(230));
      expect(find.text('First1 Last1'), findsOneWidget);
      expect(find.text('First230 Last230'), findsNothing); // below the fold: built lazily
    });
  });

  group('Report remarks screen', () {
    Future<ReportRemarksController> boot(WidgetTester t, {bool classTeacher = true, List<ReportCard>? cards}) async {
      final h = await signIn(t, assignments: const [], classTeacher: classTeacher);
      repo.onList = () async => AllPages([asm('a2', title: 'Mid-Term', cards: true, status: 'completed', section: null)]);
      repo.onCards = (_) async => AllPages(cards ?? [card('c1', remarks: 'Works hard', principal: 'Well done'), card('c2'), card('c3', published: true, remarks: 'Published remark')]);
      final l = putList(h);
      final c = Get.put(ReportRemarksController(repository: repo, list: l));
      await open(t, const AssessmentReportRemarksScreen());
      await c.load();
      await settle(t);
      return c;
    }

    testWidgets('editable cards for my class, principal remarks read-only, published card read-only, no generate / publish', (t) async {
      await boot(t);
      expect(find.text('Mid-Term'), findsOneWidget);
      expect(find.byKey(const Key('remarks_input_c1')), findsOneWidget);
      expect(t.widget<TextField>(find.byKey(const Key('remarks_input_c1'))).controller!.text, 'Works hard');
      expect(find.text('Principal: Well done'), findsOneWidget);
      expect(find.byKey(const Key('remarks_input_c3')), findsNothing);
      expect(find.byKey(const Key('remarks_read_c3')), findsOneWidget);
      expect(find.text('PUBLISHED'), findsOneWidget);
      expect(find.text('Published report cards are read-only.'), findsOneWidget);
      noAdminActions();
    });

    testWidgets('save is enabled only after a change; saving sends only the class-teacher text', (t) async {
      await boot(t);
      expect(t.widget<TextButton>(find.byKey(const Key('remarks_save_c2'))).onPressed, isNull);
      await t.enterText(find.byKey(const Key('remarks_input_c2')), 'Good term');
      await t.pump();
      await t.tap(find.byKey(const Key('remarks_save_c2')));
      await settle(t);
      expect(repo.remarks.single, (id: 'c2', text: 'Good term'));
      expect(find.text('Remarks saved'), findsOneWidget);
      await drain(t);
    });

    testWidgets('a failed save keeps the text and shows the reason', (t) async {
      await boot(t);
      repo.onRemarks = (_, __) async => throw ApiException('Forbidden resource', statusCode: 403);
      await t.enterText(find.byKey(const Key('remarks_input_c2')), 'Text');
      await t.pump();
      await t.tap(find.byKey(const Key('remarks_save_c2')));
      await settle(t);
      expect(find.byKey(const Key('remarks_error_c2')), findsOneWidget);
      expect(t.widget<TextField>(find.byKey(const Key('remarks_input_c2'))).controller!.text, 'Text');
    });

    testWidgets('not a class teacher: honest empty state; 403 on the cards: no access', (t) async {
      await boot(t, classTeacher: false);
      expect(find.text('No report cards to comment on yet'), findsOneWidget);
      expect(find.text('Remarks are written by the class teacher of a class.'), findsOneWidget);
    });

    testWidgets('403 on cards and error + retry', (t) async {
      final c = await boot(t);
      repo.onCards = (_) async => throw ApiException('Forbidden resource', statusCode: 403);
      await c.load(force: true);
      await settle(t);
      expect(find.text("You don't have access"), findsOneWidget);
      repo.onCards = (_) async => throw ApiException('x', statusCode: 500);
      await c.load(force: true);
      await settle(t);
      expect(find.byKey(const Key('screen_error')), findsOneWidget);
    });
  });

  group('Quiz grading screens', () {
    Future<QuizAttemptsController> bootList(WidgetTester t) async {
      final h = await signIn(t);
      final c = Get.put(QuizAttemptsController(repository: repo, auth: h.auth, permissions: h.perms));
      await open(t, const QuizAttemptsScreen());
      await c.load();
      await settle(t);
      return c;
    }

    testWidgets('queue: student, quiz, subject, class, answers to mark; empty; error; 403', (t) async {
      repo.onPending = () async => [attempt('t1'), attempt('t2', awarded: [3, null])];
      final c = await bootList(t);
      expect(find.text('Aarav Ahmed'), findsNWidgets(2));
      expect(find.text('2 ANSWERS TO MARK'), findsOneWidget);
      expect(find.text('1 ANSWER TO MARK'), findsOneWidget);
      expect(find.textContaining('Online Quiz · Mathematics · Grade 5 - A'), findsNWidgets(2));
      repo.onPending = () async => [];
      await c.load(force: true);
      await settle(t);
      expect(find.text('Nothing waiting for your marks'), findsOneWidget);
      expect(find.textContaining('Only attempts from your classes'), findsOneWidget);
      repo.onPending = () async => throw ApiException('Forbidden resource', statusCode: 403);
      await c.load(force: true);
      await settle(t);
      expect(find.text("You don't have access"), findsOneWidget);
      repo.onPending = () async => throw ApiException('x', statusCode: 500);
      await c.load(force: true);
      await settle(t);
      expect(find.byKey(const Key('screen_error')), findsOneWidget);
    });

    Future<QuizAttemptDetailController> bootDetail(WidgetTester t, QuizAttempt a) async {
      final h = await signIn(t);
      repo.onPending = () async => [a];
      final list = Get.put(QuizAttemptsController(repository: repo, auth: h.auth, permissions: h.perms));
      await list.load();
      repo.onAttempt = (_) async => a;
      final d = Get.put(QuizAttemptDetailController(id: a.id, list: list, repository: repo));
      await open(t, const QuizAttemptDetailScreen());
      await d.load();
      await settle(t);
      return d;
    }

    testWidgets('shows the questions, the answer key, how marking works; mark inputs with maximums', (t) async {
      await bootDetail(t, attempt('t1'));
      expect(find.text('What is 1/2 + 1/4?'), findsOneWidget);
      expect(find.textContaining('(correct)'), findsOneWidget);
      expect(find.text('CORRECT'), findsOneWidget);
      expect(find.text('Make the bottoms the same'), findsOneWidget);
      expect(find.text('Model answer: common denominator'), findsOneWidget);
      expect(find.byKey(const Key('qa_effect_note')), findsOneWidget);
      expect(find.text('out of 4'), findsNWidgets(2));
      expect(find.text('0 of 2 marked'), findsOneWidget);
    });

    testWidgets('a mark above the question maximum is flagged at once and blocks saving', (t) async {
      await bootDetail(t, attempt('t1'));
      await t.enterText(find.descendant(of: find.byKey(const Key('qa_mark_q2')), matching: find.byType(TextField)), '5');
      await t.pump();
      expect(find.byKey(const Key('qa_mark_error_q2')), findsOneWidget);
      expect(find.text("Can't be more than 4."), findsOneWidget);
      await t.tap(find.byKey(const Key('qa_submit')));
      await settle(t);
      expect(repo.grades, isEmpty);
      await drain(t);
    });

    testWidgets('partial marks ask for confirmation, then save and stay; completing shows the total and finishes', (t) async {
      final d = await bootDetail(t, attempt('t1'));
      repo.onGrade = (id, g) async => attempt(id, awarded: [3, null]);
      await t.enterText(find.descendant(of: find.byKey(const Key('qa_mark_q2')), matching: find.byType(TextField)), '3');
      await t.pump();
      await t.tap(find.byKey(const Key('qa_submit')));
      await settle(t);
      expect(find.text('Save partial marks?'), findsOneWidget);
      await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
      await settle(t);
      expect(repo.grades.single.grades, [(questionId: 'q2', marks: 3.0)]);
      expect(find.text('Marks saved'), findsOneWidget);
      await drain(t);
      await t.enterText(find.descendant(of: find.byKey(const Key('qa_mark_q3')), matching: find.byType(TextField)), '2');
      await t.pump();
      expect(find.text('Total 7 / 10'), findsOneWidget);
      repo.onGrade = (id, g) async => attempt(id, status: 'graded', awarded: [3, 2], obtained: 7);
      await t.tap(find.byKey(const Key('qa_submit')));
      await settle(t);
      expect(find.text('Finish grading?'), findsOneWidget);
      expect(find.textContaining('replaces any mark already entered'), findsOneWidget);
      await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
      await settle(t);
      expect(d.state.value.data!.isGraded, isTrue);
      await drain(t);
    });

    testWidgets('a failed save keeps the marks and offers Retry', (t) async {
      await bootDetail(t, attempt('t1'));
      repo.onGrade = (id, g) async => throw ApiException('Forbidden resource', statusCode: 403);
      await t.enterText(find.descendant(of: find.byKey(const Key('qa_mark_q2')), matching: find.byType(TextField)), '3');
      await t.pump();
      await t.tap(find.byKey(const Key('qa_submit')));
      await settle(t);
      await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
      await settle(t);
      expect(find.byKey(const Key('qa_error')), findsOneWidget);
      expect(find.textContaining("You can't save these marks"), findsOneWidget);
      expect(t.widget<TextField>(find.descendant(of: find.byKey(const Key('qa_mark_q2')), matching: find.byType(TextField))).controller!.text, '3');
      await drain(t);
    });

    testWidgets('an already graded attempt is read-only with the reason', (t) async {
      await bootDetail(t, attempt('t1', status: 'graded', awarded: [3, 2], obtained: 7));
      expect(find.byKey(const Key('qa_graded_note')), findsOneWidget);
      expect(find.byKey(const Key('qa_submit')), findsNothing);
      expect(t.widget<TextField>(find.descendant(of: find.byKey(const Key('qa_mark_q2')), matching: find.byType(TextField))).enabled, isFalse);
    });
  });
}
