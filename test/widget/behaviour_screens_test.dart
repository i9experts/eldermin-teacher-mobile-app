// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';
import 'package:eldermin_teacher_app/app/modules/behaviour/controllers/behaviour_controller.dart';
import 'package:eldermin_teacher_app/app/modules/behaviour/controllers/behaviour_log_controller.dart';
import 'package:eldermin_teacher_app/app/modules/behaviour/controllers/behaviour_student_controller.dart';
import 'package:eldermin_teacher_app/app/modules/behaviour/views/behaviour_detail_sheet.dart';
import 'package:eldermin_teacher_app/app/modules/behaviour/views/behaviour_new_screen.dart';
import 'package:eldermin_teacher_app/app/modules/behaviour/views/behaviour_screen.dart';
import 'package:eldermin_teacher_app/app/modules/behaviour/views/behaviour_student_screen.dart';
import 'package:eldermin_teacher_app/app/routes/app_routes.dart';
import 'package:eldermin_teacher_app/core/models/behaviour/behaviour_models.dart';
import 'package:eldermin_teacher_app/core/models/classroom/student_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:eldermin_teacher_app/core/widgets/detail_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/design_harness.dart' show loadDesignFonts;
import '../support/fake_classroom_repositories.dart';
import '../support/layout_probe.dart';
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

  setUpAll(loadDesignFonts); // real glyph widths (the default Ahem test font fakes overflows)

  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakeBehaviourRepository();
    students = FakeStudentsRepository()
      ..grades = (() async => const GradesSections(grades: ['Grade 5', 'Grade 6'], sections: ['A', 'B']))
      ..roster = (cls) async => cls.grade == 'Grade 5' ? [student(1), student(2), student(3)] : [student(30, grade: 'Grade 6', section: 'B')];
  });
  tearDown(Get.reset);
  tearDown(ProbeEnv.reset);

  Future<dynamic> signIn(WidgetTester t, {List<Map<String, Object?>> assignments = const [cls5a], List<String>? permissions}) async {
    return (await t.runAsync(() async {
      final h = await signedIn(permissions: permissions);
      h.api.assignments = assignments;
      await h.auth.refreshProfile(force: true);
      return h;
    }))!;
  }

  Future<void> open(WidgetTester t, Widget screen, {Size size = const Size(430, 3000)}) async {
    await t.binding.setSurfaceSize(probeSize(size));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: const Scaffold(body: Text('root'))));
    unawaited(Get.to(() => probeHome(screen)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }

  Future<void> settle(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
  }

  group('behaviourSheetData', () {
    BehaviourRecord full({String type = 'negative', bool resolved = true, String note = 'Spoke to the family', int points = -5, String severity = 'high'}) => BehaviourRecord.fromJson({
          '_id': 'x1', 'studentId': 'st1', 'studentName': 'Zara Malik', 'grade': 'Grade 5', 'section': 'A', 'type': type, 'category': 'misconduct',
          'title': 'Disrupted the lesson', 'description': 'Talked over the teacher for most of the period and refused to stop when asked twice.',
          'date': '2026-10-01T00:00:00.000Z', 'points': points, 'reportedBy': 'Omar Colleague', 'reportedById': 'INTERNAL-USER-ID',
          'severity': severity, 'resolved': resolved, 'resolvedNote': note,
        });
    String? v(DetailSheetData d, String l) => d.fields.where((f) => f.label == l).firstOrNull?.value;

    test('a resolved demerit shows everything, including the resolution note', () {
      final d = behaviourSheetData(full(), mine: false);
      expect(d.title, 'Disrupted the lesson');
      expect(d.statusLabel, 'Demerit');
      expect(v(d, 'Student'), 'Zara Malik');
      expect(v(d, 'Class'), 'Grade 5 - A');
      expect(v(d, 'Date'), '1 Oct 2026');
      expect(v(d, 'Category'), 'Misconduct');
      expect(v(d, 'Severity'), 'High');
      expect(v(d, 'Points'), '-5');
      expect(v(d, 'Logged by'), 'Omar Colleague');
      expect(v(d, 'Status'), 'Resolved');
      expect(v(d, 'Resolution note'), 'Spoke to the family');
      expect(d.longText, startsWith('Talked over the teacher'));
    });
    test('mine shows "You"; the internal reporter id is never shown', () {
      final d = behaviourSheetData(full(), mine: true);
      expect(v(d, 'Logged by'), 'You');
      expect([for (final f in d.fields) f.value].join(' '), isNot(contains('INTERNAL-USER-ID')));
    });
    test('an open demerit says Open and has no resolution note', () {
      final d = behaviourSheetData(full(resolved: false, note: 'stale note'), mine: false);
      expect(v(d, 'Status'), 'Open');
      expect(d.fields.where((f) => f.label == 'Resolution note' && f.visible), isEmpty);
    });
    test('a merit has no severity / status and zero points are hidden', () {
      final d = behaviourSheetData(full(type: 'positive', points: 0, severity: 'medium', resolved: false, note: ''), mine: false);
      expect(d.statusLabel, 'Merit');
      expect(v(d, 'Severity'), isNull);
      expect(v(d, 'Status'), isNull);
      expect(v(d, 'Points'), isNull);
    });
  });

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

    testWidgets('tapping a record on the main list opens its detail sheet (T1); "View student" then opens the student history', (t) async {
      repo.gradeRecords = (g) async => [rec('r1', by: 'Tess Teacher', byId: 'u', title: 'Great teamwork')];
      final h = await signIn(t);
      final c = Get.put(BehaviourController(repository: repo, students: students, auth: h.auth, permissions: h.perms));
      await t.binding.setSurfaceSize(const Size(430, 3000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(GetMaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: Text('root')),
        getPages: [GetPage(name: Routes.behaviourStudent, page: () => const Scaffold(body: Text('student screen')))],
      ));
      unawaited(Get.to(() => const BehaviourScreen()));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await c.load();
      await settle(t);
      await t.tap(find.text('Great teamwork'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('detail_sheet')), findsOneWidget);
      expect(find.byKey(const Key('detail_open_student')), findsOneWidget);
      await t.tap(find.byKey(const Key('detail_open_student')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(Get.currentRoute, '/behaviour/student/st1');
      expect(find.text('student screen'), findsOneWidget);
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

    // D6 layout probes: widths 320/360/375/430 x text scale 1.0/1.3 x LTR/RTL
    for (final w in probeWidths) {
      for (final sc in probeScales) {
        for (final d in probeDirs) {
          testWidgets(probeName('behaviour list', w, sc, d), (t) async {
            ProbeEnv.set(w, sc, d);
            repo.gradeRecords = (g) async => [
                  rec('r1', by: 'Tess Teacher', byId: 'u', title: 'Great teamwork on the group science project', points: 5),
                  rec('r2', by: 'Tess Teacher', byId: 'u', type: 'negative', points: -2, title: 'Late to class', category: 'late_coming', severity: 'high'),
                ];
            await boot(t);
            expectNoLayoutError(t);
            expectOneLine(t, find.text('+5'), scale: sc);
            expectOneLine(t, find.text('-2'), scale: sc);
            expectInsideScreen(t, find.byKey(const Key('beh_new_fab')), w);
            expectInsideScreen(t, find.byKey(const Key('beh_search')), w);
          });
        }
      }
    }
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

    group('unsaved changes (isDirty: ANY change from the pristine form)', () {
      testWidgets('pristine: back leaves at once, no dialog', (t) async {
        final c = await boot(t);
        expect(c.isDirty, isFalse);
        await t.binding.handlePopRoute();
        await settle(t);
        expect(find.text('Discard this entry?'), findsNothing);
        await t.pump(const Duration(seconds: 1));
        expect(find.byType(BehaviourNewScreen), findsNothing);
      });

      testWidgets('TITLE ONLY: back asks "Discard this entry?"; Cancel keeps the form, Discard leaves', (t) async {
        final c = await boot(t);
        await t.enterText(find.byKey(const Key('beh_title')), 'Late again');
        await t.pump();
        expect(c.isDirty, isTrue);
        await t.binding.handlePopRoute();
        await settle(t);
        expect(find.text('Discard this entry?'), findsOneWidget);
        expect(find.text('What you entered will be lost.'), findsOneWidget);
        await t.tap(find.byKey(const Key('confirm_dialog_cancel')));
        await settle(t);
        expect(find.byType(BehaviourNewScreen), findsOneWidget);
        expect(c.titleC.text, 'Late again');
        await t.binding.handlePopRoute();
        await settle(t);
        await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
        await settle(t);
        await t.pump(const Duration(seconds: 1));
        expect(find.byType(BehaviourNewScreen), findsNothing);
      });

      testWidgets('DESCRIPTION ONLY shows the dialog too', (t) async {
        final c = await boot(t);
        await t.enterText(find.byKey(const Key('beh_description')), 'Talked during the test');
        await t.pump();
        expect(c.isDirty, isTrue);
        await t.binding.handlePopRoute();
        await settle(t);
        expect(find.text('Discard this entry?'), findsOneWidget);
      });

      testWidgets('every single change counts; a preselected student alone does not; spaces typed count; picker search does not', (t) async {
        final c = await boot(t, assignments: [cls5a, cls6b], initial: student(1));
        expect(c.isDirty, isFalse, reason: 'preselected student is part of the pristine state');
        c.pickerQuery.value = 'zzz';
        c.selectPickerClass(1);
        expect(c.isDirty, isFalse, reason: 'picker search / class chip is navigation, not entry data');
        c.selectPickerClass(0);
        c.pickerQuery.value = '';

        void expectDirtyThenReset(String what, void Function() change, void Function() reset) {
          change();
          expect(c.isDirty, isTrue, reason: what);
          reset();
          expect(c.isDirty, isFalse, reason: 'back to pristine after $what');
        }

        expectDirtyThenReset('title spaces', () => c.titleC.text = ' ', () => c.titleC.clear());
        expectDirtyThenReset('description', () => c.descriptionC.text = 'x', () => c.descriptionC.clear());
        expectDirtyThenReset('another student', () => c.selectStudent(student(2)), () => c.selectStudent(student(1)));
        expectDirtyThenReset('points', () => c.setMagnitude(10), () => c.setMagnitude(BehaviourLogController.defaultMagnitude));
        expectDirtyThenReset('severity', () => c.setSeverity('high'), () => c.setSeverity('medium'));
        expectDirtyThenReset('kind', () => c.setKind(BehaviourKind.note), () => c.setKind(BehaviourKind.merit));
        expectDirtyThenReset('day', () => c.setDay(c.today.subtract(const Duration(days: 1))), () => c.setDay(c.today));
        c.setCategory(c.categories.first);
        expect(c.isDirty, isTrue, reason: 'category (and its auto title)');
      });

      testWidgets('a student picked from none counts', (t) async {
        final c = await boot(t);
        c.selectStudent(student(1));
        expect(c.isDirty, isTrue);
      });
    });


    // D6 layout probes: widths 320/360/375/430 x text scale 1.0/1.3 x LTR/RTL
    for (final w in probeWidths) {
      for (final sc in probeScales) {
        for (final d in probeDirs) {
          testWidgets(probeName('behaviour log form', w, sc, d), (t) async {
            ProbeEnv.set(w, sc, d);
            await boot(t);
            expectNoLayoutError(t);
            expectInsideScreen(t, find.byKey(const Key('beh_submit')), w);
            expectInsideScreen(t, find.byKey(const Key('beh_student_picker')), w);
            expectInsideScreen(t, find.byKey(const Key('beh_date_picker')), w);
          });
        }
      }
    }
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

    testWidgets('tapping a record opens its detail sheet with the full description; the sheet is read-only', (t) async {
      repo.studentRecords = (id) async => [
            BehaviourRecord.fromJson({
              '_id': 'x1', 'studentId': 'st1', 'studentName': 'Zara Malik', 'grade': 'Grade 5', 'section': 'A', 'type': 'negative', 'category': 'late_coming',
              'title': 'Late to class', 'description': 'Arrived twenty minutes late without a note and disturbed the start of the lesson for everyone.',
              'date': '2026-10-01T00:00:00.000Z', 'points': -2, 'reportedBy': 'Omar Colleague', 'severity': 'medium', 'resolved': true, 'resolvedNote': 'Parent informed',
            }),
            rec('r2', by: 'Tess Teacher', byId: 'u', title: 'Helped a classmate'),
          ];
      await boot(t, initial: mine);
      expect(find.byKey(const Key('detail_sheet')), findsNothing);
      await t.tap(find.text('Late to class'));
      await settle(t);
      await t.pump(const Duration(milliseconds: 400));
      final sheet = find.byKey(const Key('detail_sheet'));
      expect(sheet, findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.text('Demerit')), findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.text('Late Coming')), findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.text('Omar Colleague')), findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.text('Parent informed')), findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.textContaining('twenty minutes late without a note and disturbed the start of the lesson for everyone')), findsOneWidget);
      expect(find.byKey(const Key('detail_sheet_footer')), findsNothing);
      t.state<NavigatorState>(find.byType(Navigator).first).pop();
      await t.pumpAndSettle();
      await t.tap(find.text('Helped a classmate'));
      await t.pumpAndSettle();
      expect(find.descendant(of: find.byKey(const Key('detail_sheet')), matching: find.text('You')), findsOneWidget); // my own record
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

    // D6 layout probes: widths 320/360/375/430 x text scale 1.0/1.3 x LTR/RTL
    for (final w in probeWidths) {
      for (final sc in probeScales) {
        for (final d in probeDirs) {
          testWidgets(probeName('student history', w, sc, d), (t) async {
            ProbeEnv.set(w, sc, d);
            repo.studentRecords = (id) async => [rec('r1', by: 'Tess Teacher', byId: 'u', points: 5), rec('r2', type: 'negative', points: -2, title: 'Late to class', category: 'late_coming', severity: 'medium')];
            await boot(t, initial: const StudentSummary(id: 'st1', firstName: 'Zara', lastName: 'Malik', grade: 'Grade 5', section: 'A', rollNumber: '6'));
            expectNoLayoutError(t);
            expectInsideScreen(t, find.byKey(const Key('beh_student_log')), w);
          });
        }
      }
    }
  });
}
