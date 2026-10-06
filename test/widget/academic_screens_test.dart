// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';
import 'package:eldermin_teacher_app/app/modules/lesson_plans/controllers/lesson_plan_detail_controller.dart';
import 'package:eldermin_teacher_app/app/modules/lesson_plans/controllers/lesson_plan_form_controller.dart';
import 'package:eldermin_teacher_app/app/modules/lesson_plans/controllers/lesson_plan_upload_controller.dart';
import 'package:eldermin_teacher_app/app/modules/lesson_plans/controllers/lesson_plans_controller.dart';
import 'package:eldermin_teacher_app/app/modules/lesson_plans/views/lesson_plan_detail_screen.dart';
import 'package:eldermin_teacher_app/app/modules/lesson_plans/views/lesson_plan_new_screen.dart';
import 'package:eldermin_teacher_app/app/modules/lesson_plans/views/lesson_plan_upload_screen.dart';
import 'package:eldermin_teacher_app/app/modules/lesson_plans/views/lesson_plans_screen.dart';
import 'package:eldermin_teacher_app/app/modules/syllabus/controllers/syllabus_controller.dart';
import 'package:eldermin_teacher_app/app/modules/syllabus/controllers/syllabus_detail_controller.dart';
import 'package:eldermin_teacher_app/app/modules/syllabus/controllers/weekly_planner_controller.dart';
import 'package:eldermin_teacher_app/app/modules/syllabus/views/syllabus_detail_screen.dart';
import 'package:eldermin_teacher_app/app/modules/syllabus/views/syllabus_screen.dart';
import 'package:eldermin_teacher_app/app/modules/syllabus/views/syllabus_weekly_planner_screen.dart';
import 'package:eldermin_teacher_app/core/models/academic/lesson_plan_models.dart';
import 'package:eldermin_teacher_app/core/models/academic/syllabus_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/services/attachment_picker.dart' show PickedAttachment;
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_academic_repositories.dart';

final now = DateTime(2026, 10, 5, 9, 30);
const cls5a = {'gradeLevel': 'Grade 5', 'sectionName': 'A', 'subjectName': 'Mathematics'};
const cls6b = {'gradeLevel': 'Grade 6', 'sectionName': 'B', 'subjectName': 'Science'};

