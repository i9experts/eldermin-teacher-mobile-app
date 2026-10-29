// ignore_for_file: invalid_use_of_protected_member
// A1 item 9 (widgets): the student's Tarbiyah history offers New / Edit by permission and authorship, and the form works end to end.
import 'dart:async';
import 'package:eldermin_teacher_app/app/modules/behaviour/controllers/behaviour_student_controller.dart';
import 'package:eldermin_teacher_app/app/modules/behaviour/controllers/tarbiyah_form_controller.dart';
import 'package:eldermin_teacher_app/app/modules/behaviour/views/behaviour_student_screen.dart';
import 'package:eldermin_teacher_app/app/modules/behaviour/views/tarbiyah_form_screen.dart';
import 'package:eldermin_teacher_app/app/routes/app_routes.dart';
import 'package:eldermin_teacher_app/core/models/behaviour/behaviour_models.dart';
import 'package:eldermin_teacher_app/core/models/classroom/student_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/design_harness.dart' show loadDesignFonts;
import '../support/fake_classroom_repositories.dart';
import '../support/fake_phase5b_repositories.dart';
import '../support/layout_probe.dart';

const _cls5a = {'gradeLevel': 'Grade 5', 'sectionName': 'A', 'subjectName': 'Mathematics'};
const _zara = StudentSummary(id: 'st1', firstName: 'Zara', lastName: 'Malik', grade: 'Grade 5', section: 'A', rollNumber: '6');

TarbiyahAssessment _ta(String id, {String period = 'Term 1 2026-27', String? byId = 'u', String by = 'Tess Teacher'}) => TarbiyahAssessment.fromJson({
      '_id': id,
      'studentId': 'st1',
      'period': period,
      'periodType': 'termly',
      'assessmentDate': '2026-09-15T00:00:00.000Z',
      'overallPercentage': 75,
      'overallRating': 'good',
      'traits': [
        {'traitKey': 'sidq', 'score': 4}
      ],
      'teacherObservations': 'Kind and thoughtful',
      'assessedBy': by,
      if (byId != null) 'assessedById': byId,
    });

