// ignore_for_file: invalid_use_of_protected_member
// T1 (widgets): detail sheet fields + Edit / Resolve / View student, load-more, filters, new form fields, edit screen, trait labels, 403s.
import 'dart:async';
import 'package:eldermin_teacher_app/app/modules/behaviour/controllers/behaviour_controller.dart';
import 'package:eldermin_teacher_app/app/modules/behaviour/controllers/behaviour_log_controller.dart';
import 'package:eldermin_teacher_app/app/modules/behaviour/controllers/behaviour_student_controller.dart';
import 'package:eldermin_teacher_app/app/modules/behaviour/views/behaviour_detail_sheet.dart';
import 'package:eldermin_teacher_app/app/modules/behaviour/views/behaviour_new_screen.dart';
import 'package:eldermin_teacher_app/app/modules/behaviour/views/behaviour_screen.dart';
import 'package:eldermin_teacher_app/app/modules/behaviour/views/behaviour_student_screen.dart';
import 'package:eldermin_teacher_app/app/modules/behaviour/views/widgets/behaviour_widgets.dart';
import 'package:eldermin_teacher_app/core/design/design.dart' show EmDiamondFab;
import 'package:eldermin_teacher_app/core/models/behaviour/behaviour_models.dart';
import 'package:eldermin_teacher_app/core/models/classroom/student_360.dart';
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
import '../support/fake_phase5b_repositories.dart';
import '../support/layout_probe.dart';

final now = DateTime(2026, 10, 5, 9, 30);
const cls5a = {'gradeLevel': 'Grade 5', 'sectionName': 'A', 'subjectName': 'Mathematics'};

BehaviourRecord rec(String id, {String type = 'negative', String by = 'Omar', String? byId, bool resolved = false, Map<String, Object?> extra = const {}}) => BehaviourRecord.fromJson({
      '_id': id, 'studentId': 'st1', 'studentName': 'Zara Malik', 'grade': 'Grade 5', 'section': 'A', 'type': type, 'category': 'misconduct', 'title': 'Title $id',
      'description': 'Description $id', 'date': '2026-10-01T00:00:00.000Z', 'points': type == 'negative' ? -3 : 3, 'reportedBy': by, 'severity': 'high',
      'resolved': resolved, if (byId != null) 'reportedById': byId, ...extra,
    });

