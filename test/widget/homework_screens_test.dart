// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';
import 'package:eldermin_teacher_app/app/modules/homework/controllers/homework_controller.dart';
import 'package:eldermin_teacher_app/app/modules/homework/controllers/homework_detail_controller.dart';
import 'package:eldermin_teacher_app/app/modules/homework/controllers/homework_form_controller.dart';
import 'package:eldermin_teacher_app/app/modules/homework/controllers/submissions_controller.dart';
import 'package:eldermin_teacher_app/app/modules/homework/views/homework_detail_screen.dart';
import 'package:eldermin_teacher_app/app/modules/homework/views/homework_grade_screen.dart';
import 'package:eldermin_teacher_app/app/modules/homework/views/homework_new_screen.dart';
import 'package:eldermin_teacher_app/app/modules/homework/views/homework_screen.dart';
import 'package:eldermin_teacher_app/app/modules/homework/views/homework_submissions_screen.dart';
import 'package:eldermin_teacher_app/core/models/homework/homework_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/services/attachment_picker.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_classroom_repositories.dart';
import '../support/fake_phase5b_repositories.dart';

final now = DateTime(2026, 10, 5, 9, 30);

void main() {
  late FakeHomeworkRepository repo;
  late FakeStudentsRepository students;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakeHomeworkRepository();
    students = FakeStudentsRepository()..roster = (_) async => [student(1), student(2)];
  });
  tearDown(Get.reset);

  Future<({dynamic h})> signIn(WidgetTester t, {List<Map<String, Object?>> assignments = const [
    {'gradeLevel': 'Grade 5', 'sectionName': 'A', 'subjectName': 'Mathematics'}
  ], List<String>? permissions}) async {
    final h = (await t.runAsync(() async {
      final h = await signedIn(permissions: permissions);
      h.api.assignments = assignments;
      await h.auth.refreshProfile(force: true);
      return h;
    }))!;
    return (h: h);
  }

  HomeworkController list(dynamic h) => Get.put(HomeworkController(repository: repo, auth: h.auth, permissions: h.perms, clock: () => now));

  /// Root page + the screen pushed on top (so Get.back() has somewhere to go).
  Future<void> open(WidgetTester t, Widget screen, {Size size = const Size(430, 4000)}) async {
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

  group('Homework list', () {
    testWidgets('data: tiles with phase tags, due text and handed-in counts; filter chips narrow it', (t) async {
      final s = await signIn(t);
      repo.mine = (_) async => [
            asg('a1', title: 'Chapter 3 worksheet', due: '2026-10-07', count: 4),
            asg('a2', title: 'Lab report', status: 'overdue', due: '2026-10-03', subject: 'Science'),
            asg('a3', title: 'Draft quiz', status: 'draft', due: '2026-10-12'),
            asg('a4', title: 'Due now', due: '2026-10-05'),
          ];
      final c = list(s.h);
      await open(t, const HomeworkScreen());
      await c.load();
      await settle(t);
      expect(find.text('Chapter 3 worksheet'), findsOneWidget);
      expect(find.text('Due Wed 7 Oct'), findsOneWidget);
      expect(find.text('4 handed in'), findsOneWidget);
      expect(find.text('OVERDUE'), findsOneWidget);
      expect(find.text('Overdue by 2 days'), findsOneWidget);
      expect(find.text('DRAFT'), findsOneWidget);
      expect(find.text('DUE TODAY'), findsOneWidget);
      expect(find.text('Due today'), findsOneWidget);
      await t.tap(find.byKey(const Key('chip_drafts')));
      await settle(t);
      expect(find.text('Draft quiz'), findsOneWidget);
      expect(find.text('Lab report'), findsNothing);
      await t.tap(find.byKey(const Key('chip_overdue')));
      await settle(t);
      expect(find.text('Lab report'), findsOneWidget);
      expect(find.byKey(const Key('hw_new_fab')), findsOneWidget);
    });

    testWidgets('filter with no match shows an inline empty state', (t) async {
      final s = await signIn(t);
      repo.mine = (_) async => [asg('a1')];
      final c = list(s.h);
      await open(t, const HomeworkScreen());
      await c.load();
      await t.tap(find.byKey(const Key('chip_drafts')));
      await settle(t);
      expect(find.byKey(const Key('hw_filter_empty')), findsOneWidget);
    });

    testWidgets('paging: 45 rows -> 20 shown, Show more reveals the rest', (t) async {
      final s = await signIn(t);
      repo.mine = (_) async => [for (var i = 0; i < 45; i++) asg('a$i', title: 'Task $i', due: '2026-11-${(i % 28 + 1).toString().padLeft(2, '0')}')];
      final c = list(s.h);
      await open(t, const HomeworkScreen(), size: const Size(430, 20000));
      await c.load();
      await settle(t);
      expect(find.byType(HomeworkController), findsNothing);
      expect(find.textContaining('Task '), findsNWidgets(20));
      await t.tap(find.byKey(const Key('hw_show_more')));
      await settle(t);
      expect(find.textContaining('Task '), findsNWidgets(40));
      await t.tap(find.byKey(const Key('hw_show_more')));
      await settle(t);
      expect(find.textContaining('Task '), findsNWidgets(45));
      expect(find.byKey(const Key('hw_show_more')), findsNothing);
    });

    testWidgets('loading shimmer, empty, error + Try again, 403', (t) async {
      final s = await signIn(t);
      final gate = Completer<List<Assignment>>();
      repo.mine = (_) => gate.future;
      final c = list(s.h);
      await open(t, const HomeworkScreen());
      unawaited(c.load());
      await t.pump();
      expect(find.byKey(const Key('screen_loading')), findsOneWidget);
      gate.complete([]);
      await settle(t);
      expect(find.byKey(const Key('screen_empty')), findsOneWidget);
      expect(find.text('No homework yet'), findsOneWidget);

      repo.mine = (_) async => throw ApiException('Internal server error', statusCode: 500);
      await c.load(force: true);
      await settle(t);
      expect(find.byKey(const Key('screen_error')), findsOneWidget);
      repo.mine = (_) async => [asg('a1', title: 'Back again')];
      await t.tap(find.text('Try again'));
      await settle(t);
      expect(find.text('Back again'), findsOneWidget);

      repo.mine = (_) async => throw ApiException('Forbidden resource', statusCode: 403);
      await c.load(force: true);
      await settle(t);
      expect(find.text("You don't have access"), findsOneWidget);
    });

    testWidgets('no teaching:view: forbidden page and no create button', (t) async {
      final s = await signIn(t, permissions: ['dashboard:view']);
      list(s.h);
      await open(t, const HomeworkScreen());
      await settle(t);
      expect(find.byKey(const Key('screen_forbidden')), findsOneWidget);
      expect(find.byKey(const Key('hw_new_fab')), findsNothing);
      expect(repo.calls, isEmpty);
    });

    testWidgets('pull to refresh reloads from the server', (t) async {
      final s = await signIn(t);
      repo.mine = (_) async => [asg('a1')];
      final c = list(s.h);
      await open(t, const HomeworkScreen());
      await c.load();
      await settle(t);
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

  group('Homework detail', () {
    Future<HomeworkDetailController> boot(WidgetTester t, Assignment a, {Future<bool> Function(Uri)? opener}) async {
      final s = await signIn(t);
      final l = list(s.h);
      l.upsert(a);
      final c = Get.put(HomeworkDetailController(id: a.id, repository: repo, list: l, opener: opener, clock: () => now));
      await open(t, const HomeworkDetailScreen());
      return c;
    }

    testWidgets('assigned: details, attachment link opens the signed URL, submissions button, no assign button', (t) async {
      Uri? opened;
      await boot(t, asg('a1', title: 'Fractions', due: '2026-10-07', count: 3, keys: ['demo/homework-attachments/x.pdf']), opener: (u) async {
        opened = u;
        return true;
      });
      expect(find.text('Fractions'), findsOneWidget);
      expect(find.text('Due Wed 7 Oct (7 Oct 2026)'), findsOneWidget);
      expect(find.text('3 handed in'), findsOneWidget);
      expect(find.text('Attachment 1 (PDF)'), findsOneWidget);
      expect(find.byKey(const Key('hw_view_submissions')), findsOneWidget);
      expect(find.byKey(const Key('hw_assign')), findsNothing);
      await t.tap(find.byKey(const ValueKey('hw_att_0')));
      await settle(t);
      expect(repo.calls, contains('signed:demo/homework-attachments/x.pdf'));
      expect(opened.toString(), contains('files.example.test'));
    });

    testWidgets('attachment link failure shows a snackbar', (t) async {
      repo.onSigned = (_) async => throw ApiException('Internal server error', statusCode: 500);
      await boot(t, asg('a1', keys: ['k/x.pdf']));
      await t.tap(find.byKey(const ValueKey('hw_att_0')));
      await settle(t);
      expect(find.textContaining("couldn't open this file"), findsOneWidget);
    });

    testWidgets('draft: assign asks for confirmation (guardians are notified) then PATCHes', (t) async {
      repo.onUpdate = (id, p) async => asg(id, status: 'assigned');
      await boot(t, asg('a1', status: 'draft'));
      expect(find.byKey(const Key('hw_view_submissions')), findsNothing);
      await t.tap(find.byKey(const Key('hw_assign')));
      await settle(t);
      expect(find.textContaining('guardians'), findsOneWidget);
      await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
      await settle(t);
      expect(repo.patches.single, {'status': 'assigned'});
      await t.pump(const Duration(seconds: 3));
      expect(find.byKey(const Key('hw_view_submissions')), findsOneWidget);
    });

    testWidgets('delete: confirm dialog warns about submissions; cancel does nothing; confirm deletes and leaves', (t) async {
      await boot(t, asg('a1', title: 'To remove', count: 5));
      await t.tap(find.byKey(const Key('hw_delete')));
      await settle(t);
      expect(find.textContaining('every submission and grade'), findsOneWidget);
      await t.tap(find.byKey(const Key('confirm_dialog_cancel')));
      await settle(t);
      expect(repo.calls.where((x) => x.startsWith('delete')), isEmpty);
      await t.tap(find.byKey(const Key('hw_delete')));
      await settle(t);
      await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
      await settle(t);
      await t.pump(const Duration(seconds: 3));
      expect(repo.calls, contains('delete:a1'));
      expect(find.text('root'), findsOneWidget);
    });

    testWidgets('delete failure (403) keeps the screen and says why', (t) async {
      repo.onDelete = (_) async => throw ApiException('Forbidden resource', statusCode: 403);
      await boot(t, asg('a1', title: 'Mine'));
      await t.tap(find.byKey(const Key('hw_delete')));
      await settle(t);
      await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
      await settle(t);
      expect(find.text("You can't delete this homework. Forbidden resource"), findsOneWidget);
      expect(find.text('Mine'), findsOneWidget);
    });

    testWidgets('cold deep link: not in the list -> loads from the submissions endpoint; 404 -> not available', (t) async {
      final s = await signIn(t);
      final l = list(s.h);
      repo.subs = (id) async => SubmissionsResult(asg(id, title: 'From deep link'), const []);
      Get.put(HomeworkDetailController(id: 'zz', repository: repo, list: l, clock: () => now));
      await open(t, const HomeworkDetailScreen());
      await Get.find<HomeworkDetailController>().load();
      await settle(t);
      expect(find.text('From deep link'), findsOneWidget);
      repo.subs = (id) async => throw ApiException('Assignment not found', statusCode: 404);
      await Get.find<HomeworkDetailController>().load();
      await settle(t);
      expect(find.byKey(const Key('screen_unavailable')), findsOneWidget);
    });
  });

  group('Homework form', () {
    Future<HomeworkFormController> boot(WidgetTester t, {Assignment? editing, FakePicker? picker, List<Map<String, Object?>>? assignments}) async {
      final s = assignments == null ? await signIn(t) : await signIn(t, assignments: assignments);
      final l = list(s.h);
      final c = Get.put(HomeworkFormController(repository: repo, students: students, auth: s.h.auth, picker: picker ?? FakePicker(), list: l, clock: () => now, editing: editing));
      await open(t, const HomeworkNewScreen());
      await settle(t);
      return c;
    }

    testWidgets('no class assigned: honest empty state, no form', (t) async {
      await boot(t, assignments: const []);
      expect(find.byKey(const Key('hw_no_classes')), findsOneWidget);
      expect(find.byKey(const Key('hw_submit')), findsNothing);
    });

    testWidgets('pristine submit shows field errors and sends nothing', (t) async {
      final c = await boot(t);
      await t.tap(find.byKey(const Key('hw_save_draft')));
      await settle(t);
      expect(find.text('Enter a title'), findsWidgets);
      expect(find.text('Choose a due date'), findsWidgets);
      expect(repo.created, isEmpty);
      expect(c.errors.keys, containsAll(['title', 'due']));
    });

    testWidgets('class list is only MY classes; roster line shows the count; fill and save a draft', (t) async {
      final c = await boot(t);
      expect(find.byKey(const Key('hw_roster_count')), findsOneWidget);
      expect(find.text('2 students in this class'), findsOneWidget);
      expect(find.text('Grade 5 - A'), findsOneWidget);
      await t.enterText(find.byKey(const Key('hw_title_field')), 'Exercise 5.3');
      c.setDueDay(DateTime(2026, 10, 9));
      await t.pump();
      await t.tap(find.byKey(const Key('hw_save_draft')));
      await settle(t);
      await t.pump(const Duration(seconds: 3));
      expect(repo.created.single.assign, isFalse);
      expect(repo.created.single.input.title, 'Exercise 5.3');
      expect(find.text('root'), findsOneWidget); // popped back
    });

    testWidgets('assign asks first; cancel keeps the form and sends nothing', (t) async {
      final c = await boot(t);
      c.titleC.text = 'T';
      c.setDueDay(DateTime(2026, 10, 9));
      await t.tap(find.byKey(const Key('hw_submit')));
      await settle(t);
      expect(find.textContaining('guardians'), findsOneWidget);
      await t.tap(find.byKey(const Key('confirm_dialog_cancel')));
      await settle(t);
      expect(repo.created, isEmpty);
      expect(find.byKey(const Key('hw_submit')), findsOneWidget);
    });

    testWidgets('server validation error is shown and the typed text survives', (t) async {
      repo.onCreate = (i, tid, a) async => throw ApiException('totalMarks must not be less than 0', statusCode: 400);
      final c = await boot(t);
      c.titleC.text = 'Keep this';
      c.setDueDay(DateTime(2026, 10, 9));
      await t.tap(find.byKey(const Key('hw_save_draft')));
      await settle(t);
      expect(find.text('totalMarks must not be less than 0'), findsWidgets);
      expect(find.byKey(const Key('hw_submit_error')), findsOneWidget);
      expect(find.text('Keep this'), findsOneWidget);
    });

    testWidgets('attachments: progress bar while uploading, failure row with Retry, success after retry', (t) async {
      final gate = Completer<UploadedFile>();
      void Function(int, int)? progress;
      repo.onUpload = (p, n, pr) {
        progress = pr;
        return gate.future;
      };
      final picker = FakePicker()..docs = [PickedAttachment(name: 'sheet.pdf', path: '/tmp/sheet.pdf', size: 2048)];
      final c = await boot(t, picker: picker);
      unawaited(c.pickDocuments());
      await t.pump();
      await t.pump();
      expect(find.text('sheet.pdf'), findsOneWidget);
      expect(find.text('2 KB'), findsOneWidget);
      final id = c.attachments.single.id;
      expect(find.byKey(ValueKey('progress_$id')), findsOneWidget);
      progress!(25, 100);
      await t.pump();
      expect(find.text('25%'), findsOneWidget);
      expect(find.text('Uploading...'), findsOneWidget); // submit disabled while uploading
      gate.completeError(ApiException('The server had a problem', statusCode: 500));
      await settle(t);
      expect(find.byKey(ValueKey('retry_$id')), findsOneWidget);
      expect(find.byKey(ValueKey('att_err_$id')), findsOneWidget);
      repo.onUpload = (p, n, pr) async => const UploadedFile(key: 'k/sheet.pdf');
      await t.tap(find.byKey(ValueKey('retry_$id')));
      await settle(t);
      expect(find.byKey(ValueKey('retry_$id')), findsNothing);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      await t.tap(find.byKey(ValueKey('remove_$id')));
      await settle(t);
      expect(find.text('sheet.pdf'), findsNothing);
    });

    testWidgets('rejected file types / sizes are explained', (t) async {
      final picker = FakePicker()..docs = [const PickedAttachment(name: 'run.exe', path: '/tmp/run.exe', size: 10)];
      final c = await boot(t, picker: picker);
      await c.pickDocuments();
      await settle(t);
      expect(find.byKey(const Key('hw_pick_notice')), findsOneWidget);
      expect(find.textContaining('run.exe'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('edit an assigned homework: class/subject read-only, one "Save changes" button, only the diff is sent', (t) async {
      final c = await boot(t, editing: asg('a1', title: 'Old', due: '2026-10-07'));
      expect(find.text('Edit homework'), findsOneWidget);
      expect(find.byKey(const Key('hw_save_draft')), findsNothing);
      expect(find.text('Save changes'), findsOneWidget);
      expect(find.byKey(const Key('class_picker')), findsNothing);
      await t.enterText(find.byKey(const Key('hw_title_field')), 'New title');
      c.setDueDay(DateTime(2026, 10, 9));
      await t.pump();
      await t.tap(find.byKey(const Key('hw_submit')));
      await settle(t);
      await t.pump(const Duration(seconds: 3));
      expect(repo.patches.single, {'title': 'New title', 'dueDate': '2026-10-09'});
    });

    testWidgets('leaving with unsaved text asks first', (t) async {
      final c = await boot(t);
      c.titleC.text = 'Unsaved';
      await t.pump();
      await t.binding.handlePopRoute();
      await settle(t);
      expect(find.text('Discard this homework?'), findsOneWidget);
      await t.tap(find.byKey(const Key('confirm_dialog_cancel')));
      await settle(t);
      expect(find.text('Unsaved'), findsOneWidget);
    });
  });

  group('Submissions and grading', () {
    Future<SubmissionsController> boot(WidgetTester t, {List<Submission>? rows, Assignment? a}) async {
      final s = await signIn(t);
      final l = list(s.h);
      l.upsert(a ?? asg('a1', title: 'Fractions', count: 3));
      repo.subs = (id) async => SubmissionsResult(a ?? asg(id, title: 'Fractions', count: 3), rows ?? defaultRows());
      final c = Get.put(SubmissionsController(assignmentId: 'a1', repository: repo, list: l));
      await open(t, const HomeworkSubmissionsScreen());
      await c.load();
      await settle(t);
      return c;
    }

    testWidgets('whole roster: tags, late flag, grade, counts, filters and the not-handed-in rows', (t) async {
      await boot(t);
      expect(find.text('Fractions'), findsOneWidget);
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Di'), findsOneWidget); // pending student is listed
      expect(find.text('NOT HANDED IN'), findsWidgets);
      expect(find.text('MISSED'), findsOneWidget);
      expect(find.text('LATE'), findsWidgets);
      expect(find.text('80/100'), findsOneWidget);
      expect(find.textContaining('Handed in 4 Oct'), findsWidgets);
      await t.tap(find.byKey(const Key('chip_notHandedIn')));
      await settle(t);
      expect(find.text('Ana'), findsNothing);
      expect(find.text('Ed'), findsOneWidget);
      await t.tap(find.byKey(const Key('chip_graded')));
      await settle(t);
      expect(find.text('Cy'), findsOneWidget);
      expect(find.text('Di'), findsNothing);
    });

    testWidgets('tapping a student who has not handed in explains instead of opening a grade screen', (t) async {
      await boot(t);
      await t.tap(find.text('Di'));
      await settle(t);
      expect(find.textContaining('has not handed anything in yet'), findsOneWidget);
    });

    testWidgets('states: loading, error + retry, 403, 404, assigned-but-empty roster', (t) async {
      final s = await signIn(t);
      final gate = Completer<SubmissionsResult>();
      repo.subs = (_) => gate.future;
      final c = Get.put(SubmissionsController(assignmentId: 'a1', repository: repo, list: list(s.h)));
      await open(t, const HomeworkSubmissionsScreen());
      unawaited(c.load());
      await t.pump();
      expect(find.byKey(const Key('screen_loading')), findsOneWidget);
      gate.completeError(ApiException('Internal server error', statusCode: 500));
      await settle(t);
      expect(find.byKey(const Key('screen_error')), findsOneWidget);
      repo.subs = (id) async => SubmissionsResult(asg(id), const []);
      await t.tap(find.text('Try again'));
      await settle(t);
      expect(find.byKey(const Key('subs_none')), findsOneWidget);
      repo.subs = (id) async => throw ApiException('This assignment belongs to a different campus.', statusCode: 403);
      await c.load(force: true);
      await settle(t);
      expect(find.text("You don't have access"), findsOneWidget);
      repo.subs = (id) async => throw ApiException('Assignment not found', statusCode: 404);
      await c.load(force: true);
      await settle(t);
      expect(find.byKey(const Key('screen_unavailable')), findsOneWidget);
    });

    Future<SubmissionsController> bootGrade(WidgetTester t, String sid, {List<Submission>? rows}) async {
      final s = await signIn(t);
      final l = list(s.h);
      l.upsert(asg('a1', title: 'Fractions', count: 3));
      repo.subs = (id) async => SubmissionsResult(asg(id, title: 'Fractions', count: 3), rows ?? defaultRows());
      final c = Get.put(SubmissionsController(assignmentId: 'a1', repository: repo, list: l));
      Get.parameters = {'id': 'a1', 'sid': sid};
      await c.load();
      await open(t, const HomeworkGradeScreen());
      await settle(t);
      return c;
    }

    testWidgets('grade screen shows the answer, files and "out of" the row maximum', (t) async {
      await bootGrade(t, 's2');
      expect(find.byKey(const Key('grade_student')), findsOneWidget);
      expect(find.text('Bo'), findsOneWidget);
      expect(find.text('LATE'), findsOneWidget);
      expect(find.text('Attachment 1 (PDF)'), findsOneWidget);
      expect(find.text('Marks out of 100 *'), findsOneWidget);
    });

    testWidgets('validation: blank / too high / negative / text show inline errors and send nothing', (t) async {
      await bootGrade(t, 's6'); // max 20
      for (final entry in {'': 'Enter the marks', '21': "Marks can't be more than 20", '-1': "Marks can't be below 0", 'abc': 'Marks must be a number'}.entries) {
        await t.enterText(find.byKey(const Key('grade_marks')), entry.key);
        await t.tap(find.byKey(const Key('grade_save')));
        await settle(t);
        expect(find.text(entry.value), findsOneWidget, reason: entry.key);
      }
      expect(repo.graded, isEmpty);
    });

    testWidgets('server rejection text is shown in a banner and the entered marks are kept', (t) async {
      repo.onGrade = (a, s, g, f) async => throw ApiException("Grade cannot exceed this assignment's maximum of 100.", statusCode: 400);
      await bootGrade(t, 's1');
      await t.enterText(find.byKey(const Key('grade_marks')), '90');
      await t.tap(find.byKey(const Key('grade_save')));
      await settle(t);
      expect(find.byKey(const Key('grade_server_error')), findsOneWidget);
      expect(find.text("Grade cannot exceed this assignment's maximum of 100."), findsOneWidget);
      expect(find.text('90'), findsOneWidget);
    });

    testWidgets('success: marks saved, screen closes, the list row now reads GRADED with the mark', (t) async {
      repo.onGrade = (a, s, g, f) async => Submission.fromJson({'_id': s, 'studentName': 'Ana', 'status': 'graded', 'grade': g, 'maxGrade': 100});
      final c = await bootGrade(t, 's1');
      await t.enterText(find.byKey(const Key('grade_marks')), '87.5');
      await t.enterText(find.byKey(const Key('grade_feedback')), 'Nice work');
      await t.tap(find.byKey(const Key('grade_save')));
      await settle(t);
      await t.pump(const Duration(seconds: 3));
      expect(repo.graded.single.grade, 87.5);
      expect(repo.graded.single.feedback, 'Nice work');
      expect(c.byId('s1')!.isGraded, isTrue);
      expect(find.text('root'), findsOneWidget);
    });

    testWidgets('a student who has not handed in cannot be graded', (t) async {
      await bootGrade(t, 's4');
      expect(find.byKey(const Key('grade_not_gradable')), findsOneWidget);
      expect(find.byKey(const Key('grade_save')), findsNothing);
    });

    testWidgets('unknown submission id -> not found message', (t) async {
      await bootGrade(t, 'nope');
      expect(find.byKey(const Key('grade_missing')), findsOneWidget);
    });
  });
}

List<Submission> defaultRows() => [
      sub('s1', 'submitted', name: 'Ana', text: 'Done'),
      sub('s2', 'late', name: 'Bo', late: true, keys: ['k/a.pdf'], text: 'Sorry'),
      sub('s3', 'graded', name: 'Cy', grade: 80, late: true),
      sub('s4', 'pending', name: 'Di'),
      sub('s5', 'missed', name: 'Ed'),
      sub('s6', 'submitted', name: 'Fay', max: 20),
    ];