void main() {
  late FakeBehaviourRepository repo;

  setUpAll(loadDesignFonts);

  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakeBehaviourRepository();
  });
  tearDown(Get.reset);
  tearDown(ProbeEnv.reset);

  Future<dynamic> signIn(WidgetTester t, {List<String>? permissions}) async => (await t.runAsync(() async {
        final h = await signedIn(permissions: permissions);
        h.api.assignments = const [_cls5a];
        await h.auth.refreshProfile(force: true);
        return h;
      }))!;

  Future<void> open(WidgetTester t, Widget screen, {Size size = const Size(430, 3000), List<GetPage> pages = const []}) async {
    await t.binding.setSurfaceSize(probeSize(size));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: const Scaffold(body: Text('root')), getPages: pages));
    unawaited(Get.to(() => probeHome(screen)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }

  Future<void> settle(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
  }

  group('student history', () {
    Future<void> boot(WidgetTester t, {List<String>? permissions}) async {
      final h = await signIn(t, permissions: permissions);
      final c = Get.put(BehaviourStudentController(studentId: 'st1', initial: _zara, repository: repo, students: FakeStudentsRepository(), auth: h.auth, permissions: h.perms));
      await open(t, const BehaviourStudentScreen());
      await c.load();
      await settle(t);
    }

    testWidgets('a teacher can start a new assessment; Edit only appears on the one she recorded', (t) async {
      repo.tarbiyah = (_) async => [_ta('mine'), _ta('theirs', period: 'Term 3 2025-26', byId: 'other', by: 'Omar Colleague')];
      await boot(t);
      expect(find.byKey(const Key('tarbiyah_add')), findsOneWidget);
      expect(find.text('New Tarbiyah assessment'), findsOneWidget);
      expect(find.byKey(const ValueKey('tarbiyah_edit_mine')), findsOneWidget);
      expect(find.byKey(const ValueKey('tarbiyah_edit_theirs')), findsNothing);
      expect(find.text('Term 3 2025-26'), findsOneWidget, reason: "a colleague's assessment is still readable");
    });

    testWidgets('with no assessment yet the button is still there (and the old "created on the web" line is gone)', (t) async {
      await boot(t);
      expect(find.byKey(const Key('tarbiyah_add')), findsOneWidget);
      expect(find.byKey(const Key('student_no_tarbiyah')), findsOneWidget);
      expect(find.textContaining('created by the school on the web'), findsNothing);
    });

    testWidgets('a view-only custom role (behaviour:view) can read but has neither New nor Edit', (t) async {
      repo.tarbiyah = (_) async => [_ta('mine')];
      await boot(t, permissions: ['behaviour:view']);
      expect(find.text('Term 1 2026-27'), findsOneWidget);
      expect(find.byKey(const Key('tarbiyah_add')), findsNothing);
      expect(find.byKey(const ValueKey('tarbiyah_edit_mine')), findsNothing);
    });

    testWidgets('New opens the form route with this student; Edit opens it with the assessment', (t) async {
      repo.tarbiyah = (_) async => [_ta('mine')];
      final h = await signIn(t);
      final c = Get.put(BehaviourStudentController(studentId: 'st1', initial: _zara, repository: repo, students: FakeStudentsRepository(), auth: h.auth, permissions: h.perms));
      await open(t, const BehaviourStudentScreen(), pages: [GetPage(name: Routes.tarbiyahForm, page: () => const Scaffold(body: Text('form route')))]);
      await c.load();
      await settle(t);
      await t.tap(find.byKey(const Key('tarbiyah_add')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('form route'), findsOneWidget);
      final a = Get.arguments as TarbiyahFormArgs;
      expect(a.student.id, 'st1');
      expect(a.editing, isNull);
      expect(a.existing.map((x) => x.id), ['mine'], reason: 'the form knows which periods are taken');
      Get.back();
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.byKey(const ValueKey('tarbiyah_edit_mine')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect((Get.arguments as TarbiyahFormArgs).editing?.id, 'mine');
    });
  });

  group('form', () {
    Future<TarbiyahFormController> boot(WidgetTester t, {TarbiyahAssessment? editing, List<TarbiyahAssessment> existing = const [], List<String>? permissions, CharacterSettings settings = CharacterSettings.fallback}) async {
      final h = await signIn(t, permissions: permissions);
      final c = Get.put(TarbiyahFormController(
        args: TarbiyahFormArgs(student: student(1), settings: settings, existing: existing, editing: editing),
        repository: repo,
        auth: h.auth,
        permissions: h.perms,
        clock: () => DateTime(2026, 10, 5, 9, 30),
      ));
      await open(t, const TarbiyahFormScreen());
      await settle(t);
      return c;
    }

    testWidgets('lists the school\'s traits with the school scale; scoring and typing then saving sends the assessment', (t) async {
      final c = await boot(t, settings: const CharacterSettings(moduleDisplayName: 'Character', traitLabels: {'grit': 'Grit', 'kindness': 'Kindness'}, scaleMin: 1, scaleMax: 3));
      expect(find.text('New Character assessment'), findsOneWidget);
      expect(find.byKey(const ValueKey('tarbiyah_trait_grit')), findsOneWidget);
      expect(find.byKey(const ValueKey('tarbiyah_trait_kindness')), findsOneWidget);
      expect(find.byKey(const ValueKey('tarbiyah_trait_sidq')), findsNothing);
      expect(find.byKey(const Key('score_grit_3')), findsOneWidget);
      expect(find.byKey(const Key('score_grit_4')), findsNothing, reason: 'scale is 1 to 3');
      expect(find.text('Traits (1 to 3)'), findsOneWidget);
      // no share-with-parent switch yet (waits for visibleToParent)
      expect(find.textContaining('Share with parent'), findsNothing);
      expect(find.byType(Switch), findsNothing);

      await t.enterText(find.byKey(const Key('tarbiyah_period')), 'Term 1 2026-27');
      await t.tap(find.byKey(const Key('score_grit_3')));
      await t.pump();
      expect(find.byKey(const Key('tarbiyah_average')), findsOneWidget);
      expect(find.textContaining('Average so far: 3.0 of 3'), findsOneWidget);
      await t.enterText(find.byKey(const Key('tarbiyah_observations')), 'Very persistent');
      await t.ensureVisible(find.byKey(const Key('tarbiyah_submit')));
      await t.tap(find.byKey(const Key('tarbiyah_submit')));
      await t.runAsync(() => pumpEventQueue());
      await settle(t);
      await t.pump(const Duration(seconds: 5)); // the "saved" toast's timer
      expect(repo.calls, ['createTarbiyah']);
      expect(repo.bodies.single['traits'], [
        {'traitKey': 'grit', 'score': 3}
      ]);
      expect(repo.bodies.single['teacherObservations'], 'Very persistent');
      expect(c.saving.value, isFalse);
    });

    testWidgets('saving with nothing entered explains what is missing and sends nothing', (t) async {
      await boot(t);
      await t.ensureVisible(find.byKey(const Key('tarbiyah_submit')));
      await t.tap(find.byKey(const Key('tarbiyah_submit')));
      await settle(t);
      expect(find.textContaining('Enter the period'), findsWidgets);
      expect(repo.calls, isEmpty);
    });

    testWidgets('a duplicate period is explained on the field; a 403 from the server is a friendly message', (t) async {
      final c = await boot(t, existing: [_ta('t1', period: 'Term 1 2026-27')]);
      await t.enterText(find.byKey(const Key('tarbiyah_period')), 'term 1 2026-27');
      await t.tap(find.byKey(const Key('score_sidq_4')));
      await t.pump();
      await t.ensureVisible(find.byKey(const Key('tarbiyah_submit')));
      await t.tap(find.byKey(const Key('tarbiyah_submit')));
      await settle(t);
      expect(find.textContaining('already has an assessment'), findsWidgets);
      expect(repo.calls, isEmpty);

      await t.enterText(find.byKey(const Key('tarbiyah_period')), 'Term 2 2026-27');
      repo.onCreateTarbiyah = (b) async => throw ApiException('Forbidden resource', statusCode: 403);
      await t.ensureVisible(find.byKey(const Key('tarbiyah_submit')));
      await t.tap(find.byKey(const Key('tarbiyah_submit')));
      await t.runAsync(() => pumpEventQueue());
      await settle(t);
      expect(find.byKey(const Key('tarbiyah_submit_error')), findsOneWidget);
      expect(find.textContaining("You can't create this assessment"), findsWidgets);
      expect(c.periodC.text, 'Term 2 2026-27', reason: 'the form keeps what was typed');
    });

    testWidgets('edit mode: opens with the stored values and says Save changes', (t) async {
      await boot(t, editing: _ta('t1'), existing: [_ta('t1')]);
      expect(find.text('Edit Tarbiyah assessment'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
      expect(tester0(t, const Key('tarbiyah_period')), 'Term 1 2026-27');
    });

    testWidgets("someone else's assessment cannot be edited here", (t) async {
      await boot(t, editing: _ta('t9', byId: 'other', by: 'Omar Colleague'));
      expect(find.byKey(const Key('tarbiyah_not_author')), findsOneWidget);
      expect(find.byKey(const Key('tarbiyah_submit')), findsNothing);
    });

    testWidgets('view-only role: no access page, no form', (t) async {
      await boot(t, permissions: ['behaviour:view']);
      expect(find.byKey(const Key('tarbiyah_no_access')), findsOneWidget);
      expect(find.byKey(const Key('tarbiyah_submit')), findsNothing);
    });

    testWidgets('opened without a student (stale link): says to open a student first', (t) async {
      await open(t, const TarbiyahFormScreen());
      await settle(t);
      expect(find.byKey(const Key('tarbiyah_no_student')), findsOneWidget);
    });

    for (final w in probeWidths) {
      for (final sc in probeScales) {
        for (final d in probeDirs) {
          testWidgets(probeName('tarbiyah form', w, sc, d), (t) async {
            ProbeEnv.set(w, sc, d);
            await boot(t);
            expectNoLayoutError(t);
            expectInsideScreen(t, find.byKey(const Key('tarbiyah_period')), w);
            expectInsideScreen(t, find.byKey(const Key('tarbiyah_submit')), w);
            await t.ensureVisible(find.byKey(const Key('score_sidq_5')));
            expectInsideScreen(t, find.byKey(const Key('score_sidq_5')), w);
          });
        }
      }
    }
  });
}

String tester0(WidgetTester t, Key k) => t.widget<EditableText>(find.descendant(of: find.byKey(k), matching: find.byType(EditableText))).controller.text;