void main() {
  late FakeBehaviourRepository repo;
  late FakeStudentsRepository students;
  setUpAll(loadDesignFonts);

  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakeBehaviourRepository();
    students = FakeStudentsRepository()
      ..grades = (() async => const GradesSections(grades: ['Grade 5'], sections: ['A']))
      ..roster = (cls) async => [student(1), student(2)];
  });
  tearDown(Get.reset);
  tearDown(ProbeEnv.reset);

  Future<dynamic> signIn(WidgetTester t, {List<String>? permissions}) async => (await t.runAsync(() async {
        final h = await signedIn(permissions: permissions);
        h.api.assignments = const [cls5a];
        await h.auth.refreshProfile(force: true);
        return h;
      }))!;

  Future<void> settle(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
  }

  Future<void> open(WidgetTester t, Widget screen) async {
    await t.binding.setSurfaceSize(probeSize(const Size(430, 3000)));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: const Scaffold(body: Text('root'))));
    unawaited(Get.to(() => probeHome(screen)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }

  /// A page with one button that opens the sheet.
  Future<void> openSheet(WidgetTester t, BehaviourRecord r,
      {required bool mine, BehaviourSheetActions actions = const BehaviourSheetActions(), Future<BehaviourRecord> Function()? loader, bool Function(BehaviourRecord)? mineOf}) async {
    await t.binding.setSurfaceSize(const Size(430, 2400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(GetMaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            key: const Key('open_sheet'),
            onPressed: () => showBehaviourDetailSheet(ctx, r, mine: mine, actions: actions, repository: repo, loader: loader, mineOf: mineOf),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await t.tap(find.byKey(const Key('open_sheet')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
  }

  group('detail sheet: every field a teacher may see', () {
    String? v(DetailSheetData d, String l) => d.fields.where((f) => f.label == l).firstOrNull?.value;

    test('the new fields are shown with readable values', () {
      final d = behaviourSheetData(
        rec('x', extra: {
          'location': 'Corridor', 'consequence': 'written_warning', 'actionTaken': 'Spoke to him', 'witnesses': ['Ali', 'Sara'], 'followUpRequired': true,
          'followUpDate': '2026-10-10T00:00:00.000Z', 'followUpNote': 'Call home', 'parentNotified': true, 'parentNotifiedDate': '2026-10-02T00:00:00.000Z',
          'parentNotifiedBy': 'Ms T', 'parentResponse': 'Thanks', 'verified': true, 'verifiedBy': 'Principal', 'attachments': ['https://files.test/a/report%20one.pdf?x=1'],
          'resolved': true, 'resolvedNote': 'Done', 'resolvedDate': '2026-10-06T00:00:00.000Z',
        }),
        mine: false,
      );
      expect(v(d, 'Consequence'), 'Written warning');
      expect(v(d, 'Location'), 'Corridor');
      expect(v(d, 'Action taken'), 'Spoke to him');
      expect(v(d, 'Witnesses'), 'Ali, Sara');
      expect(v(d, 'Follow-up'), 'Required by 10 Oct 2026');
      expect(v(d, 'Follow-up note'), 'Call home');
      expect(v(d, 'Parents notified'), 'Yes on 2 Oct 2026 by Ms T');
      expect(v(d, 'Parent response'), 'Thanks');
      expect(v(d, 'Verified'), 'Yes, by Principal');
      expect(v(d, 'Status'), 'Resolved');
      expect(v(d, 'Resolved on'), '6 Oct 2026');
      expect(d.attachments.single.name, 'report one.pdf');
    });

    test('empty optional fields stay hidden', () {
      final d = behaviourSheetData(rec('x'), mine: false);
      for (final l in ['Consequence', 'Location', 'Action taken', 'Witnesses', 'Follow-up', 'Parents notified', 'Parent response', 'Verified', 'Resolved on']) {
        expect(d.fields.where((f) => f.label == l && f.visible), isEmpty, reason: l);
      }
      expect(d.attachments, isEmpty);
    });

    test('resolve is offered for an open concern or a follow-up, never for a resolved or plain merit', () {
      expect(behaviourCanResolve(rec('a')), isTrue);
      expect(behaviourCanResolve(rec('a', resolved: true)), isFalse);
      expect(behaviourCanResolve(rec('a', type: 'positive')), isFalse);
      expect(behaviourCanResolve(rec('a', type: 'positive', extra: {'followUpRequired': true})), isTrue);
    });
  });

  group('detail sheet: actions', () {
    testWidgets('Edit shows only for MY record, and opens the edit callback with the record', (t) async {
      BehaviourRecord? edited;
      await openSheet(t, rec('a', byId: 'u'), mine: true, actions: BehaviourSheetActions(onEdit: (r) => edited = r));
      expect(find.byKey(const Key('detail_edit')), findsOneWidget);
      await t.tap(find.byKey(const Key('detail_edit')));
      await settle(t);
      expect(edited!.id, 'a');
      expect(find.byKey(const Key('detail_sheet')), findsNothing, reason: 'the sheet closes before the form opens');
    });

    testWidgets('a colleague\'s record has no Edit button', (t) async {
      await openSheet(t, rec('a', by: 'Omar'), mine: false, actions: BehaviourSheetActions(onEdit: (_) {}, onResolved: (_) {}));
      expect(find.byKey(const Key('detail_edit')), findsNothing);
      expect(find.byKey(const Key('detail_resolve')), findsOneWidget, reason: 'resolving is for any record of my classes');
    });

    testWidgets('without callbacks (view-only teacher) there is no footer at all', (t) async {
      await openSheet(t, rec('a', byId: 'u'), mine: true);
      expect(find.byKey(const Key('detail_sheet_footer')), findsNothing);
    });

    testWidgets('Resolve: asks for a note, calls the server, the sheet turns to Resolved and the callback gets the updated record', (t) async {
      BehaviourRecord? updated;
      repo.onResolve = (id, note) async => rec(id, resolved: true, extra: {'resolvedNote': note});
      await openSheet(t, rec('a'), mine: false, actions: BehaviourSheetActions(onResolved: (r) => updated = r));
      expect(find.text('Open'), findsOneWidget);
      await t.tap(find.byKey(const Key('detail_resolve')));
      await settle(t);
      await t.enterText(find.byKey(const Key('resolve_note')), 'Spoke with the family');
      await t.tap(find.byKey(const Key('resolve_confirm')));
      await settle(t);
      await settle(t);
      expect(repo.calls, contains('resolve:a'));
      expect(updated!.resolved, isTrue);
      expect(updated!.resolvedNote, 'Spoke with the family');
      expect(find.text('Resolved'), findsOneWidget);
      expect(find.text('Spoke with the family'), findsOneWidget);
      expect(find.byKey(const Key('detail_resolve')), findsNothing, reason: 'resolved: nothing left to resolve');
    });

    testWidgets('Resolve cancelled (sheet dismissed) sends nothing', (t) async {
      await openSheet(t, rec('a'), mine: false, actions: BehaviourSheetActions(onResolved: (_) {}));
      await t.tap(find.byKey(const Key('detail_resolve')));
      await settle(t);
      await t.tapAt(const Offset(5, 5)); // barrier
      await settle(t);
      expect(repo.calls.where((c) => c.startsWith('resolve')), isEmpty);
    });

    testWidgets('Resolve 403: a friendly message in the sheet, the record stays Open, no crash', (t) async {
      repo.onResolve = (id, note) async => throw ApiException('Access denied. This student is not in one of your classes.', statusCode: 403);
      await openSheet(t, rec('a'), mine: false, actions: BehaviourSheetActions(onResolved: (_) {}));
      await t.tap(find.byKey(const Key('detail_resolve')));
      await settle(t);
      await t.tap(find.byKey(const Key('resolve_confirm')));
      await settle(t);
      await settle(t);
      expect(find.byKey(const Key('detail_action_error')), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('"View student" closes the sheet and calls back', (t) async {
      BehaviourRecord? opened;
      await openSheet(t, rec('a'), mine: false, actions: BehaviourSheetActions(onOpenStudent: (r) => opened = r));
      await t.tap(find.byKey(const Key('detail_open_student')));
      await settle(t);
      expect(opened!.studentId, 'st1');
    });
  });

  group('detail sheet: loader (Student 360 rows)', () {
    testWidgets('loading, then the full record with its extra fields', (t) async {
      final done = Completer<BehaviourRecord>();
      await openSheet(t, rec('a', extra: {'title': 'Stub title'}), mine: false, loader: () => done.future);
      expect(find.byKey(const Key('detail_sheet')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      done.complete(rec('a', extra: {'location': 'Library', 'title': 'Full title'}));
      await settle(t);
      await settle(t);
      expect(find.text('Full title'), findsOneWidget);
      expect(find.text('Library'), findsOneWidget);
    });

    testWidgets('403 / failure: a friendly error with Try again, then success on retry; never a crash', (t) async {
      var n = 0;
      await openSheet(t, rec('a'), mine: false, loader: () async {
        if (n++ == 0) throw ApiException('Access denied. This student is not in one of your classes.', statusCode: 403);
        return rec('a', extra: {'title': 'Loaded'});
      });
      await settle(t);
      await settle(t);
      expect(find.text('Retry'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.tap(find.text('Retry'));
      await settle(t);
      await settle(t);
      expect(find.text('Loaded'), findsOneWidget);
    });

    testWidgets('"mine" is decided from the LOADED record: Edit appears once it loads as mine', (t) async {
      await openSheet(t, rec('a'), mine: false, actions: BehaviourSheetActions(onEdit: (_) {}), loader: () async => rec('a', byId: 'u'), mineOf: (r) => r.reportedById == 'u');
      await settle(t);
      await settle(t);
      expect(find.byKey(const Key('detail_edit')), findsOneWidget);
    });

    testWidgets('showBehaviourItemSheet: a legacy item shows what it has and never calls the server', (t) async {
      await t.binding.setSurfaceSize(const Size(430, 2400));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(GetMaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              key: const Key('open_sheet'),
              onPressed: () => showBehaviourItemSheet(ctx, const BehaviourItem(source: 'legacy', type: 'positive', category: 'helping', description: 'Old note', points: 2),
                  studentId: 'st1', studentName: 'Zara Malik', myId: 'u', myName: 'Tess', repository: repo),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await t.tap(find.byKey(const Key('open_sheet')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Old note'), findsOneWidget);
      expect(find.text('Zara Malik'), findsOneWidget);
      expect(repo.calls.where((c) => c.startsWith('record:')), isEmpty);
      expect(find.byKey(const Key('detail_edit')), findsNothing);
    });

    testWidgets('showBehaviourItemSheet: a records item fetches the full record by id', (t) async {
      repo.onFetchRecord = (id) async => rec(id, extra: {'location': 'Hall'});
      await t.binding.setSurfaceSize(const Size(430, 2400));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(GetMaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              key: const Key('open_sheet'),
              onPressed: () => showBehaviourItemSheet(ctx, const BehaviourItem(id: 'rid', source: 'records', type: 'negative', title: 'T'),
                  studentId: 'st1', studentName: 'Zara Malik', myId: 'u', myName: 'Tess', repository: repo),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await t.tap(find.byKey(const Key('open_sheet')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      await settle(t);
      expect(repo.calls, contains('record:rid'));
      expect(find.text('Hall'), findsOneWidget);
    });
  });

  group('Behaviour home: filters and load more', () {
    Future<BehaviourController> boot(WidgetTester t) async {
      final h = await signIn(t);
      final c = Get.put(BehaviourController(repository: repo, students: students, auth: h.auth, permissions: h.perms));
      await open(t, const BehaviourScreen());
      await t.runAsync(c.load);
      await settle(t);
      await t.runAsync(() => c.setScope(BehaviourScope.classes));
      await settle(t);
      return c;
    }

    testWidgets('the Filters button opens the sheet; applying sends the params, shows chips and the count; a chip drops its filter', (t) async {
      repo.gradeRecords = (g) async => [rec('a', byId: 'u')];
      final c = await boot(t);
      expect(find.byKey(const Key('beh_filter_btn')), findsOneWidget);
      await t.tap(find.byKey(const Key('beh_filter_btn')));
      await settle(t);
      await t.tap(find.byKey(const Key('f_type_negative')));
      await t.tap(find.byKey(const Key('f_sev_high')));
      await t.tap(find.byKey(const Key('f_res_open')));
      await settle(t);
      await t.runAsync(() async {
        await t.tap(find.byKey(const Key('f_apply')));
      });
      await settle(t);
      await settle(t);
      final q = repo.queries.last;
      expect(q['type'], 'negative');
      expect(q['severity'], 'high');
      expect(q['resolved'], 'false');
      expect(find.text('Filters (3)'), findsOneWidget);
      expect(c.filters.value.count, 3);
      expect(find.byKey(const Key('beh_filter_Open')), findsOneWidget);
      await t.runAsync(() async {
        await t.tap(find.byKey(const Key('beh_filter_Open')));
      });
      await settle(t);
      await settle(t);
      expect(c.filters.value.resolved, isNull);
      expect(c.filters.value.count, 2);
    });

    testWidgets('Clear filters resets everything', (t) async {
      repo.gradeRecords = (g) async => [rec('a')];
      final c = await boot(t);
      await t.runAsync(() => c.setFilters(const RecordFilters(type: 'positive', severity: 'low')));
      await settle(t);
      await t.tap(find.byKey(const Key('beh_filter_btn')));
      await settle(t);
      await t.runAsync(() async {
        await t.tap(find.byKey(const Key('f_clear')));
      });
      await settle(t);
      await settle(t);
      expect(c.filters.value.isActive, isFalse);
    });

    testWidgets('a filter that matches nothing keeps the controls and says so', (t) async {
      repo.gradeRecords = (g) async => [rec('a')];
      final c = await boot(t);
      repo.gradeRecords = (g) async => [];
      await t.runAsync(() => c.setFilters(const RecordFilters(severity: 'critical')));
      await settle(t);
      expect(find.byKey(const Key('beh_filter_btn')), findsOneWidget);
      expect(find.byKey(const Key('beh_filter_empty')), findsOneWidget);
    });

    testWidgets('Load more appears when there is another page, loads it, and disappears at the end', (t) async {
      repo.pageSize = 1;
      repo.gradeRecords = (g) async => [rec('r1'), rec('r2')];
      final c = await boot(t);
      expect(find.byKey(const Key('beh_load_more')), findsOneWidget);
      expect(find.text('Title r2'), findsNothing);
      await t.runAsync(() async {
        await t.tap(find.byKey(const Key('beh_load_more')));
      });
      await settle(t);
      await settle(t);
      expect(find.text('Title r2'), findsOneWidget);
      expect(find.byKey(const Key('beh_load_more')), findsNothing);
      expect(c.hasMore.value, isFalse);
    });

    testWidgets('Load more failure: message + Try again, the list stays', (t) async {
      repo.pageSize = 1;
      var fail = false;
      repo.gradeRecords = (g) async {
        if (fail) throw ApiException('offline');
        return [rec('r1'), rec('r2')];
      };
      await boot(t);
      fail = true;
      await t.runAsync(() async {
        await t.tap(find.byKey(const Key('beh_load_more')));
      });
      await settle(t);
      await settle(t);
      expect(find.byKey(const Key('beh_load_more_error')), findsOneWidget);
      expect(find.text('Title r1'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('the list FAB is the diamond FAB, and the stock extended FAB is gone from the module', (t) async {
      repo.gradeRecords = (g) async => [rec('a')];
      await boot(t);
      expect(find.byKey(const Key('beh_new_fab')), findsOneWidget);
      expect(find.byType(EmDiamondFab), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('tapping a colleague\'s record offers Resolve; mine offers Edit (view-only teachers get neither)', (t) async {
      repo.gradeRecords = (g) async => [rec('mine', byId: 'u', extra: {'title': 'Mine'}), rec('theirs', by: 'Omar', extra: {'title': 'Theirs'})];
      await boot(t);
      await t.tap(find.text('Mine'));
      await settle(t);
      expect(find.byKey(const Key('detail_edit')), findsOneWidget);
      expect(find.byKey(const Key('detail_resolve')), findsOneWidget);
      await t.tapAt(const Offset(5, 5));
      await settle(t);
      await t.tap(find.text('Theirs'));
      await settle(t);
      expect(find.byKey(const Key('detail_edit')), findsNothing);
      expect(find.byKey(const Key('detail_resolve')), findsOneWidget);
    });
  });

  group('log form: new fields and edit screen', () {
    Future<BehaviourLogController> boot(WidgetTester t, {BehaviourRecord? editing, StudentSummary? initial}) async {
      final h = await signIn(t);
      final list = Get.put(BehaviourController(repository: repo, students: students, auth: h.auth, permissions: h.perms));
      final c = Get.put(BehaviourLogController(repository: repo, students: students, auth: h.auth, permissions: h.perms, list: list, clock: () => now, initialStudent: initial, editing: editing));
      await open(t, const BehaviourNewScreen());
      await settle(t);
      return c;
    }

    testWidgets('create form offers consequence chips, location, follow-up and "Notify parents", and sends them', (t) async {
      final c = await boot(t, initial: student(1));
      await t.tap(find.byKey(const Key('cat_helping_others')));
      await t.enterText(find.byKey(const Key('beh_description')), 'Helped');
      await t.tap(find.byKey(const Key('cons_detention')));
      await t.enterText(find.byKey(const Key('beh_location')), 'Playground');
      await t.ensureVisible(find.byKey(const Key('beh_follow_up')));
      await t.tap(find.byKey(const Key('beh_follow_up')));
      await t.ensureVisible(find.byKey(const Key('beh_parent_notified')));
      await t.tap(find.byKey(const Key('beh_parent_notified')));
      await settle(t);
      expect(c.consequence.value, 'detention');
      await t.runAsync(() async {
        await t.tap(find.byKey(const Key('beh_submit')));
      });
      await settle(t);
      final b = repo.bodies.single;
      expect(b['consequence'], 'detention');
      expect(b['location'], 'Playground');
      expect(b['followUpRequired'], true);
      expect(b['parentNotified'], true);
    });

    testWidgets('edit screen: title says Edit entry, student fixed (no picker), no "Notify parents", Save changes sends a PUT', (t) async {
      final c = await boot(t, editing: rec('e1', byId: 'u', extra: {'location': 'Hall', 'consequence': 'detention'}));
      expect(find.text('Edit entry'), findsWidgets);
      expect(find.byKey(const Key('beh_student_fixed')), findsOneWidget);
      expect(find.byKey(const Key('beh_student_picker')), findsNothing);
      expect(find.byKey(const Key('beh_parent_notified')), findsNothing);
      expect(find.text('Save changes'), findsOneWidget);
      expect(c.locationC.text, 'Hall');
      await t.enterText(find.byKey(const Key('beh_title')), 'Retitled');
      await t.runAsync(() async {
        await t.tap(find.byKey(const Key('beh_submit')));
      });
      await settle(t);
      expect(repo.calls, contains('update:e1'));
      expect(repo.bodies.single['title'], 'Retitled');
      expect(c.saving.value, isFalse);
    });

    testWidgets('edit 403 from the server: a calm message, the form stays', (t) async {
      repo.onUpdate = (id, b) async => throw ApiException('You can only edit behaviour records you logged yourself.', statusCode: 403);
      await boot(t, editing: rec('e1', byId: 'u'));
      await t.enterText(find.byKey(const Key('beh_title')), 'x');
      await t.runAsync(() async {
        await t.tap(find.byKey(const Key('beh_submit')));
      });
      await settle(t);
      expect(find.byKey(const Key('beh_submit_error')), findsOneWidget);
      expect(find.byKey(const Key('beh_title')), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('student history: load more, programme name, trait labels', () {
    Future<BehaviourStudentController> boot(WidgetTester t) async {
      final h = await signIn(t);
      final c = Get.put(BehaviourStudentController(studentId: 'st1', initial: StudentSummary(id: 'st1', firstName: 'Zara', lastName: 'Malik', grade: 'Grade 5', section: 'A'), repository: repo, students: students, auth: h.auth, permissions: h.perms));
      await open(t, const BehaviourStudentScreen());
      await t.runAsync(c.load);
      await settle(t);
      return c;
    }

    testWidgets('the diamond FAB, and Load more for older records', (t) async {
      repo.pageSize = 1;
      repo.studentRecords = (id) async => [rec('r1'), rec('r2')];
      await boot(t);
      expect(find.byType(EmDiamondFab), findsOneWidget);
      expect(find.byKey(const Key('student_load_more')), findsOneWidget);
      await t.runAsync(() async {
        await t.tap(find.byKey(const Key('student_load_more')));
      });
      await settle(t);
      await settle(t);
      expect(find.text('Title r2'), findsOneWidget);
      expect(find.byKey(const Key('student_load_more')), findsNothing);
    });

    testWidgets('the server points total is shown; the programme name heads the assessments; the school\'s trait names are used', (t) async {
      repo.studentRecords = (id) async => [rec('r1')];
      repo.points = (id) async => 99;
      repo.settings = () async => const CharacterSettings(moduleDisplayName: 'Akhlaq', traitLabels: {'sidq': 'Honesty'});
      repo.tarbiyah = (id) async => [
            TarbiyahAssessment.fromJson({'_id': 't1', 'studentId': 'st1', 'period': 'Term 1', 'overallPercentage': 80, 'traits': [{'traitKey': 'sidq', 'score': 4}, {'traitKey': 'custom_trait', 'score': 3}]}),
          ];
      await boot(t);
      expect(find.text('+99'), findsOneWidget);
      expect(find.text('Akhlaq assessments'), findsOneWidget);
      expect(find.text('Honesty'), findsOneWidget);
      expect(find.text('Custom trait'), findsOneWidget, reason: 'unknown key: readable fallback');
    });

    testWidgets('settings failing (403) falls back to Tarbiyah and the built-in names without an error banner', (t) async {
      repo.settings = () async => throw ApiException('no', statusCode: 403);
      repo.tarbiyah = (id) async => [TarbiyahAssessment.fromJson({'_id': 't1', 'studentId': 'st1', 'traits': [{'traitKey': 'sidq', 'score': 4}]})];
      await boot(t);
      expect(find.text('Tarbiyah assessments'), findsOneWidget);
      expect(find.text('Truthfulness (Sidq)'), findsOneWidget);
      expect(find.byKey(const Key('section_error')), findsNothing);
    });
  });

  testWidgets('TarbiyahCard alone: labels come from the settings passed in', (t) async {
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: TarbiyahCard(
          a: TarbiyahAssessment.fromJson({'_id': 't', 'traits': [{'traitKey': 'adab', 'score': 5}]}),
          settings: const CharacterSettings(traitLabels: {'adab': 'Respect'}),
        ),
      ),
    ));
    expect(find.text('Respect'), findsOneWidget);
  });
}