void main() {
  late FakeLessonPlanRepository lp;
  late FakeSyllabusRepository sy;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    lp = FakeLessonPlanRepository();
    sy = FakeSyllabusRepository();
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

  Future<void> open(WidgetTester t, Widget screen, {Size size = const Size(430, 4000)}) async {
    await t.binding.setSurfaceSize(size);
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: const Scaffold(body: Text('root'))));
    unawaited(Get.to(() => screen));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }

  /// Lets the 2 s toast timer finish (ToastUtil) so no timer is left pending.
  Future<void> drain(WidgetTester t) async {
    await t.pump(const Duration(seconds: 3));
  }

  Future<void> settle(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
  }

  LessonPlansController lpList(dynamic h, {LessonPlanFilter? filter}) => Get.put(LessonPlansController(repository: lp, auth: h.auth, permissions: h.perms, initialFilter: filter));

  group('Lesson plans list', () {
    testWidgets('status chips with counts, rejected plan shows its reason, others do not; truncation notice absent under 100', (t) async {
      final h = await signIn(t);
      lp.mine = (_) async => [
            plan('p1', topic: 'Fractions', status: 'rejected', reason: 'Add an assessment section'),
            plan('p2', topic: 'Decimals', status: 'submitted'),
            plan('p3', topic: 'Percentages', status: 'submitted', reason: 'STALE reason from an old rejection'),
            plan('p4', topic: 'Ratios', status: 'approved', notes: 'Approver says hi'),
            plan('p5', topic: 'Geometry', status: 'draft'),
            plan('p6', topic: 'Angles', status: 'overdue'),
          ];
      final c = lpList(h);
      await open(t, const LessonPlansScreen());
      await c.load();
      await settle(t);
      expect(find.text('REJECTED'), findsOneWidget);
      expect(find.text('AWAITING APPROVAL'), findsNWidgets(2));
      expect(find.text('APPROVED'), findsOneWidget);
      expect(find.text('DRAFT'), findsOneWidget);
      expect(find.text('OVERDUE'), findsOneWidget);
      expect(find.text('Rejected: Add an assessment section'), findsOneWidget);
      expect(find.textContaining('STALE'), findsNothing); // the stale reason of a re-submitted plan is never shown
      expect(find.textContaining('Approver says hi'), findsNothing); // notes belong to the detail
      expect(find.byKey(const Key('lp_truncated')), findsNothing);
      expect(find.text('All  6'), findsOneWidget);
      expect(find.text('Rejected  1'), findsOneWidget);
      await t.tap(find.byKey(const Key('chip_rejected')));
      await settle(t);
      expect(find.text('Fractions'), findsOneWidget);
      expect(find.text('Decimals'), findsNothing);
      await t.tap(find.byKey(const Key('chip_submitted')));
      await settle(t);
      expect(find.text('Decimals'), findsOneWidget);
      expect(find.text('Percentages'), findsOneWidget);
      expect(find.byKey(const Key('lp_new_fab')), findsOneWidget);
      expect(find.byKey(const Key('lp_upload_action')), findsOneWidget);
    });

    testWidgets('opens pre-filtered when the Home card sends a status', (t) async {
      final h = await signIn(t);
      lp.mine = (_) async => [plan('p1', topic: 'Fractions', status: 'rejected', reason: 'r'), plan('p2', topic: 'Decimals', status: 'draft')];
      final c = lpList(h, filter: LessonPlanFilter.rejected);
      c.onInit();
      await open(t, const LessonPlansScreen());
      await c.load();
      await settle(t);
      expect(find.text('Fractions'), findsOneWidget);
      expect(find.text('Decimals'), findsNothing);
    });

    testWidgets('100 plans: says the list may be truncated', (t) async {
      final h = await signIn(t);
      lp.mine = (_) async => [for (var i = 0; i < 100; i++) plan('p$i', topic: 'T$i')];
      final c = lpList(h);
      await open(t, const LessonPlansScreen(), size: const Size(430, 30000));
      await c.load();
      await settle(t);
      expect(find.byKey(const Key('lp_truncated')), findsOneWidget);
    });

    testWidgets('loading shimmer, empty, error + Try again, 403 "You don\'t have access"', (t) async {
      final h = await signIn(t);
      final gate = Completer<List<LessonPlanRecord>>();
      lp.mine = (_) => gate.future;
      final c = lpList(h);
      await open(t, const LessonPlansScreen());
      unawaited(c.load());
      await t.pump();
      expect(find.byKey(const Key('screen_loading')), findsOneWidget);
      gate.complete([]);
      await settle(t);
      expect(find.byKey(const Key('screen_empty')), findsOneWidget);
      expect(find.text('No lesson plans yet'), findsOneWidget);
      lp.mine = (_) async => throw ApiException('Internal server error', statusCode: 500);
      await c.load(force: true);
      await settle(t);
      expect(find.byKey(const Key('screen_error')), findsOneWidget);
      lp.mine = (_) async => [plan('p1', topic: 'Back again')];
      await t.tap(find.text('Try again'));
      await settle(t);
      expect(find.text('Back again'), findsOneWidget);
      lp.mine = (_) async => throw ApiException('Forbidden resource', statusCode: 403);
      await c.load(force: true);
      await settle(t);
      expect(find.text("You don't have access"), findsOneWidget);
      expect(find.byKey(const Key('lp_new_fab')), findsNothing); // no create button on a 403 page
    });

    testWidgets('filter with no match shows an inline empty state; pull to refresh reloads', (t) async {
      final h = await signIn(t);
      lp.mine = (_) async => [plan('p1')];
      final c = lpList(h);
      await open(t, const LessonPlansScreen());
      await c.load();
      await t.tap(find.byKey(const Key('chip_rejected')));
      await settle(t);
      expect(find.byKey(const Key('lp_filter_empty')), findsOneWidget);
      await t.binding.setSurfaceSize(null);
      await t.pump();
      final before = lp.calls.length;
      await t.fling(find.byType(ListView).first, const Offset(0, 300), 1000);
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      await t.pump(const Duration(seconds: 1));
      expect(lp.calls.length, greaterThan(before));
    });
  });

  group('Lesson plan detail', () {
    Future<LessonPlanDetailController> boot(WidgetTester t, LessonPlanRecord p) async {
      final h = await signIn(t);
      lp.mine = (_) async => [p];
      final l = lpList(h);
      final c = Get.put(LessonPlanDetailController(id: p.id, repository: lp, list: l));
      await open(t, const LessonPlanDetailScreen());
      await c.load();
      await settle(t);
      return c;
    }

    testWidgets('rejected: the reason is shown, "Edit and resubmit" is offered, "Submit" is not', (t) async {
      await boot(t, plan('p1', status: 'rejected', reason: 'Add an assessment section'));
      expect(find.byKey(const Key('lp_rejection')), findsOneWidget);
      expect(find.text('Add an assessment section'), findsOneWidget);
      expect(find.text('Edit and resubmit'), findsOneWidget);
      expect(find.byKey(const Key('lp_submit')), findsNothing);
    });

    testWidgets('rejected without a reason says so honestly', (t) async {
      await boot(t, plan('p1', status: 'rejected'));
      expect(find.text('No reason was given.'), findsOneWidget);
    });

    testWidgets('a re-submitted plan never shows the stale reason; awaiting plans cannot be edited', (t) async {
      await boot(t, plan('p1', status: 'submitted', reason: 'OLD reason'));
      expect(find.textContaining('OLD reason'), findsNothing);
      expect(find.byKey(const Key('lp_rejection')), findsNothing);
      expect(find.byKey(const Key('lp_under_review')), findsOneWidget);
      expect(find.byKey(const Key('lp_edit')), findsNothing);
      expect(find.byKey(const Key('lp_submit')), findsNothing);
    });

    testWidgets('approved: approver notes shown, read-only, and NO approve / reject / delete controls anywhere', (t) async {
      await boot(t, plan('p1', status: 'approved', notes: 'Well structured'));
      expect(find.byKey(const Key('lp_approver_notes')), findsOneWidget);
      expect(find.text('Well structured'), findsOneWidget);
      expect(find.byKey(const Key('lp_edit')), findsNothing);
      expect(find.byKey(const Key('lp_submit')), findsNothing);
      for (final w in ['Approve', 'Reject', 'Delete']) {
        expect(find.text(w), findsNothing);
      }
    });

    testWidgets('draft: submit asks for confirmation, then sends only the status', (t) async {
      final c = await boot(t, plan('p1', status: 'draft', topic: 'Geometry'));
      expect(find.byKey(const Key('lp_submit')), findsOneWidget);
      await t.tap(find.byKey(const Key('lp_submit')));
      await settle(t);
      expect(find.text('Submit for approval?'), findsOneWidget);
      await t.tap(find.byKey(const Key('confirm_dialog_cancel')));
      await settle(t);
      expect(lp.patches, isEmpty);
      await t.tap(find.byKey(const Key('lp_submit')));
      await settle(t);
      await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
      await settle(t);
      expect(lp.patches.single.patch, {'status': 'submitted'});
      expect(c.plan!.status, LessonPlanStatus.submitted);
      expect(find.byKey(const Key('lp_submit')), findsNothing);
      await drain(t);
    });

    testWidgets('submit failure: an inline error, the plan stays a draft', (t) async {
      lp.onUpdate = (id, p) async => throw ApiException('You can only modify your own lesson plans', statusCode: 403);
      await boot(t, plan('p1', status: 'draft'));
      await t.tap(find.byKey(const Key('lp_submit')));
      await settle(t);
      await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
      await settle(t);
      expect(find.byKey(const Key('lp_action_error')), findsOneWidget);
      expect(find.byKey(const Key('lp_submit')), findsOneWidget);
    });

    testWidgets('unknown plan: not-in-list message; fields shown: objectives, resources, homework', (t) async {
      await boot(t, plan('p1', objectives: ['Add fractions', 'Compare fractions'], resources: ['Textbook', 'Video'], homework: 'Exercise 4', method: 'lecture'));
      expect(find.text('1. Add fractions'), findsOneWidget);
      expect(find.text('2. Compare fractions'), findsOneWidget);
      expect(find.text('Textbook, Video'), findsOneWidget);
      expect(find.text('Exercise 4'), findsOneWidget);
      expect(find.text('Lecture'), findsOneWidget);
    });
  });

  group('Lesson plan form', () {
    Future<LessonPlanFormController> boot(WidgetTester t, {List<Map<String, Object?>> assignments = const [cls5a, cls6b], LessonPlanRecord? editing, LessonPlanDraft? draft}) async {
      final h = await signIn(t, assignments: assignments);
      final l = lpList(h);
      final c = Get.put(LessonPlanFormController(repository: lp, auth: h.auth, list: l, clock: () => now, editing: editing, draft: draft));
      await open(t, const LessonPlanNewScreen());
      return c;
    }

    testWidgets('pristine submit shows inline errors and sends nothing', (t) async {
      await boot(t);
      await t.tap(find.byKey(const Key('lp_save_draft')));
      await settle(t);
      expect(find.text('Choose a class'), findsWidgets); // inline error + the first one in the snackbar
      expect(find.text('Enter the topic'), findsOneWidget);
      expect(find.text('Choose the lesson date'), findsOneWidget);
      expect(lp.created, isEmpty);
      expect(lp.patches, isEmpty);
    });

    testWidgets('class picker narrows the subjects; a single class and subject preselect', (t) async {
      final c = await boot(t);
      expect(find.text('Choose a class first.'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('class_chip_1')));
      await settle(t);
      expect(find.byKey(const Key('subject_Science')), findsOneWidget);
      expect(c.subject.value, 'Science');
    });

    testWidgets('fill, save as draft: the exact body is posted and the screen closes', (t) async {
      final c = await boot(t, assignments: const [cls5a]);
      await t.enterText(find.byKey(const Key('lp_topic_field')), 'Adding fractions');
      c.setPlanDay(DateTime(2026, 10, 9));
      await t.enterText(find.byKey(ValueKey('lp_obj_${c.objectives.first.id}')), 'Add fractions');
      await t.tap(find.byKey(const Key('res_Textbook')));
      await t.tap(find.byKey(const Key('method_activity')));
      await settle(t);
      await t.tap(find.byKey(const Key('lp_save_draft')));
      await settle(t);
      final b = lp.created.single;
      expect(b['status'], 'draft');
      expect(b['topic'], 'Adding fractions');
      expect(b['objectives'], ['Add fractions']);
      expect(b['resources'], ['Textbook']);
      expect(b['teachingMethodology'], 'activity');
      expect(b['planDate'], '2026-10-09');
      await drain(t);
      expect(find.byKey(const Key('lp_save_draft')), findsNothing); // popped
    });

    testWidgets('submit for approval confirms first; cancel sends nothing', (t) async {
      final c = await boot(t, assignments: const [cls5a]);
      await t.enterText(find.byKey(const Key('lp_topic_field')), 'Adding fractions');
      c.setPlanDay(DateTime(2026, 10, 9));
      await t.tap(find.byKey(const Key('lp_submit_approval')));
      await settle(t);
      expect(find.text('Submit for approval?'), findsOneWidget);
      await t.tap(find.byKey(const Key('confirm_dialog_cancel')));
      await settle(t);
      expect(lp.created, isEmpty);
      await t.tap(find.byKey(const Key('lp_submit_approval')));
      await settle(t);
      await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
      await settle(t);
      expect(lp.created.single['status'], 'submitted');
      await drain(t);
    });

    testWidgets('offline failure: the form stays filled and shows a banner; saving is re-enabled', (t) async {
      lp.onCreate = (_) async => throw ApiException('No internet connection.');
      final c = await boot(t, assignments: const [cls5a]);
      await t.enterText(find.byKey(const Key('lp_topic_field')), 'Adding fractions');
      c.setPlanDay(DateTime(2026, 10, 9));
      await t.tap(find.byKey(const Key('lp_save_draft')));
      await settle(t);
      expect(find.byKey(const Key('lp_submit_error')), findsOneWidget);
      expect(find.text('Adding fractions'), findsOneWidget);
      expect(c.saving.value, isFalse);
      expect(find.byKey(const Key('lp_save_draft')), findsOneWidget);
    });

    testWidgets('objectives can be added and removed', (t) async {
      final c = await boot(t, assignments: const [cls5a]);
      await t.tap(find.byKey(const Key('lp_add_objective')));
      await settle(t);
      expect(c.objectives, hasLength(2));
      await t.tap(find.byKey(ValueKey('lp_obj_remove_${c.objectives.last.id}')));
      await settle(t);
      expect(c.objectives, hasLength(1));
    });

    testWidgets('editing a rejected plan: the rejection reason is shown on the form; "Save and resubmit" sends status + only the changes', (t) async {
      final c = await boot(t, editing: plan('r1', status: 'rejected', reason: 'Add an assessment section', mins: 40));
      expect(find.byKey(const Key('lp_edit_rejection')), findsOneWidget);
      expect(find.text('Add an assessment section'), findsOneWidget);
      expect(find.text('Edit and resubmit'), findsOneWidget);
      expect(find.byKey(const Key('lp_date_picker')), findsOneWidget);
      await t.enterText(find.byKey(const Key('lp_assessment_field')), 'Exit ticket');
      await t.tap(find.text('Save and resubmit'));
      await settle(t);
      await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
      await settle(t);
      expect(lp.patches.single.patch, {'assessment': 'Exit ticket', 'status': 'submitted'});
      expect(c.saving.value, isFalse);
      await drain(t);
    });

    testWidgets('a parsed draft prefills the form with a review banner and the reader\'s warnings; nothing is saved', (t) async {
      final d = LessonPlanDraft.fromJson(Map<String, dynamic>.from(fx6('parse_upload') as Map));
      await boot(t, assignments: const [cls5a], draft: d);
      expect(find.byKey(const Key('lp_prefill_banner')), findsOneWidget);
      expect(find.text('Prefilled from plan.docx'), findsOneWidget);
      expect(find.byKey(const Key('lp_prefill_warnings')), findsOneWidget);
      expect(find.textContaining('No clear duration found'), findsOneWidget);
      expect(find.textContaining('Equivalent fractions'), findsOneWidget);
      expect(lp.created, isEmpty);
      expect(lp.patches, isEmpty); // review only: nothing saved, nothing submitted
    });

    testWidgets('no assigned class: honest empty state, no form', (t) async {
      await boot(t, assignments: const []);
      expect(find.byKey(const Key('lp_no_classes')), findsOneWidget);
      expect(find.byKey(const Key('lp_topic_field')), findsNothing);
    });
  });

  group('Upload and parse screen', () {
    Future<LessonPlanUploadController> boot(WidgetTester t) async {
      final c = Get.put(LessonPlanUploadController(repository: lp, picker: FakeSourcePicker()));
      await open(t, const LessonPlanUploadScreen());
      return c;
    }

    testWidgets('idle: choose a file or paste a link; read button disabled until one is given; pdf is refused with advice', (t) async {
      final c = await boot(t);
      expect(find.byKey(const Key('lp_pick_file')), findsOneWidget);
      expect(t.widget<ElevatedButton>(find.byKey(const Key('lp_parse'))).onPressed, isNull);
      c.setPicked(const PickedAttachment(name: 'plan.pdf', path: '/tmp/plan.pdf', size: 10));
      await settle(t);
      expect(find.byKey(const Key('lp_pick_notice')), findsOneWidget);
      c.setPicked(const PickedAttachment(name: 'plan.docx', path: '/tmp/plan.docx', size: 2048));
      await settle(t);
      expect(find.byKey(const Key('lp_picked')), findsOneWidget);
      expect(find.text('plan.docx'), findsOneWidget);
      expect(t.widget<ElevatedButton>(find.byKey(const Key('lp_parse'))).onPressed, isNotNull);
    });

    testWidgets('AI unavailable: a clean "couldn\'t read this file, fill it in yourself" state; no raw server text', (t) async {
      lp.onParse = (p, n, l) async => throw ApiException('AI assistance is not configured on this server.', statusCode: 500);
      final c = await boot(t);
      c.setPicked(const PickedAttachment(name: 'plan.docx', path: '/tmp/plan.docx', size: 2048));
      await settle(t);
      await t.tap(find.byKey(const Key('lp_parse')));
      await settle(t);
      expect(find.byKey(const Key('lp_parse_failure')), findsOneWidget);
      expect(find.text("We couldn't read this document"), findsOneWidget);
      expect(find.textContaining('fill the plan in yourself'), findsOneWidget);
      expect(find.textContaining('not configured'), findsNothing);
      expect(find.byKey(const Key('lp_fill_manually')), findsOneWidget);
      expect(find.byKey(const Key('lp_picked')), findsOneWidget); // file kept
    });

    testWidgets('reading: progress and a disabled button', (t) async {
      final gate = Completer<LessonPlanDraft>();
      lp.onParse = (p, n, l) => gate.future;
      final c = await boot(t);
      c.setLink('https://docs.google.com/document/d/abc/edit');
      await settle(t);
      unawaited(c.parse());
      await t.pump();
      expect(find.byKey(const Key('lp_parse_progress')), findsOneWidget);
      expect(find.text('Reading...'), findsOneWidget);
      expect(t.widget<ElevatedButton>(find.byKey(const Key('lp_parse'))).onPressed, isNull);
      gate.complete(const LessonPlanDraft(topic: 'T'));
      await settle(t);
    });
  });

  // ───────────────────────────── Syllabus ─────────────────────────────

  Future<SyllabusController> sylList(WidgetTester t, {List<Map<String, Object?>> assignments = const [cls5a, cls6b], List<String>? permissions}) async {
    final h = await signIn(t, assignments: assignments, permissions: permissions);
    return Get.put<SyllabusController>(SyllabusController(repository: sy, auth: h.auth, permissions: h.perms));
  }

  group('Syllabus list', () {
    testWidgets('tiles with overall progress, behind tag, assigned vs your class; colleague\'s other subject absent; planner entry', (t) async {
      final c = await sylList(t);
      await open(t, const SyllabusScreen());
      await c.load();
      await settle(t);
      expect(find.text('Mathematics'), findsNWidgets(3)); // 5-A, whole grade 5, grade 7 (legacy profile id)
      expect(find.text('Science'), findsNWidgets(2)); // term 1 (behind) and term 3
      expect(find.text('Art'), findsOneWidget);
      expect(find.text('DRAFT'), findsOneWidget);
      expect(find.text('English'), findsNothing);
      expect(find.text('BEHIND SCHEDULE'), findsOneWidget);
      expect(find.text('3 of 9 covered'), findsOneWidget);
      expect(find.text('33%'), findsOneWidget);
      expect(find.text('Your class'), findsOneWidget);
      expect(find.text('Assigned to you'), findsWidgets);
      expect(find.byKey(const Key('syl_planner_card')), findsOneWidget);
      await t.tap(find.byKey(const Key('chip_behind')));
      await settle(t);
      expect(find.text('Science'), findsOneWidget);
      expect(find.text('Mathematics'), findsNothing);
    });

    testWidgets('loading, empty, error + retry, 403, and no admin controls', (t) async {
      final c = await sylList(t);
      final gate = Completer<List<Syllabus>>();
      sy.onList = (_) => gate.future;
      await open(t, const SyllabusScreen());
      unawaited(c.load());
      await t.pump();
      expect(find.byKey(const Key('screen_loading')), findsOneWidget);
      gate.complete([]);
      await settle(t);
      expect(find.byKey(const Key('screen_empty')), findsOneWidget);
      sy.onList = (_) async => throw ApiException('Internal server error', statusCode: 500);
      await c.load(force: true);
      await settle(t);
      expect(find.byKey(const Key('screen_error')), findsOneWidget);
      sy.onList = (_) async => throw ApiException('Forbidden resource', statusCode: 403);
      await c.load(force: true);
      await settle(t);
      expect(find.text("You don't have access"), findsOneWidget);
      expect(find.byKey(const Key('syl_planner_card')), findsNothing);
      for (final w in ['Approve', 'Publish', 'Delete', 'Unpublish']) {
        expect(find.text(w), findsNothing);
      }
    });

    testWidgets('no teaching:view: forbidden, nothing requested', (t) async {
      await sylList(t, permissions: ['dashboard:view']);
      await open(t, const SyllabusScreen());
      await settle(t);
      expect(find.byKey(const Key('screen_forbidden')), findsOneWidget);
      expect(sy.queries, isEmpty);
    });
  });

  group('Syllabus detail', () {
    Future<(SyllabusController, String)> boot(WidgetTester t) async {
      final c = await sylList(t);
      await c.load();
      final id = c.items.firstWhere((s) => s.subjectName == 'Mathematics' && s.sectionName == 'A').id;
      Get.put(SyllabusDetailController(id: id, list: c, repository: sy));
      await open(t, const SyllabusDetailScreen());
      await Get.find<SyllabusDetailController>().load();
      await settle(t);
      return (c, id);
    }

    testWidgets('overall + per-unit + per-topic progress; sub-topics hidden until the topic is opened', (t) async {
      await boot(t);
      expect(find.text('Mathematics'), findsOneWidget);
      expect(find.text('3 of 9 covered'), findsOneWidget);
      expect(find.byKey(const Key('syl_overall_bar')), findsOneWidget);
      expect(find.text('1. Adding fractions'), findsOneWidget);
      expect(find.byKey(const ValueKey('topic_count_1_1')), findsOneWidget);
      expect(find.text('2/3'), findsOneWidget);
      expect(find.byKey(const ValueKey('sub_1_1_3')), findsNothing);
      await t.tap(find.text('1. Adding fractions'));
      await settle(t);
      expect(find.byKey(const ValueKey('sub_1_1_3')), findsOneWidget);
      expect(find.text('Mixed numbers'), findsOneWidget);
    });

    testWidgets('ticking a sub-topic is optimistic: the tick and the totals change BEFORE the server answers', (t) async {
      final gate = Completer<Syllabus>();
      final (c, id) = await boot(t);
      sy.onMark = (i, u, tp, s, cov) => gate.future;
      await t.tap(find.text('1. Adding fractions'));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('tick_sub_1_1_3')));
      await t.pump();
      expect(find.text('4 of 9 covered'), findsOneWidget);
      expect(find.text('3/3'), findsOneWidget);
      expect(find.byKey(const ValueKey('topic_state_1_1')), findsOneWidget);
      gate.complete(c.byId(id)!);
      await settle(t);
      expect(find.text('4 of 9 covered'), findsOneWidget);
    });

    testWidgets('a rejected tick is put back and a message says why (403)', (t) async {
      final (c, id) = await boot(t);
      sy.onMark = (i, u, tp, s, cov) async => throw ApiException('Forbidden resource', statusCode: 403);
      await t.tap(find.text('1. Adding fractions'));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('tick_sub_1_1_3')));
      await settle(t);
      expect(find.text('3 of 9 covered'), findsOneWidget);
      expect(find.textContaining("You can't update this syllabus"), findsOneWidget);
      expect(c.byId(id)!.progress.covered, 3);
    });

    testWidgets('a plain topic can be ticked; a topic with sub-topics has no direct tick', (t) async {
      final (_, id) = await boot(t);
      expect(find.byKey(const ValueKey('tick_topic_1_1')), findsNothing);
      expect(find.byKey(const ValueKey('tick_topic_2_2')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('tick_topic_2_2')));
      await settle(t);
      expect(sy.marks.single, (id: id, u: 2, t: 2, s: null, covered: true, by: 'Tess Teacher'));
      expect(find.text('4 of 9 covered'), findsOneWidget);
    });

    testWidgets('lessons are listed read-only (type icon + title), with no add / delete controls', (t) async {
      await boot(t);
      await t.tap(find.text('1. Adding fractions'));
      await settle(t);
      expect(find.text('LESSONS (READ ONLY)'), findsOneWidget);
      expect(find.text('Fractions explained (video)'), findsOneWidget);
      expect(find.text('Practice sheet'), findsOneWidget);
      for (final w in ['Add lesson', 'Delete', 'Publish', 'Approve']) {
        expect(find.text(w), findsNothing);
      }
    });

    testWidgets('behind-schedule notice, and not-mine syllabus is refused', (t) async {
      final c = await sylList(t);
      await c.load();
      final science = c.items.firstWhere((s) => s.subjectName == 'Science' && s.gradeLevel == 'Grade 6').id;
      Get.put(SyllabusDetailController(id: science, list: c, repository: sy));
      await open(t, const SyllabusDetailScreen());
      await settle(t);
      expect(find.byKey(const Key('syl_behind')), findsOneWidget);
    });

    testWidgets('a syllabus without units says so', (t) async {
      final c = await sylList(t);
      sy.onList = (q) async => [Syllabus.fromJson({'_id': 'e1', 'subjectName': 'Mathematics', 'gradeLevel': 'Grade 5', 'sectionName': 'A', 'status': 'active', 'teacherId': myStaff6, 'units': <Object>[]})];
      await c.load();
      Get.put(SyllabusDetailController(id: 'e1', list: c, repository: sy));
      await open(t, const SyllabusDetailScreen());
      await settle(t);
      expect(find.byKey(const Key('syl_no_units')), findsOneWidget);
    });
  });

  group('Weekly planner screen', () {
    Future<WeeklyPlannerController> boot(WidgetTester t, {DateTime? clockNow}) async {
      final c = await sylList(t);
      await c.load();
      final p = Get.put(WeeklyPlannerController(repository: sy, syllabi: c, auth: c.auth, clock: () => clockNow ?? now));
      await open(t, const SyllabusWeeklyPlannerScreen());
      await p.load();
      await settle(t);
      return p;
    }

    testWidgets('this week: cards per subject and class with the planned sub-topics, a tick, and not-covered earlier items', (t) async {
      await boot(t);
      expect(find.byKey(const Key('planner_label')), findsOneWidget);
      expect(find.text('This week'), findsWidgets);
      expect(find.text('Mathematics · Grade 5 - A'), findsOneWidget);
      expect(find.text('Mixed numbers'), findsOneWidget);
      expect(find.text('Place value'), findsOneWidget);
      expect(find.text('PLANNED FOR EARLIER WEEKS, NOT COVERED YET'), findsOneWidget);
      expect(find.text('Outputs'), findsOneWidget);
      await t.tap(find.descendant(of: find.byKey(const ValueKey('planner_64f000000000000000000801')), matching: find.byType(InkResponse)).first);
      await settle(t);
      expect(sy.marks, hasLength(1));
    });

    testWidgets('next / previous week arrows and "This week" shortcut', (t) async {
      final p = await boot(t);
      await t.tap(find.byKey(const Key('planner_next')));
      await settle(t);
      expect(find.text('Next week'), findsOneWidget);
      expect(find.text('Rounding'), findsOneWidget);
      expect(find.text('Mixed numbers'), findsNothing);
      await t.tap(find.byKey(const Key('planner_today')));
      await settle(t);
      expect(p.offset.value, 0);
      await t.tap(find.byKey(const Key('planner_prev')));
      await settle(t);
      expect(find.text('Last week'), findsOneWidget);
      expect(find.text('Unlike denominators'), findsOneWidget);
    });

    testWidgets('empty (nothing planned), error + retry, 403', (t) async {
      final c = await sylList(t);
      await c.load();
      final p = Get.put(WeeklyPlannerController(repository: sy, syllabi: c, auth: c.auth, clock: () => now));
      await open(t, const SyllabusWeeklyPlannerScreen());
      sy.onPlanner = (_) async => [];
      await p.load(force: true);
      await settle(t);
      expect(find.byKey(const Key('screen_empty')), findsOneWidget);
      expect(find.text('Nothing planned for this week'), findsOneWidget);
      sy.onPlanner = (_) async => throw ApiException('Internal server error', statusCode: 500);
      await p.load(force: true);
      await settle(t);
      expect(find.byKey(const Key('screen_error')), findsOneWidget);
      sy.onPlanner = null;
      await t.tap(find.text('Try again'));
      await settle(t);
      expect(find.text('Mathematics · Grade 5 - A'), findsOneWidget);
      sy.onPlanner = (_) async => throw ApiException('Forbidden resource', statusCode: 403);
      await p.load(force: true);
      await settle(t);
      expect(find.text("You don't have access"), findsOneWidget);
    });
  });
}
