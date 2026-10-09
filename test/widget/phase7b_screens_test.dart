// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';
import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/app/modules/fixtures/controllers/fixtures_controller.dart';
import 'package:eldermin_teacher_app/app/modules/fixtures/views/fixtures_screen.dart';
import 'package:eldermin_teacher_app/app/modules/leave/controllers/leave_apply_controller.dart';
import 'package:eldermin_teacher_app/app/modules/leave/controllers/leave_controller.dart';
import 'package:eldermin_teacher_app/app/modules/leave/views/leave_apply_screen.dart';
import 'package:eldermin_teacher_app/app/modules/leave/views/leave_screen.dart';
import 'package:eldermin_teacher_app/app/modules/ptm/controllers/ptm_controller.dart';
import 'package:eldermin_teacher_app/app/modules/ptm/controllers/ptm_create_controller.dart';
import 'package:eldermin_teacher_app/app/modules/ptm/controllers/ptm_detail_controller.dart';
import 'package:eldermin_teacher_app/app/modules/ptm/views/ptm_detail_screen.dart';
import 'package:eldermin_teacher_app/app/modules/ptm/views/ptm_new_screen.dart';
import 'package:eldermin_teacher_app/app/modules/ptm/views/ptm_screen.dart';
import 'package:eldermin_teacher_app/app/routes/app_routes.dart';
import 'package:eldermin_teacher_app/core/models/home/teaching.dart';
import 'package:eldermin_teacher_app/core/models/leave/leave_models.dart';
import 'package:eldermin_teacher_app/core/models/ptm/ptm_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_classroom_repositories.dart';
import '../support/fake_phase7b_repositories.dart';

const cls5a = {'gradeLevel': 'Grade 5', 'sectionName': 'A', 'subjectName': 'Mathematics'};

void main() {
  late FakePtmRepository ptm;
  late FakeFixturesRepository fx;
  late FakeLeaveRepository lv;
  late AuthController auth;
  final now = DateTime(2026, 10, 8, 13, 0);

  setUp(() {
    Get.reset();
    Get.testMode = true;
    ptm = FakePtmRepository();
    fx = FakeFixturesRepository();
    lv = FakeLeaveRepository();
  });
  tearDown(Get.reset);

  Future<void> signIn(WidgetTester t) async {
    final h = (await t.runAsync(() async {
      final h = await signedIn();
      h.api.assignments = const [cls5a];
      await h.auth.refreshProfile(force: true);
      return h;
    }))!;
    auth = h.auth;
  }

  Future<void> show(WidgetTester t, Widget home) async {
    await t.binding.setSurfaceSize(const Size(430, 1600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    Widget stub(String name) => Scaffold(body: Text('went:$name'));
    await t.pumpWidget(GetMaterialApp(
      theme: AppTheme.light,
      home: home,
      getPages: [for (final r in Routes.all) GetPage(name: r, page: () => stub(r))],
    ));
    await t.pump();
  }

  Future<void> settle(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 350));
  }

  // ───────────────────────── PTM list ─────────────────────────
  group('PTM list screen', () {
    final ahead = [meeting('up', status: 'confirmed', day: '2026-10-10', student: 'Ali Raza'), meeting('today1', status: 'requested', day: '2026-10-08', start: '15:00', end: '15:30', student: 'Zara Malik'), meeting('over', status: 'confirmed', day: '2026-10-08', start: '08:00', end: '08:20', student: 'Sana Khan')];
    final past = [meeting('done', status: 'completed', day: '2026-10-01', student: 'Omar Farooq'), meeting('open_past', status: 'requested', day: '2026-10-05', student: 'Hira Noor'), meeting('can', status: 'cancelled', day: '2026-10-03', student: 'Bilal Ahmed')];

    Future<PtmController> boot(WidgetTester t, {Future<List<ParentMeeting>> Function(String, DateTime?, DateTime?)? list}) async {
      await signIn(t);
      ptm.list = list ?? (s, f, to) async => f != null ? ahead : past;
      final c = Get.put(PtmController(repository: ptm, auth: auth, clock: () => now));
      await show(t, const PtmScreen());
      await t.runAsync(() => c.reload());
      await settle(t);
      return c;
    }

    testWidgets('opens on Today: remaining first, then "Earlier today"; tabs carry counts', (t) async {
      await boot(t);
      expect(find.text('Today (2)'), findsOneWidget);
      expect(find.text('Upcoming (1)'), findsOneWidget);
      expect(find.text('Past (2)'), findsOneWidget);
      expect(find.text('Cancelled (1)'), findsOneWidget);
      expect(find.text('Zara Malik'), findsOneWidget);
      expect(find.text('Earlier today'), findsOneWidget);
      expect(find.text('Sana Khan'), findsOneWidget);
      expect(find.text('Ali Raza'), findsNothing, reason: 'upcoming is another tab');
    });

    testWidgets('each tab shows its own meetings; an open meeting in the past says the outcome is missing', (t) async {
      await boot(t);
      await t.tap(find.text('Upcoming (1)'));
      await settle(t);
      expect(find.text('Ali Raza'), findsOneWidget);
      await t.tap(find.text('Past (2)'));
      await settle(t);
      expect(find.text('Omar Farooq'), findsOneWidget);
      expect(find.byKey(const Key('ptm_overdue_hint')), findsOneWidget);
      expect(find.text('Date has passed: outcome not recorded'), findsOneWidget);
      await t.tap(find.text('Cancelled (1)'));
      await settle(t);
      expect(find.text('Bilal Ahmed'), findsOneWidget);
      expect(find.text('CANCELLED'), findsOneWidget);
    });

    testWidgets('a card shows the date, times, class and the guardian NAME only', (t) async {
      await boot(t);
      expect(find.textContaining('Thu 8 Oct, 15:00 - 15:30'), findsOneWidget);
      expect(find.textContaining('Grade 5 - A · with Mr Malik'), findsWidgets);
      expect(find.textContaining('@'), findsNothing);
      expect(find.textContaining('0300'), findsNothing);
    });

    testWidgets('tapping a card opens /ptm/:id; the + button opens /ptm/new', (t) async {
      await boot(t);
      await t.tap(find.byKey(const ValueKey('ptm_today1')));
      await settle(t);
      expect(find.text('went:/ptm/:id'), findsOneWidget);
      Get.back();
      await settle(t);
      await t.tap(find.byKey(const Key('ptm_new')));
      await settle(t);
      expect(find.text('went:/ptm/new'), findsOneWidget);
    });

    testWidgets('an empty tab says so; no meetings at all -> the empty state', (t) async {
      final c = await boot(t, list: (s, f, to) async => f != null ? [ahead[1]] : []);
      await t.tap(find.text('Cancelled (0)'));
      await settle(t);
      expect(find.byKey(const Key('ptm_tab_empty')), findsOneWidget);
      expect(find.text('No cancelled meetings'), findsOneWidget);
      ptm.list = (s, f, to) async => [];
      await t.runAsync(() => c.reload());
      await settle(t);
      expect(find.byKey(const Key('screen_empty')), findsOneWidget);
      expect(find.text('No parent meetings yet'), findsOneWidget);
    });

    testWidgets('loading shows the shimmer; error shows Retry which reloads', (t) async {
      await signIn(t);
      final gate = Completer<List<ParentMeeting>>();
      ptm.list = (s, f, to) => gate.future;
      final c = Get.put(PtmController(repository: ptm, auth: auth, clock: () => now));
      await show(t, const PtmScreen());
      unawaited(c.reload(userInitiated: true));
      await t.pump();
      expect(find.byKey(const Key('screen_loading')), findsOneWidget);
      gate.completeError(fail7bException(500));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await settle(t);
      expect(find.byKey(const Key('screen_error')), findsOneWidget);
      ptm.list = (s, f, to) async => f != null ? ahead : past;
      await t.tap(find.text('Try again'));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await settle(t);
      expect(find.text('Zara Malik'), findsOneWidget);
    });

    testWidgets('403 -> "You don\'t have access"; 404 -> not available on this server yet', (t) async {
      final c = await boot(t, list: (s, f, to) async => fail7b(403));
      expect(find.byKey(const Key('screen_forbidden')), findsOneWidget);
      expect(find.text("You don't have access"), findsOneWidget);
      ptm.list = (s, f, to) async => fail7b(404, 'Cannot GET /api/v1/teaching/ptm');
      await t.runAsync(() => c.reload(userInitiated: true));
      await settle(t);
      expect(find.byKey(const Key('screen_unavailable')), findsOneWidget);
    });

    testWidgets('pull to refresh works in the error state too', (t) async {
      final c = await boot(t, list: (s, f, to) async => fail7b(500));
      expect(find.byKey(const Key('screen_error')), findsOneWidget);
      ptm.list = (s, f, to) async => f != null ? ahead : past;
      await t.drag(find.byType(ListView).first, const Offset(0, 400));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await settle(t);
      await t.pump(const Duration(seconds: 1));
      expect(c.load.value.hasData, isTrue);
    });
  });

  // ───────────────────────── PTM detail ─────────────────────────
  group('PTM detail screen', () {
    Future<PtmDetailController> boot(WidgetTester t, ParentMeeting m, {List<ParentMeeting> history = const []}) async {
      await signIn(t);
      ptm.one = (id) async => m;
      ptm.history = (s) async => history;
      final c = Get.put(PtmDetailController(id: m.id, repository: ptm, auth: auth, clock: () => now), tag: m.id);
      await show(t, PtmDetailScreen(meetingId: m.id));
      await t.runAsync(() => c.reload());
      await settle(t);
      return c;
    }

    bool shown(String key) => find.byKey(Key(key)).evaluate().isNotEmpty;

    testWidgets('requested + mine: Confirm, Record outcome, Reschedule, Message guardian, Cancel', (t) async {
      await boot(t, meeting('a', status: 'requested'));
      for (final k in ['ptm_confirm', 'ptm_outcome_btn', 'ptm_reschedule', 'ptm_message', 'ptm_cancel']) {
        expect(shown(k), isTrue, reason: k);
      }
      expect(find.text('Zara Malik'), findsOneWidget);
      expect(find.textContaining('With Mr Malik'), findsOneWidget);
      expect(find.text('Maths progress'), findsOneWidget);
      expect(find.byKey(const Key('ptm_not_mine')), findsNothing);
    });

    testWidgets('confirmed + mine: no Confirm button', (t) async {
      await boot(t, meeting('a', status: 'confirmed'));
      expect(shown('ptm_confirm'), isFalse);
      for (final k in ['ptm_outcome_btn', 'ptm_reschedule', 'ptm_cancel']) {
        expect(shown(k), isTrue, reason: k);
      }
    });

    testWidgets('someone else\'s meeting: read-only, no action buttons at all, and a note says why (admin/other-teacher actions are never shown)', (t) async {
      await boot(t, meeting('a', status: 'requested', teacherId: otherStaff));
      for (final k in ['ptm_confirm', 'ptm_outcome_btn', 'ptm_reschedule', 'ptm_message', 'ptm_cancel']) {
        expect(shown(k), isFalse, reason: k);
      }
      expect(find.byKey(const Key('ptm_not_mine')), findsOneWidget);
      expect(find.textContaining('Teacher: Other Teacher'), findsOneWidget);
    });

    testWidgets('completed: outcome and notes shown, action items toggle, no cancel / reschedule / outcome buttons', (t) async {
      final c = await boot(t, meeting('a', status: 'completed', attended: true, notes: 'Agreed daily reading.', items: [item('i1'), item('i2', text: 'Send log', status: 'done')]));
      expect(find.text('PARENT ATTENDED'), findsOneWidget);
      expect(find.text('Agreed daily reading.'), findsOneWidget);
      expect(find.text('Read daily'), findsOneWidget);
      for (final k in ['ptm_cancel', 'ptm_reschedule', 'ptm_outcome_btn', 'ptm_confirm']) {
        expect(shown(k), isFalse, reason: k);
      }
      ptm.item0 = (id, i, d) async => meeting('a', status: 'completed', items: [item('i1', status: 'done'), item('i2', text: 'Send log', status: 'done')]);
      await t.tap(find.byKey(const ValueKey('ptm_item_check_i1')));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await settle(t);
      expect(ptm.calls, contains('item:a:i1:done'));
      expect(c.meeting!.actionItems.first.done, isTrue);
    });

    testWidgets('other teacher\'s completed meeting: item checkboxes are disabled', (t) async {
      await boot(t, meeting('a', status: 'completed', teacherId: otherStaff, items: [item('i1')]));
      final cb = t.widget<Checkbox>(find.byKey(const ValueKey('ptm_item_check_i1')));
      expect(cb.onChanged, isNull);
    });

    testWidgets('cancelled: the reason is shown, no actions', (t) async {
      await boot(t, meeting('a', status: 'cancelled', cancelledReason: 'Parent is travelling'));
      expect(find.byKey(const Key('ptm_cancelled_box')), findsOneWidget);
      expect(find.text('Parent is travelling'), findsOneWidget);
      expect(shown('ptm_cancel'), isFalse);
    });

    testWidgets('an open meeting whose day has passed says the outcome is missing', (t) async {
      await boot(t, meeting('a', status: 'requested', day: '2026-10-05'));
      expect(find.byKey(const Key('ptm_overdue_hint')), findsOneWidget);
    });

    testWidgets('cancel sheet: a reason is required; success closes it and the screen shows the cancelled state', (t) async {
      await boot(t, meeting('a', status: 'requested'));
      await t.ensureVisible(find.byKey(const Key('ptm_cancel')));
      await t.tap(find.byKey(const Key('ptm_cancel')));
      await settle(t);
      expect(find.text('Cancel this meeting?'), findsOneWidget);
      await t.tap(find.byKey(const Key('cancel_confirm')));
      await settle(t);
      expect(find.text('Tell the parent why the meeting is cancelled'), findsOneWidget);
      expect(ptm.calls.where((x) => x.startsWith('cancel')), isEmpty);
      await t.enterText(find.byKey(const Key('cancel_reason')), 'Parent is travelling');
      await t.tap(find.byKey(const Key('cancel_confirm')));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await settle(t);
      expect(ptm.calls, contains('cancel:a'));
      expect(find.text('Cancel this meeting?'), findsNothing);
      expect(find.byKey(const Key('ptm_cancelled_box')), findsOneWidget);
    });

    testWidgets('cancel sheet: "Keep meeting" closes without a request', (t) async {
      await boot(t, meeting('a', status: 'requested'));
      await t.ensureVisible(find.byKey(const Key('ptm_cancel')));
      await t.tap(find.byKey(const Key('ptm_cancel')));
      await settle(t);
      await t.tap(find.byKey(const Key('cancel_keep')));
      await settle(t);
      expect(ptm.calls.where((x) => x.startsWith('cancel')), isEmpty);
      expect(find.text('Cancel this meeting?'), findsNothing);
    });

    testWidgets('cancel sheet: a server 403 stays in the sheet with the server text', (t) async {
      await boot(t, meeting('a', status: 'requested'));
      ptm.cancel0 = (id, r) async => fail7b(403, 'Forbidden resource');
      await t.ensureVisible(find.byKey(const Key('ptm_cancel')));
      await t.tap(find.byKey(const Key('ptm_cancel')));
      await settle(t);
      await t.enterText(find.byKey(const Key('cancel_reason')), 'Travelling');
      await t.tap(find.byKey(const Key('cancel_confirm')));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await settle(t);
      expect(find.byKey(const Key('sheet_error')), findsOneWidget);
      expect(find.text('Cancel this meeting?'), findsOneWidget);
      expect(find.text('Travelling'), findsOneWidget, reason: 'what was typed is kept');
    });

    testWidgets('outcome sheet: attended / no-show, notes, action items; a described item is sent', (t) async {
      await boot(t, meeting('a', status: 'confirmed'));
      await t.ensureVisible(find.byKey(const Key('ptm_outcome_btn')));
      await t.tap(find.byKey(const Key('ptm_outcome_btn')));
      await settle(t);
      expect(find.text('Record outcome'), findsWidgets);
      await t.enterText(find.byKey(const Key('outcome_notes')), 'Went well');
      await t.ensureVisible(find.byKey(const Key('outcome_add_item')));
      await t.tap(find.byKey(const Key('outcome_add_item')));
      await settle(t);
      await t.enterText(find.byKey(const Key('outcome_item_desc_0')), 'Read daily');
      await t.tap(find.byKey(const Key('outcome_save')));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await settle(t);
      expect(ptm.lastOutcome!.parentAttended, isTrue);
      expect((ptm.lastOutcome!.meetingNotes, ptm.lastOutcome!.actionItems.single.description), ('Went well', 'Read daily'));
    });

    testWidgets('outcome sheet: an item without a description is reported in the sheet and nothing is sent', (t) async {
      await boot(t, meeting('a', status: 'confirmed'));
      await t.ensureVisible(find.byKey(const Key('ptm_outcome_btn')));
      await t.tap(find.byKey(const Key('ptm_outcome_btn')));
      await settle(t);
      await t.ensureVisible(find.byKey(const Key('outcome_add_item')));
      await t.tap(find.byKey(const Key('outcome_add_item')));
      await settle(t);
      await t.enterText(find.byKey(const Key('outcome_item_who_0')), 'Parent');
      await t.tap(find.byKey(const Key('outcome_save')));
      await settle(t);
      expect(find.text('Describe this action item'), findsOneWidget);
      expect(ptm.calls.where((x) => x.startsWith('outcome')), isEmpty);
    });

    testWidgets('outcome sheet: typing a description clears that item\'s error', (t) async {
      await boot(t, meeting('a', status: 'confirmed'));
      await t.ensureVisible(find.byKey(const Key('ptm_outcome_btn')));
      await t.tap(find.byKey(const Key('ptm_outcome_btn')));
      await settle(t);
      await t.ensureVisible(find.byKey(const Key('outcome_add_item')));
      await t.tap(find.byKey(const Key('outcome_add_item')));
      await settle(t);
      await t.enterText(find.byKey(const Key('outcome_item_who_0')), 'Parent');
      await t.tap(find.byKey(const Key('outcome_save')));
      await settle(t);
      expect(find.text('Describe this action item'), findsOneWidget);
      await t.enterText(find.byKey(const Key('outcome_item_desc_0')), 'Read daily');
      await t.pump();
      expect(find.text('Describe this action item'), findsNothing);
    });

    testWidgets('reschedule sheet: shows the explanation, a past/empty date is refused in the sheet', (t) async {
      await boot(t, meeting('a', status: 'confirmed', day: '2026-10-01'));
      await t.ensureVisible(find.byKey(const Key('ptm_reschedule')));
      await t.tap(find.byKey(const Key('ptm_reschedule')));
      await settle(t);
      expect(find.textContaining('goes back to "Requested"'), findsOneWidget);
      expect(find.text('Choose a date'), findsWidgets, reason: 'the old date already passed: not prefilled');
      await t.tap(find.byKey(const Key('reschedule_save')));
      await settle(t);
      expect(find.text('Choose a date'), findsWidgets);
      expect(ptm.calls.where((x) => x.startsWith('reschedule')), isEmpty);
    });

    testWidgets('history section lists earlier meetings of the student', (t) async {
      await boot(t, meeting('a', status: 'requested'), history: [meeting('h1', status: 'completed', day: '2026-09-01')]);
      await t.ensureVisible(find.byKey(const ValueKey('ptm_hist_h1')));
      expect(find.byKey(const ValueKey('ptm_hist_h1')), findsOneWidget);
      expect(find.text('Earlier meetings with this student'), findsOneWidget);
    });

    testWidgets('not found', (t) async {
      await signIn(t);
      ptm.one = (id) async => fail7b(404, 'Meeting not found');
      final c = Get.put(PtmDetailController(id: 'x', repository: ptm, auth: auth), tag: 'x');
      await show(t, const PtmDetailScreen(meetingId: 'x'));
      await t.runAsync(() => c.reload());
      await settle(t);
      expect(find.byKey(const Key('ptm_not_found')), findsOneWidget);
    });

    testWidgets('403 -> You don\'t have access; 500 -> error with Try again', (t) async {
      await signIn(t);
      ptm.one = (id) async => fail7b(403);
      final c = Get.put(PtmDetailController(id: 'y', repository: ptm, auth: auth), tag: 'y');
      await show(t, const PtmDetailScreen(meetingId: 'y'));
      await t.runAsync(() => c.reload());
      await settle(t);
      expect(find.byKey(const Key('screen_forbidden')), findsOneWidget);
      ptm.one = (id) async => fail7b(500);
      await t.runAsync(() => c.reload());
      await settle(t);
      expect(find.byKey(const Key('screen_error')), findsOneWidget);
      ptm.one = (id) async => meeting(id);
      await t.tap(find.text('Try again'));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await settle(t);
      expect(find.text('Zara Malik'), findsOneWidget);
    });
  });

  // ───────────────────────── PTM create ─────────────────────────
  group('PTM create screen', () {
    Future<PtmCreateController> boot(WidgetTester t) async {
      await signIn(t);
      final students = FakeStudentsRepository()..roster = (c) async => [student(1), student(2)];
      final c = Get.put(PtmCreateController(repository: ptm, students: students, auth: auth, clock: () => now));
      await show(t, const PtmNewScreen());
      await settle(t);
      return c;
    }

    testWidgets('submitting the empty form reports the problems and sends nothing', (t) async {
      final c = await boot(t);
      await t.tap(find.byKey(const Key('ptm_new_submit')));
      await settle(t);
      expect(find.text('Choose a student'), findsWidgets);
      expect(find.text('Choose a date'), findsWidgets);
      expect(c.errors.keys, containsAll(['student', 'day', 'start', 'end']));
      expect(ptm.calls, isEmpty);
    });

    testWidgets('choosing a student shows it; a valid form is sent with MY staff id and creates the meeting', (t) async {
      final c = await boot(t);
      await t.tap(find.byKey(const Key('ptm_new_student')));
      await settle(t);
      await t.tap(find.text('First1 Last1'));
      await settle(t);
      expect(find.byKey(const Key('ptm_new_selected')), findsOneWidget);
      c.setDay(DateTime(2026, 10, 9));
      c.setStart('10:00');
      await settle(t);
      expect(find.text('10:30'), findsOneWidget, reason: 'the end suggested 30 minutes later');
      ptm.create0 = (r) async => meeting('new1', day: '2026-10-09');
      await t.ensureVisible(find.byKey(const Key('ptm_new_submit')));
      await t.tap(find.byKey(const Key('ptm_new_submit')));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await settle(t);
      expect(ptm.lastCreate!.teacherId, myStaff);
      expect(ptm.lastCreate!.toJson()['scheduledDate'], '2026-10-09');
      expect(find.text('went:/ptm/:id'), findsOneWidget);
    });

    testWidgets('the server\'s 403 text is shown on the form and the values stay', (t) async {
      final c = await boot(t);
      c.selectStudent(student(1));
      c.setDay(DateTime(2026, 10, 9));
      c.setStart('10:00');
      ptm.create0 = (r) async => fail7b(403, 'You can only create meetings for yourself');
      await t.pump();
      await t.ensureVisible(find.byKey(const Key('ptm_new_submit')));
      await t.tap(find.byKey(const Key('ptm_new_submit')));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await settle(t);
      expect(find.byKey(const Key('ptm_new_error')), findsOneWidget);
      expect(find.text('You can only create meetings for yourself'), findsWidgets);
      expect(c.student.value, isNotNull);
    });

    testWidgets('no class -> a clear message instead of the form', (t) async {
      await signIn(t);
      Get.put(PtmCreateController(repository: ptm, students: FakeStudentsRepository(), auth: auth, clock: () => now));
      auth.staffMe.value = null;
      await show(t, const PtmNewScreen());
      await settle(t);
      expect(find.byKey(const Key('ptm_new_no_classes')), findsOneWidget);
    });
  });

  // ───────────────────────── fixtures ─────────────────────────
  group('Fixtures screens', () {
    final data = [
      fixture('c1', day: '2026-10-08', period: 3),
      fixture('c2', status: 'completed', day: '2026-10-06', period: 5),
      fixture('o1', original: myStaff, substitute: otherStaff, day: '2026-10-09', period: 2),
      fixture('o2', original: myStaff, substitute: null, status: 'open', day: '2026-10-08', period: 5, subject: 'Science'),
    ];

    Future<FixturesController> boot(WidgetTester t, {Widget? screen, Future<List<Substitution>> Function(String, DateTime?)? list}) async {
      await signIn(t);
      fx.list = list ?? (s, f) async => data;
      final c = Get.put(FixturesController(repository: fx, auth: auth, clock: () => now));
      await show(t, screen ?? const FixturesScreen());
      await t.runAsync(() => c.reload());
      await settle(t);
      return c;
    }

    testWidgets('"Covering for others": date groups, period/time/class/subject, who I cover for, status chips', (t) async {
      await boot(t);
      expect(find.text('Covering for others (2)'), findsOneWidget);
      expect(find.text('My periods covered (2)'), findsOneWidget);
      expect(find.text('Today · Thu 8 Oct'), findsOneWidget);
      expect(find.text('Period 3 · 09:20 - 10:00'), findsOneWidget);
      expect(find.text('Grade 4 - B · Mathematics · Room 101'), findsNWidgets(2));
      expect(find.text('Covering for Other Teacher'), findsNWidgets(2));
      expect(find.text('ASSIGNED'), findsOneWidget);
      expect(find.text('COMPLETED'), findsOneWidget);
    });

    testWidgets('"My periods covered": covered by whom, and an open one says NOT COVERED YET', (t) async {
      await boot(t);
      await t.tap(find.text('My periods covered (2)'));
      await settle(t);
      expect(find.text('Covered by Other Teacher'), findsOneWidget);
      expect(find.text('Not covered yet'), findsOneWidget);
      expect(find.text('NOT COVERED YET'), findsOneWidget);
      expect(find.text('Tomorrow · Fri 9 Oct'), findsOneWidget);
    });

    testWidgets('empty, error, 403 and 404 states; no admin action anywhere (no assign / cancel / generate)', (t) async {
      final c = await boot(t, list: (s, f) async => []);
      expect(find.byKey(const Key('screen_empty')), findsOneWidget);
      fx.list = (s, f) async => fail7b(500);
      await t.runAsync(() => c.reload(userInitiated: true));
      await settle(t);
      expect(find.byKey(const Key('screen_error')), findsOneWidget);
      fx.list = (s, f) async => fail7b(403);
      await t.runAsync(() => c.reload(userInitiated: true));
      await settle(t);
      expect(find.byKey(const Key('screen_forbidden')), findsOneWidget);
      fx.list = (s, f) async => fail7b(404, 'Cannot GET /x');
      await t.runAsync(() => c.reload(userInitiated: true));
      await settle(t);
      expect(find.byKey(const Key('screen_unavailable')), findsOneWidget);
      for (final w in ['Assign', 'Generate', 'Suggest']) {
        expect(find.textContaining(w), findsNothing);
      }
    });

    testWidgets('detail of MY assigned cover: Mark complete -> confirm -> done; the button disappears', (t) async {
      final c = await boot(t, screen: const FixtureDetailScreen(fixtureId: 'c1'));
      expect(find.byKey(const Key('fx_complete')), findsOneWidget);
      await t.tap(find.byKey(const Key('fx_complete')));
      await settle(t);
      expect(find.text('Mark this cover as complete?'), findsOneWidget);
      await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await settle(t);
      expect(fx.calls, contains('complete:c1'));
      expect(c.find('c1')!.status, 'completed');
      expect(find.byKey(const Key('fx_complete')), findsNothing);
    });

    testWidgets('detail: no Mark complete for a completed one, for one I am the ORIGINAL of, or for an unknown id', (t) async {
      await boot(t, screen: const FixtureDetailScreen(fixtureId: 'c2'));
      expect(find.byKey(const Key('fx_complete')), findsNothing);
      expect(find.text('COMPLETED'), findsOneWidget);
      Get.reset();
      Get.testMode = true;
      await boot(t, screen: const FixtureDetailScreen(fixtureId: 'o1'));
      expect(find.byKey(const Key('fx_complete')), findsNothing);
      Get.reset();
      Get.testMode = true;
      await boot(t, screen: const FixtureDetailScreen(fixtureId: 'nope'));
      expect(find.byKey(const Key('fx_not_found')), findsOneWidget);
    });

    testWidgets('detail: a server rejection is shown as a message', (t) async {
      await boot(t, screen: const FixtureDetailScreen(fixtureId: 'c1'));
      fx.complete0 = (id) async => fail7b(404, 'Fixture not found or not in an assigned state');
      await t.tap(find.byKey(const Key('fx_complete')));
      await settle(t);
      await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await settle(t);
      expect(find.text('Fixture not found or not in an assigned state'), findsOneWidget);
    });
  });

  // ───────────────────────── leave ─────────────────────────
  group('My leave screens', () {
    Future<LeaveController> boot(WidgetTester t) async {
      final c = Get.put(LeaveController(repository: lv));
      await show(t, const LeaveScreen());
      await t.runAsync(() => c.reload());
      await settle(t);
      return c;
    }

    testWidgets('balance cards (remaining, used of entitled) and history with status chips, dates, days, reason, approver note', (t) async {
      lv.history = () async => [
            leaveRow('p', status: 'pending', from: '2026-11-02', to: '2026-11-04', days: 3),
            leaveRow('r', status: 'rejected', type: 'casual', from: '2026-10-05', to: '2026-10-05', days: 1, reason: 'Personal errand at the bank', by: 'Hina HR', note: 'Exam week.'),
            leaveRow('a', status: 'approved', type: 'sick', from: '2026-09-01', to: '2026-09-02', days: 2, by: 'Hina HR'),
          ];
      await boot(t);
      expect(find.byKey(const ValueKey('leave_bal_annual')), findsOneWidget);
      expect(find.text('17'), findsOneWidget);
      expect(find.text('4 used of 21'), findsOneWidget);
      expect(find.byKey(const ValueKey('leave_bal_hajj')), findsNothing, reason: 'nothing entitled: no card');
      expect(find.text('PENDING'), findsOneWidget);
      expect(find.text('REJECTED'), findsOneWidget);
      expect(find.text('APPROVED'), findsOneWidget);
      expect(find.text('Mon 2 Nov - Wed 4 Nov 2026 (3 days)'), findsOneWidget);
      expect(find.text('Decided by Hina HR: "Exam week."'), findsOneWidget);
      expect(find.text('Sick leave'), findsOneWidget);
      expect(find.textContaining('@'), findsNothing);
    });

    testWidgets('no policy: a calm note instead of zero cards; empty history; both without an error', (t) async {
      lv.balance = () async => balanceOf(hasPolicy: false);
      await boot(t);
      expect(find.byKey(const Key('leave_no_policy')), findsOneWidget);
      expect(find.byKey(const ValueKey('leave_bal_annual')), findsNothing);
      expect(find.byKey(const Key('leave_history_empty')), findsOneWidget);
    });

    testWidgets('one section failing keeps the other and offers Retry for it', (t) async {
      lv.history = () async => fail7b(500);
      final c = await boot(t);
      expect(find.byKey(const ValueKey('leave_bal_annual')), findsOneWidget);
      expect(find.byKey(const Key('leave_history_error')), findsOneWidget);
      lv.history = () async => [leaveRow('p')];
      await t.ensureVisible(find.text('Try again'));
      await t.tap(find.text('Try again'));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await settle(t);
      expect(find.byKey(const ValueKey('leave_p')), findsOneWidget);
      expect(c.history.value.hasData, isTrue);
    });

    testWidgets('403 on both -> one "You don\'t have access"; 404 on both -> not available on this server yet', (t) async {
      lv.balance = () async => fail7b(403);
      lv.history = () async => fail7b(403);
      final c = await boot(t);
      expect(find.byKey(const Key('screen_forbidden')), findsOneWidget);
      lv.balance = () async => fail7b(404, 'Cannot GET /a');
      lv.history = () async => fail7b(404, 'Cannot GET /b');
      await t.runAsync(() => c.reload(userInitiated: true));
      await settle(t);
      expect(find.byKey(const Key('screen_unavailable')), findsOneWidget);
    });

    testWidgets('loading shows the shimmer', (t) async {
      final gate = Completer<LeaveBalanceSummary>();
      lv.balance = () => gate.future;
      lv.history = () => Completer<List<StaffLeaveRequest>>().future;
      Get.put(LeaveController(repository: lv));
      await show(t, const LeaveScreen());
      await t.pump();
      expect(find.byKey(const Key('leave_balance_loading')), findsOneWidget);
      expect(find.byKey(const Key('leave_history_loading')), findsOneWidget);
    });

    testWidgets('Apply opens the form route', (t) async {
      await boot(t);
      await t.tap(find.byKey(const Key('leave_apply')));
      await settle(t);
      expect(find.text('went:/leave/apply'), findsOneWidget);
    });

    group('apply form', () {
      Future<LeaveApplyController> bootApply(WidgetTester t) async {
        final list = Get.put(LeaveController(repository: lv));
        await t.runAsync(() => list.reload());
        final c = Get.put(LeaveApplyController(repository: lv, list: list));
        await show(t, const LeaveApplyScreen());
        await settle(t);
        return c;
      }

      testWidgets('submitting empty shows the validation errors under the fields and sends nothing', (t) async {
        final c = await bootApply(t);
        await t.tap(find.byKey(const Key('leave_submit')));
        await settle(t);
        expect(find.text('Choose the first day'), findsWidgets);
        expect(find.text('Give a reason'), findsWidgets);
        expect(c.errors.keys, containsAll(['from', 'to', 'reason']));
        expect(lv.lastApply, isNull);
        expect(find.byKey(const Key('leave_days_hint')), findsOneWidget);
        expect(find.textContaining('The school calculates'), findsOneWidget);
      });

      testWidgets('a short reason is refused; a valid form asks for confirmation, sends, shows success and leaves', (t) async {
        final store = <StaffLeaveRequest>[];
        lv.history = () async => List.of(store);
        lv.apply0 = (b) async {
          final r = leaveRow('new1', type: b.type.wire);
          store.insert(0, r);
          return r;
        };
        final c = await bootApply(t);
        c.setType(StaffLeaveType.sick);
        c.setFrom(DateTime(2026, 11, 2));
        c.setTo(DateTime(2026, 11, 4));
        await t.enterText(find.byKey(const Key('leave_reason')), 'too short');
        await t.tap(find.byKey(const Key('leave_submit')));
        await settle(t);
        expect(find.text('Please write at least 10 characters'), findsWidgets);
        expect(lv.lastApply, isNull);
        expect(find.textContaining('3 calendar days'), findsOneWidget);
        await t.pump(const Duration(seconds: 5));
        await t.pump(const Duration(seconds: 1));
        await t.enterText(find.byKey(const Key('leave_reason')), 'Fever and a doctor rest advice');
        await t.tap(find.byKey(const Key('leave_submit')));
        await settle(t);
        expect(find.text('Send this leave request?'), findsOneWidget);
        await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await settle(t);
        expect(lv.lastApply!.toJson()['leaveType'], 'sick');
        expect(find.text('Send this leave request?'), findsNothing);
        expect(Get.find<LeaveController>().rows.first.typeWire, 'sick');
      });

      testWidgets('the balance warning and the overlap hint are informational', (t) async {
        lv.balance = () async => balanceOf(annualUsed: 20);
        lv.history = () async => [leaveRow('p', status: 'approved', from: '2026-11-03', to: '2026-11-03')];
        final c = await bootApply(t);
        c.setFrom(DateTime(2026, 11, 2));
        c.setTo(DateTime(2026, 11, 4));
        await t.pump();
        expect(find.byKey(const Key('leave_balance_hint')), findsOneWidget);
        expect(find.byKey(const Key('leave_overlap_hint')), findsOneWidget);
        expect(find.textContaining('You can still send'), findsWidgets);
      });

      testWidgets('a server error stays on the form with its text; fields are kept', (t) async {
        final c = await bootApply(t);
        c.setFrom(DateTime(2026, 11, 2));
        c.setTo(DateTime(2026, 11, 2));
        c.reasonC.text = 'Dentist appointment in town';
        lv.apply0 = (b) async => fail7b(400, 'LeaveApplication validation failed');
        await t.tap(find.byKey(const Key('leave_submit')));
        await settle(t);
        await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await settle(t);
        expect(find.byKey(const Key('leave_submit_error')), findsOneWidget);
        expect(find.text('LeaveApplication validation failed'), findsWidgets);
        expect(c.reasonC.text, 'Dentist appointment in town');
      });
    });
  });
}

ApiException fail7bException(int status) => ApiException('boom', statusCode: status);
