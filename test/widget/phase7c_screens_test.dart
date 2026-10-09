// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';
import 'package:eldermin_teacher_app/app/components/external_link.dart';
import 'package:eldermin_teacher_app/app/modules/about/controllers/about_controller.dart';
import 'package:eldermin_teacher_app/app/modules/about/views/about_screen.dart';
import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/app/modules/calendar/controllers/calendar_controller.dart';
import 'package:eldermin_teacher_app/app/modules/calendar/controllers/circulars_controller.dart';
import 'package:eldermin_teacher_app/app/modules/calendar/views/calendar_screen.dart';
import 'package:eldermin_teacher_app/app/modules/delete_account/controllers/delete_account_controller.dart';
import 'package:eldermin_teacher_app/app/modules/delete_account/views/delete_account_screen.dart';
import 'package:eldermin_teacher_app/app/modules/events/controllers/events_controller.dart';
import 'package:eldermin_teacher_app/app/modules/events/views/event_detail_screen.dart';
import 'package:eldermin_teacher_app/app/modules/events/views/events_screen.dart';
import 'package:eldermin_teacher_app/app/modules/help/controllers/help_controller.dart';
import 'package:eldermin_teacher_app/app/modules/help/views/help_article_screen.dart';
import 'package:eldermin_teacher_app/app/modules/help/views/help_screen.dart';
import 'package:eldermin_teacher_app/app/modules/leave/controllers/leave_controller.dart';
import 'package:eldermin_teacher_app/app/modules/leave/views/leave_screen.dart';
import 'package:eldermin_teacher_app/app/modules/more/controllers/more_controller.dart';
import 'package:eldermin_teacher_app/app/modules/more/views/more_screen.dart';
import 'package:eldermin_teacher_app/app/modules/profile/controllers/profile_controller.dart';
import 'package:eldermin_teacher_app/app/modules/profile/views/profile_screen.dart';
import 'package:eldermin_teacher_app/app/modules/safeguarding/controllers/safeguarding_controller.dart';
import 'package:eldermin_teacher_app/app/modules/safeguarding/views/safeguarding_screen.dart';
import 'package:eldermin_teacher_app/app/routes/app_routes.dart';
import 'package:eldermin_teacher_app/core/models/calendar/calendar_models.dart';
import 'package:eldermin_teacher_app/core/models/classroom/student_models.dart';
import 'package:eldermin_teacher_app/core/models/help/kb_models.dart';
import 'package:eldermin_teacher_app/core/models/safeguarding/safeguarding_models.dart';
import 'package:eldermin_teacher_app/core/services/account_repository.dart';
import 'package:eldermin_teacher_app/core/services/avatar_picker.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/auth_harness.dart';
import '../support/fake_classroom_repositories.dart';
import '../support/fake_phase7b_repositories.dart';
import '../support/fake_phase7c_repositories.dart';

const cls5a = {'gradeLevel': 'Grade 5', 'sectionName': 'A', 'subjectName': 'Mathematics'};
final now = DateTime(2026, 10, 9, 12);

CalendarEntry entry(String id, String title, {String start = '2026-10-09T00:00:00.000Z', String? end, bool allDay = true, String type = 'event', String description = ''}) => CalendarEntry.tryParse(calRow(id, title, start: start, end: end, allDay: allDay, type: type, description: description))!;
Circular circ(String id, String title, {bool ack = false, bool urgent = false, String body = '<p>Hello</p>', List<String> attachments = const []}) => Circular.tryParse(circRow(id, title, ack: ack, urgent: urgent, body: body, attachments: attachments))!;
SchoolEvent ev(String id, String title, {List<Map<String, Object?>>? sessions, String status = 'published', String description = ''}) => SchoolEvent.tryParse(eventRow(id, title, sessions: sessions, status: status, description: description))!;

void main() {
  setUp(() {
    Get.reset();
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    ExternalLinks.launcher = (u) async => true;
  });
  tearDown(Get.reset);

  Future<void> open(WidgetTester t, Widget screen, {Size size = const Size(430, 2400)}) async {
    await t.binding.setSurfaceSize(size);
    addTearDown(() => t.binding.setSurfaceSize(null));
    Widget stub(String name) => Scaffold(body: Text('went:$name'));
    await t.pumpWidget(GetMaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: Text('root')),
      getPages: [for (final r in Routes.all) GetPage(name: r, page: () => stub(r))],
    ));
    unawaited(Get.to(() => screen));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }

  Future<void> settle(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 350));
  }

  Future<AuthController> signIn(WidgetTester t) async {
    final h = (await t.runAsync(() async {
      final h = await signedIn();
      h.api.assignments = const [cls5a];
      await h.auth.refreshProfile(force: true);
      return h;
    }))!;
    return h.auth;
  }

  // ───────────────────────── calendar ─────────────────────────
  group('Calendar screen', () {
    late FakeSchoolCalendarRepository repo;
    setUp(() => repo = FakeSchoolCalendarRepository());

    Future<(CalendarController, CircularsController)> boot(WidgetTester t, {bool waitData = true}) async {
      final auth = await signIn(t);
      final cal = Get.put(CalendarController(repository: repo, clock: () => now));
      final circ = Get.put(CircularsController(repository: repo, auth: auth, local: memoryLocal()));
      await open(t, const CalendarScreen());
      if (waitData) {
        await t.runAsync(() async {
          await cal.load();
          await circ.load();
        });
        await settle(t);
      }
      return (cal, circ);
    }

    testWidgets('month view: grid, legend of the types present, selected-day list with time labels; no fee text anywhere', (t) async {
      repo.events = (f, to) async => [
            entry('h', 'Autumn break', type: 'holiday', start: '2026-10-09T00:00:00.000Z', end: '2026-10-11T00:00:00.000Z', description: 'School closed.'),
            entry('x', 'Mid-term exam', type: 'exam', start: '2026-10-09T00:00:00.000Z'),
            entry('o', 'Sports week', start: '2026-10-20T00:00:00.000Z'),
          ];
      await boot(t);
      expect(find.byKey(const Key('cal_grid')), findsOneWidget);
      expect(find.text('Autumn break'), findsOneWidget);
      expect(find.text('Mid-term exam'), findsOneWidget);
      expect(find.text('Sports week'), findsNothing, reason: 'another day');
      expect(find.text('All day'), findsWidgets);
      expect(find.text('Holiday'), findsWidgets);
      expect(find.text('Exam'), findsWidgets);
      expect(find.textContaining('(today)'), findsOneWidget);
      expect(find.textContaining('Fee'), findsNothing);
      expect(find.textContaining('outstanding'), findsNothing);
    });

    testWidgets('tapping another day of the grid changes the list; a day without entries says so', (t) async {
      repo.events = (f, to) async => [entry('o', 'Sports week', start: '2026-10-20T00:00:00.000Z')];
      final (c, _) = await boot(t);
      expect(find.byKey(const Key('day_empty')), findsOneWidget);
      await t.tap(find.text('20').first);
      await settle(t);
      expect(c.selectedDay.value, DateTime(2026, 10, 20));
      expect(find.text('Sports week'), findsOneWidget);
      expect(find.byKey(const Key('cal_today')), findsOneWidget);
      await t.tap(find.byKey(const Key('cal_today')));
      await settle(t);
      expect(c.selectedDay.value, DateTime(2026, 10, 9));
    });

    testWidgets('agenda view lists the month by day and has month arrows', (t) async {
      repo.events = (f, to) async => [entry('a', 'Break', type: 'holiday', start: '2026-10-12T00:00:00.000Z', end: '2026-10-13T00:00:00.000Z'), entry('b', 'Fair', start: '2026-10-05T00:00:00.000Z')];
      final (c, _) = await boot(t);
      await t.tap(find.text('Agenda'));
      await settle(t);
      expect(find.byKey(const Key('cal_grid')), findsNothing);
      expect(find.byKey(const ValueKey('agenda_day_2026-10-12')), findsOneWidget);
      expect(find.byKey(const ValueKey('agenda_day_2026-10-13')), findsOneWidget);
      expect(find.byKey(const ValueKey('agenda_day_2026-10-05')), findsOneWidget);
      expect(find.text('October 2026'), findsOneWidget);
      repo.events = (f, to) async => [];
      await t.tap(find.byKey(const Key('agenda_next')));
      await t.runAsync(() => pumpEventQueue());
      await settle(t);
      expect(c.focusedDay.value.month, 11);
      expect(find.text('November 2026'), findsOneWidget);
      expect(find.byKey(const Key('screen_empty')), findsOneWidget);
    });

    testWidgets('entry detail sheet: type, days, time, grades, description', (t) async {
      repo.events = (f, to) async => [entry('h', 'Autumn break', type: 'holiday', description: 'School closed for the break.')];
      await boot(t);
      await t.tap(find.byKey(const ValueKey('cal_entry_h')));
      await settle(t);
      expect(find.byKey(const Key('cal_entry_sheet')), findsOneWidget);
      expect(find.text('School closed for the break.'), findsWidgets);
      expect(find.text('Fri 9 Oct'), findsWidgets);
    });

    testWidgets('loading shimmer, then error with Retry, 403, 404', (t) async {
      final gate = Completer<List<CalendarEntry>>();
      repo.events = (f, to) => gate.future;
      final (c, _) = await boot(t, waitData: false);
      unawaited(c.load());
      await t.pump();
      expect(find.byKey(const Key('screen_loading')), findsOneWidget);
      gate.complete([]);
      await t.runAsync(() => pumpEventQueue());
      repo.events = (f, to) async => fail7c(500);
      await t.runAsync(() => c.reload());
      await settle(t);
      expect(find.byKey(const Key('screen_error')), findsOneWidget);
      repo.events = (f, to) async => [entry('o', 'Back again')];
      await t.tap(find.text('Try again'));
      await t.runAsync(() => pumpEventQueue());
      await settle(t);
      expect(find.text('Back again'), findsOneWidget);
      repo.events = (f, to) async => fail7c(403);
      await t.runAsync(() => c.reload());
      await settle(t);
      expect(find.text("You don't have access"), findsOneWidget);
      repo.events = (f, to) async => fail7c(404);
      await t.runAsync(() => c.reload());
      await settle(t);
      expect(find.text('Not available on this server yet'), findsOneWidget);
    });

    testWidgets('circulars tab: new dot, acknowledgment tag, tab badge; open sheet marks it opened; body is inert text', (t) async {
      repo.circulars = () async => [
            circ('c1', 'Fire drill', ack: true, urgent: true, body: '<p>Drill at 10:00.</p><script>alert(1)</script><a href="javascript:alert(2)">x</a><a href="https://example.test/plan">plan</a>', attachments: ['https://files.test/plan.pdf']),
            circ('c2', 'Library hours'),
          ];
      final (_, c) = await boot(t);
      await t.tap(find.byKey(const Key('tab_circulars')));
      await settle(t);
      expect(find.text('Fire drill'), findsOneWidget);
      expect(find.text('URGENT'), findsOneWidget);
      expect(find.byKey(const ValueKey('circular_needs_ack_c1')), findsOneWidget);
      expect(find.byKey(const ValueKey('circular_new_c1')), findsOneWidget);
      expect(find.byKey(const Key('circulars_pending_badge')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('circular_c1')));
      await settle(t);
      expect(find.byKey(const Key('circular_sheet')), findsOneWidget);
      expect(find.textContaining('alert'), findsNothing);
      expect(find.textContaining('Drill at 10:00.'), findsWidgets);
      expect(find.byKey(const ValueKey('circular_link_https://example.test/plan')), findsOneWidget);
      expect(find.byKey(const ValueKey('circular_link_https://files.test/plan.pdf')), findsOneWidget);
      expect(find.byKey(const ValueKey('circular_link_javascript:alert(2)')), findsNothing);
      expect(c.opened.contains('c1'), isTrue);
    });

    testWidgets('acknowledge: button, in-flight state, success replaces it and clears the tab badge; failure shows the reason and keeps the button', (t) async {
      repo.circulars = () async => [circ('c1', 'Fire drill', ack: true)];
      final (_, c) = await boot(t);
      await t.tap(find.byKey(const Key('tab_circulars')));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('circular_c1')));
      await settle(t);
      repo.ack0 = (id) async => fail7c(403, 'Forbidden resource');
      await t.tap(find.byKey(const Key('circular_ack_button')));
      await t.runAsync(() => pumpEventQueue());
      await settle(t);
      expect(find.byKey(const Key('circular_ack_error')), findsOneWidget);
      expect(find.byKey(const Key('circular_ack_button')), findsOneWidget);
      repo.ack0 = (id) async => CircularAck(DateTime.utc(2026, 10, 9));
      await t.tap(find.byKey(const Key('circular_ack_button')));
      await t.runAsync(() => pumpEventQueue());
      await settle(t);
      expect(find.byKey(const Key('circular_ack_done')), findsOneWidget);
      expect(find.byKey(const Key('circular_ack_button')), findsNothing);
      expect(c.pendingAcks, 0);
      expect(find.byKey(const Key('circulars_pending_badge')), findsNothing);
    });

    testWidgets('a circular without requiresAcknowledgment shows no acknowledge button', (t) async {
      repo.circulars = () async => [circ('c2', 'Library hours')];
      await boot(t);
      await t.tap(find.byKey(const Key('tab_circulars')));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('circular_c2')));
      await settle(t);
      expect(find.byKey(const Key('circular_ack_button')), findsNothing);
      expect(find.byKey(const Key('circular_ack_done')), findsNothing);
    });

    testWidgets('links ask for confirmation: Cancel does not open, Open launches; only http(s)', (t) async {
      final opened = <Uri>[];
      ExternalLinks.launcher = (u) async {
        opened.add(u);
        return true;
      };
      repo.circulars = () async => [circ('c1', 'With link', body: '<a href="https://example.test/plan">plan</a>')];
      await boot(t);
      await t.tap(find.byKey(const Key('tab_circulars')));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('circular_c1')));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('circular_link_https://example.test/plan')));
      await settle(t);
      expect(find.text('Open this link?'), findsOneWidget);
      await t.tap(find.byKey(const Key('confirm_dialog_cancel')));
      await settle(t);
      expect(opened, isEmpty);
      await t.tap(find.byKey(const ValueKey('circular_link_https://example.test/plan')));
      await settle(t);
      await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
      await settle(t);
      expect(opened.single.toString(), 'https://example.test/plan');
      await ExternalLinks.openWithConfirm('javascript:alert(1)');
      await settle(t);
      expect(find.text('Open this link?'), findsNothing);
    });

    testWidgets('circulars: empty, 403, 404, error + retry', (t) async {
      repo.circulars = () async => [];
      final (_, c) = await boot(t);
      await t.tap(find.byKey(const Key('tab_circulars')));
      await settle(t);
      expect(find.text('No circulars'), findsOneWidget);
      repo.circulars = () async => fail7c(500);
      await t.runAsync(() => c.load(userInitiated: true));
      await settle(t);
      expect(find.byKey(const Key('screen_error')), findsOneWidget);
      repo.circulars = () async => fail7c(403);
      await t.runAsync(() => c.load(userInitiated: true));
      await settle(t);
      expect(find.text("You don't have access"), findsOneWidget);
      repo.circulars = () async => fail7c(404);
      await t.runAsync(() => c.load(userInitiated: true));
      await settle(t);
      expect(find.text('Not available on this server yet'), findsOneWidget);
    });
  });

  // ───────────────────────── events ─────────────────────────
  group('Events screens', () {
    late FakeEventsRepository repo;
    setUp(() => repo = FakeEventsRepository());

    testWidgets('list: Upcoming and Past, cancelled tag, date to be confirmed, tap opens the detail route', (t) async {
      repo.list = () async => [
            ev('e1', 'Annual Day', sessions: [session('Day 1', '2026-10-20T09:00:00.000Z', '2026-10-20T12:00:00.000Z')]),
            ev('e2', 'Graduation', sessions: [session('Ceremony', '2026-09-01T09:00:00.000Z', '2026-09-01T10:00:00.000Z')]),
            ev('e3', 'Charity run', status: 'cancelled', sessions: [session('Run', '2026-10-25T09:00:00.000Z', '2026-10-25T10:00:00.000Z')]),
            ev('e4', 'Parent workshop', sessions: []),
          ];
      final c = Get.put(EventsController(repository: repo, clock: () => now));
      await open(t, const EventsScreen());
      await t.runAsync(() => c.load());
      await settle(t);
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Past'), findsOneWidget);
      expect(find.text('CANCELLED'), findsOneWidget);
      expect(find.text('Date to be confirmed'), findsOneWidget);
      expect(find.textContaining('ticket', findRichText: true), findsNothing);
      await t.tap(find.byKey(const ValueKey('event_e1')));
      await settle(t);
      expect(find.text('went:/events/:id'), findsOneWidget);
    });

    testWidgets('list: empty, 403, 404, error + retry', (t) async {
      final c = Get.put(EventsController(repository: repo, clock: () => now));
      await open(t, const EventsScreen());
      await t.runAsync(() => c.load());
      await settle(t);
      expect(find.byKey(const Key('screen_empty')), findsOneWidget);
      for (final e in {403: 'screen_forbidden', 404: 'screen_unavailable', 500: 'screen_error'}.entries) {
        repo.list = () async => fail7c(e.key);
        await t.runAsync(() => c.load(userInitiated: true));
        await settle(t);
        expect(find.byKey(Key(e.value)), findsOneWidget, reason: '${e.key}');
      }
    });

    testWidgets('detail: sessions, venue, plain-text description, link needs confirmation; nothing about tickets', (t) async {
      repo.one = (id) async => ev(id, 'Annual Day', description: '<p>Our <b>annual day</b>.</p><script>x()</script><a href="https://example.test/p">programme</a>');
      final c = Get.put(EventDetailController(repository: repo, eventId: 'e1', initial: ev('e1', 'Annual Day', description: '<p>Our annual day.</p>')));
      await open(t, const EventDetailScreen());
      await t.runAsync(() => c.load());
      await settle(t);
      expect(find.byKey(const Key('event_title')), findsOneWidget);
      expect(find.byKey(const Key('event_venue')), findsOneWidget);
      expect(find.text('Main Hall'), findsOneWidget);
      expect(find.byKey(const Key('event_description')), findsOneWidget);
      expect(find.textContaining('x()'), findsNothing);
      expect(find.byKey(const ValueKey('event_link_https://example.test/p')), findsOneWidget);
      expect(find.textContaining('STAFF50'), findsNothing);
      expect(find.textContaining('Ticket'), findsNothing);
    });

    testWidgets('detail: 404 says unavailable; error offers retry', (t) async {
      repo.one = (id) async => fail7c(404, 'Event not found');
      final c = Get.put(EventDetailController(repository: repo, eventId: 'e1'));
      await open(t, const EventDetailScreen());
      await t.runAsync(() => c.load());
      await settle(t);
      expect(find.byKey(const Key('screen_unavailable')), findsOneWidget);
    });
  });

  // ───────────────────────── safeguarding ─────────────────────────
  group('Safeguarding screen', () {
    late FakeSafeguardingRepository repo;
    late FakeStudentsRepository students;
    setUp(() {
      repo = FakeSafeguardingRepository();
      students = FakeStudentsRepository()..roster = (cls) async => [StudentSummary.fromJson({'_id': '64d000000000000000000501', 'firstName': 'Zara', 'lastName': 'Malik', 'currentGrade': 'Grade 5', 'currentSection': 'A'})];
    });

    Future<SafeguardingController> boot(WidgetTester t) async {
      final auth = await signIn(t);
      final c = Get.put(SafeguardingController(repository: repo, students: students, auth: auth, clock: () => now));
      await open(t, const SafeguardingScreen());
      await settle(t);
      return c;
    }

    testWidgets('the confidentiality notice is at the top; nothing about a case list', (t) async {
      await boot(t);
      expect(find.byKey(const Key('sg_notice')), findsOneWidget);
      expect(find.text(kSafeguardingNotice), findsOneWidget);
      expect(find.textContaining('immediate danger'), findsOneWidget);
      expect(find.textContaining('My cases'), findsNothing);
      expect(find.byKey(const Key('sg_no_student')), findsOneWidget);
    });

    testWidgets('empty submit lists what is missing and sends nothing; no confirmation dialog', (t) async {
      await boot(t);
      await t.tap(find.byKey(const Key('sg_submit')));
      await settle(t);
      expect(find.text('Choose what kind of concern this is'), findsWidgets);
      expect(find.text('Add a short summary'), findsWidgets);
      expect(find.text('Describe what you saw or heard'), findsWidgets);
      expect(find.text('Send this concern?'), findsNothing);
      expect(repo.bodies, isEmpty);
    });

    Future<void> fill(WidgetTester t) async {
      await t.tap(find.byKey(const Key('sg_type_bullying')));
      await t.enterText(find.byKey(const Key('sg_title')), 'Name calling');
      await t.enterText(find.byKey(const Key('sg_description')), 'Heard it in the corridor (DUMMY)');
      await t.pump();
    }

    testWidgets('confirm dialog: Keep editing sends nothing; Send sends once and shows only "Report sent" + the reference', (t) async {
      final c = await boot(t);
      await fill(t);
      await t.tap(find.byKey(const Key('sg_submit')));
      await settle(t);
      expect(find.text('Send this concern?'), findsOneWidget);
      await t.tap(find.byKey(const Key('confirm_dialog_cancel')));
      await settle(t);
      expect(repo.bodies, isEmpty);
      expect(c.titleC.text, 'Name calling');
      await t.tap(find.byKey(const Key('sg_submit')));
      await settle(t);
      await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
      await t.runAsync(() => pumpEventQueue());
      await settle(t);
      expect(repo.bodies.length, 1);
      expect(find.byKey(const Key('sg_sent_title')), findsOneWidget);
      expect(find.text('Reference: SC-2026-123'), findsOneWidget);
      expect(find.byKey(const Key('sg_title')), findsNothing, reason: 'the form is gone');
      expect(find.textContaining('Name calling'), findsNothing);
      expect(find.textContaining('corridor'), findsNothing);
      expect(c.descriptionC.text, '');
    });

    testWidgets('no reference from the server: the success view shows none', (t) async {
      repo.submit0 = (_) async => const SafeguardingReceipt(null);
      await boot(t);
      await fill(t);
      await t.tap(find.byKey(const Key('sg_submit')));
      await settle(t);
      await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
      await t.runAsync(() => pumpEventQueue());
      await settle(t);
      expect(find.byKey(const Key('sg_sent_title')), findsOneWidget);
      expect(find.byKey(const Key('sg_reference')), findsNothing);
    });

    testWidgets('403: "You don\'t have access to raise a concern here" and the form stays', (t) async {
      repo.submit0 = (_) async => fail7c(403, 'Forbidden resource');
      final c = await boot(t);
      await fill(t);
      await t.tap(find.byKey(const Key('sg_submit')));
      await settle(t);
      await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
      await t.runAsync(() => pumpEventQueue());
      await settle(t);
      expect(find.byKey(const Key('sg_submit_error')), findsOneWidget);
      expect(find.textContaining("You don't have access to raise a concern here"), findsOneWidget);
      expect(c.titleC.text, 'Name calling');
      expect(find.byKey(const Key('sg_title')), findsOneWidget);
    });

    testWidgets('server failure keeps the form and says what is kept', (t) async {
      repo.submit0 = (_) async => fail7c(500);
      final c = await boot(t);
      await fill(t);
      await t.tap(find.byKey(const Key('sg_submit')));
      await settle(t);
      await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
      await t.runAsync(() => pumpEventQueue());
      await settle(t);
      expect(find.textContaining('What you wrote is still here'), findsOneWidget);
      expect(c.descriptionC.text, isNotEmpty);
    });

    testWidgets('Discard dialog when typed text exists (Keep writing stays, Discard leaves and wipes); pristine form leaves at once', (t) async {
      final c = await boot(t);
      await t.binding.handlePopRoute();
      await settle(t);
      await t.pump(const Duration(seconds: 1));
      expect(find.byType(SafeguardingScreen), findsNothing, reason: 'nothing typed: no dialog');
      Get.reset();
      Get.testMode = true;
      final c2 = await boot(t);
      await t.enterText(find.byKey(const Key('sg_description')), 'typed');
      await t.pump();
      expect(c2.isDirty, isTrue);
      await t.binding.handlePopRoute();
      await settle(t);
      expect(find.text('Discard this concern?'), findsOneWidget);
      expect(find.text('Nothing has been sent.'), findsNothing);
      await t.tap(find.byKey(const Key('confirm_dialog_cancel')));
      await settle(t);
      expect(find.byType(SafeguardingScreen), findsOneWidget);
      expect(c2.descriptionC.text, 'typed');
      await t.binding.handlePopRoute();
      await settle(t);
      await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
      await settle(t);
      await t.pump(const Duration(seconds: 1));
      expect(find.byType(SafeguardingScreen), findsNothing);
      expect(c, isNotNull);
    });

    testWidgets('student picker lists only my class roster; choosing and clearing; "not about a student" is the default', (t) async {
      final c = await boot(t);
      await t.tap(find.byKey(const Key('sg_student_picker')));
      await settle(t);
      await t.runAsync(() => pumpEventQueue());
      await settle(t);
      expect(find.text('Only students of your classes are listed.'), findsOneWidget);
      await t.tap(find.text('Zara Malik'));
      await settle(t);
      expect(c.student.value!.id, '64d000000000000000000501');
      expect(find.byKey(const Key('sg_selected_student')), findsOneWidget);
      await t.tap(find.byKey(const Key('sg_clear_student')));
      await settle(t);
      expect(find.byKey(const Key('sg_no_student')), findsOneWidget);
    });

    testWidgets('double tap on Send: one request', (t) async {
      final gate = Completer<SafeguardingReceipt>();
      repo.submit0 = (_) => gate.future;
      await boot(t);
      await fill(t);
      await t.tap(find.byKey(const Key('sg_submit')));
      await settle(t);
      await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
      await settle(t);
      await t.tap(find.byKey(const Key('sg_submit')), warnIfMissed: false);
      await settle(t);
      expect(repo.bodies.length, 1);
      gate.complete(const SafeguardingReceipt('SC-1'));
      await t.runAsync(() => pumpEventQueue());
      await settle(t);
    });
  });

  // ───────────────────────── profile ─────────────────────────
  group('Profile screen', () {
    late FakeProfileRepository repo;
    late FakeAvatarPicker picker;
    setUp(() {
      repo = FakeProfileRepository();
      picker = FakeAvatarPicker();
    });

    Future<(ProfileController, AuthController)> boot(WidgetTester t) async {
      final auth = await signIn(t);
      final c = Get.put(ProfileController(repository: repo, picker: picker, auth: auth));
      await open(t, const ProfileScreen());
      await t.runAsync(() => c.load());
      await settle(t);
      return (c, auth);
    }

    testWidgets('read-only details from the profile; missing values are omitted, not filled with placeholders', (t) async {
      await boot(t);
      expect(find.byKey(const Key('profile_name')), findsOneWidget);
      expect(find.text('Tess Teacher'), findsOneWidget);
      expect(find.text('t@s.test'), findsWidgets);
      expect(find.text('Main Campus'), findsOneWidget);
      expect(find.text('Science'), findsOneWidget);
      expect(find.byKey(const Key('profile_designation')), findsNothing, reason: 'the harness sends no designation');
      expect(find.textContaining('N/A'), findsNothing);
      expect(find.byKey(const Key('profile_readonly_note')), findsOneWidget);
      expect(find.byKey(const Key('avatar_gallery')), findsOneWidget);
      expect(find.byKey(const Key('avatar_camera')), findsOneWidget);
    });

    testWidgets('help / about / delete account entries open their routes', (t) async {
      await boot(t);
      await t.scrollUntilVisible(find.byKey(const Key('profile_help')), 200, scrollable: find.byType(Scrollable).first);
      await t.tap(find.byKey(const Key('profile_help')));
      await settle(t);
      expect(find.text('went:/help'), findsOneWidget);
    });

    testWidgets('upload success shows the confirmation', (t) async {
      final (c, auth) = await boot(t);
      await t.tap(find.byKey(const Key('avatar_gallery')));
      await t.runAsync(() => pumpEventQueue());
      await settle(t);
      expect(find.byKey(const Key('avatar_outcome_uploaded')), findsOneWidget);
      expect(find.text('Your photo was updated.'), findsOneWidget);
      expect(auth.user.value!.avatarUrl, isNotNull);
      expect(c.outcome.value, AvatarOutcome.uploaded);
    });

    testWidgets('503: "Upload unavailable", both photo buttons disabled (no retry hammering)', (t) async {
      repo.upload = (p, n, m) async => fail7c(503, 'File uploads are not available on this server (storage is not configured).');
      await boot(t);
      await t.tap(find.byKey(const Key('avatar_gallery')));
      await t.runAsync(() => pumpEventQueue());
      await settle(t);
      expect(find.text('Upload unavailable'), findsOneWidget);
      expect(find.byKey(const Key('avatar_outcome_unavailable')), findsOneWidget);
      expect(t.widget<OutlinedButton>(find.byKey(const Key('avatar_gallery'))).onPressed, isNull);
      expect(t.widget<OutlinedButton>(find.byKey(const Key('avatar_camera'))).onPressed, isNull);
    });

    testWidgets('permission denied: explanation and an Open Settings button', (t) async {
      picker.result = (s) async => throw AvatarPickDenied(s);
      await boot(t);
      await t.tap(find.byKey(const Key('avatar_camera')));
      await t.runAsync(() => pumpEventQueue());
      await settle(t);
      expect(find.byKey(const Key('avatar_outcome_denied')), findsOneWidget);
      expect(find.byKey(const Key('avatar_open_settings')), findsOneWidget);
      expect(find.textContaining('camera'), findsWidgets);
    });

    testWidgets('too large / wrong type: refusal text, nothing uploaded', (t) async {
      picker.result = (_) async => const PickedAvatar(path: '/tmp/a.gif', name: 'a.gif', size: 100);
      await boot(t);
      await t.tap(find.byKey(const Key('avatar_gallery')));
      await t.runAsync(() => pumpEventQueue());
      await settle(t);
      expect(find.text('Please choose a JPG, PNG or WebP photo.'), findsOneWidget);
      expect(repo.uploads, isEmpty);
    });

    testWidgets('uploading shows progress and disables the buttons', (t) async {
      final gate = Completer<String>();
      repo.upload = (p, n, m) => gate.future;
      await boot(t);
      await t.tap(find.byKey(const Key('avatar_gallery')));
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('avatar_busy')), findsOneWidget);
      expect(t.widget<OutlinedButton>(find.byKey(const Key('avatar_gallery'))).onPressed, isNull);
      gate.complete('https://files.test/a.png');
      await t.runAsync(() => pumpEventQueue());
      await settle(t);
    });
  });

  // ───────────────────────── help / about / delete ─────────────────────────
  group('Help screens', () {
    late FakeKbRepository repo;
    setUp(() => repo = FakeKbRepository());
    const a1 = KbArticle(module: 'hr', tabKey: 'dashboard', title: 'Dashboard', tagline: 'Your morning read', order: 1);
    const g1 = KbArticle(module: 'general', tabKey: 'start', title: 'Getting started', order: 1);

    testWidgets('list by module, contact card; tap opens the article route', (t) async {
      repo.listRows = () async => [a1, g1];
      final c = Get.put(HelpController(repository: repo));
      await open(t, const HelpScreen());
      await t.runAsync(() => c.load());
      await settle(t);
      expect(find.text('Staff & HR'), findsOneWidget);
      expect(find.text('General'), findsWidgets);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.byKey(const Key('help_contact')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('help_hr/dashboard')));
      await settle(t);
      expect(find.text('went:/help/:module/:tabKey'), findsOneWidget);
    });

    testWidgets('search: submit shows results; no match message; clear returns to the list; states', (t) async {
      repo.listRows = () async => [a1, g1];
      final c = Get.put(HelpController(repository: repo));
      await open(t, const HelpScreen());
      await t.runAsync(() => c.load());
      await settle(t);
      repo.search0 = (q) async => [g1];
      await t.enterText(find.byKey(const Key('help_search')), 'start');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.runAsync(() => pumpEventQueue());
      await settle(t);
      expect(repo.calls.contains('search:start'), isTrue);
      expect(find.text('Getting started'), findsOneWidget);
      expect(find.text('Dashboard'), findsNothing);
      repo.search0 = (q) async => [];
      await t.enterText(find.byKey(const Key('help_search')), 'zzz');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.runAsync(() => pumpEventQueue());
      await settle(t);
      expect(find.text('No articles match'), findsOneWidget);
      await t.tap(find.byKey(const Key('help_search_clear')));
      await settle(t);
      expect(find.text('Dashboard'), findsOneWidget);
    });

    testWidgets('list: empty, 403, 404, error', (t) async {
      final c = Get.put(HelpController(repository: repo));
      await open(t, const HelpScreen());
      await t.runAsync(() => c.load());
      await settle(t);
      expect(find.byKey(const Key('screen_empty')), findsOneWidget);
      for (final e in {403: 'screen_forbidden', 404: 'screen_unavailable', 500: 'screen_error'}.entries) {
        repo.listRows = () async => fail7c(e.key);
        await t.runAsync(() => c.load(userInitiated: true));
        await settle(t);
        expect(find.byKey(Key(e.value)), findsOneWidget);
      }
    });

    testWidgets('article: markdown rendered as inert text; script / iframe / image / javascript links never appear; https link needs confirmation', (t) async {
      const body = '# Welcome\n\nThis is **bold** and [a safe link](https://example.test/ok) and [bad](javascript:alert(1)).\n\n- one\n- two\n\n<script>alert("xss")</script><iframe src="https://evil.test"></iframe><img src="https://t.test/x.png" onerror="alert(2)">\n\n![remote](https://t.test/pixel.png)';
      repo.one = (m, tk) async => const KbArticle(module: 'general', tabKey: 'start', title: 'Getting started', tagline: 'A tour', body: body, steps: ['Sign in', 'Open Classes']);
      final c = Get.put(HelpArticleController(repository: repo, module: 'general', tabKey: 'start'));
      await open(t, const HelpArticleScreen());
      await t.runAsync(() => c.load());
      await settle(t);
      expect(find.byKey(const Key('help_article_title')), findsOneWidget);
      expect(find.byKey(const Key('rich_text')), findsWidgets);
      expect(find.textContaining('xss'), findsNothing);
      expect(find.textContaining('evil.test'), findsNothing);
      expect(find.textContaining('onerror'), findsNothing);
      expect(find.byType(Image), findsNothing, reason: 'no remote images');
      expect(find.textContaining('This is bold and a safe link and bad.', findRichText: true), findsOneWidget);
      expect(find.text('How to use it'), findsOneWidget);
      expect(find.textContaining('Sign in', findRichText: true), findsOneWidget);
    });

    testWidgets('article 404 and error', (t) async {
      repo.one = (m, tk) async => fail7c(404, 'No KB article found for hr/x');
      final c = Get.put(HelpArticleController(repository: repo, module: 'hr', tabKey: 'x'));
      await open(t, const HelpArticleScreen());
      await t.runAsync(() => c.load());
      await settle(t);
      expect(find.byKey(const Key('screen_unavailable')), findsOneWidget);
    });
  });

  group('About screen', () {
    testWidgets('name, version, build and the API host only', (t) async {
      final c = Get.put(AboutController(loader: () async => const AppInfo('Eldermin Teacher', '0.1.0', '7')));
      await open(t, const AboutScreen());
      await t.runAsync(() => c.load());
      await settle(t);
      expect(find.byKey(const Key('about_name')), findsOneWidget);
      expect(find.text('0.1.0'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.byKey(const Key('about_host')), findsOneWidget);
      expect(find.textContaining('http'), findsNothing, reason: 'host only, never a URL');
      expect(find.textContaining('/api/'), findsNothing);
    });

    testWidgets('a failing loader shows Unavailable and does not crash', (t) async {
      final c = Get.put(AboutController(loader: () async => throw StateError('x')));
      await open(t, const AboutScreen());
      await t.runAsync(() => c.load());
      await settle(t);
      expect(find.text('Unavailable'), findsNWidgets(2));
    });
  });

  group('Delete account screen', () {
    late FakeAccountRepository repo;
    setUp(() => repo = FakeAccountRepository());

    testWidgets('explains it is a request; button disabled until DELETE is typed; sends; shows status and keeps the user signed in', (t) async {
      final auth = await signIn(t);
      final c = Get.put(DeleteAccountController(repository: repo));
      await open(t, const DeleteAccountScreen());
      await settle(t);
      expect(find.textContaining('request, not an instant deletion'), findsOneWidget);
      expect(find.textContaining('stays active'), findsOneWidget);
      expect(t.widget<ElevatedButton>(find.byKey(const Key('delete_submit'))).onPressed, isNull);
      await t.enterText(find.byKey(const Key('delete_reason')), 'Moving abroad (DUMMY)');
      await t.enterText(find.byKey(const Key('delete_confirm_field')), 'delet');
      await t.pump();
      expect(t.widget<ElevatedButton>(find.byKey(const Key('delete_submit'))).onPressed, isNull);
      await t.enterText(find.byKey(const Key('delete_confirm_field')), 'DELETE');
      await t.pump();
      await t.tap(find.byKey(const Key('delete_submit')));
      await t.runAsync(() => pumpEventQueue());
      await settle(t);
      expect(repo.reasons, ['Moving abroad (DUMMY)']);
      expect(find.byKey(const Key('delete_done_title')), findsOneWidget);
      expect(find.text('Request sent'), findsOneWidget);
      expect(find.text('Status: Pending'), findsOneWidget);
      expect(find.textContaining('retained until they process it'), findsOneWidget);
      expect(auth.status.value, AuthStatus.authenticated);
      expect(c.result.value, isNotNull);
    });

    testWidgets('already requested', (t) async {
      repo.request0 = (_) async => const DeletionRequestResult(requestId: 'r1', status: 'pending', alreadyRequested: true);
      Get.put(DeleteAccountController(repository: repo));
      await open(t, const DeleteAccountScreen());
      await t.enterText(find.byKey(const Key('delete_confirm_field')), 'DELETE');
      await t.pump();
      await t.tap(find.byKey(const Key('delete_submit')));
      await t.runAsync(() => pumpEventQueue());
      await settle(t);
      expect(find.text('You already have a pending request'), findsOneWidget);
      expect(find.text('Request sent'), findsNothing);
    });

    testWidgets('403 and 404 messages; the form stays', (t) async {
      final c = Get.put(DeleteAccountController(repository: repo));
      await open(t, const DeleteAccountScreen());
      await t.enterText(find.byKey(const Key('delete_confirm_field')), 'DELETE');
      await t.pump();
      repo.request0 = (_) async => fail7c(403, 'Forbidden');
      await t.tap(find.byKey(const Key('delete_submit')));
      await t.runAsync(() => pumpEventQueue());
      await settle(t);
      expect(find.textContaining("You don't have access to request account deletion"), findsOneWidget);
      repo.request0 = (_) async => fail7c(404, 'Cannot POST');
      await t.tap(find.byKey(const Key('delete_submit')));
      await t.runAsync(() => pumpEventQueue());
      await settle(t);
      expect(find.textContaining('not available on this server yet'), findsOneWidget);
      expect(find.byKey(const Key('delete_confirm_field')), findsOneWidget);
      expect(c.result.value, isNull);
    });
  });

  // ───────────────────────── More + leave ─────────────────────────
  group('More tab entries', () {
    testWidgets('calendar, events, safeguarding, profile, help, about and delete account are live; sign out still there', (t) async {
      final h = (await t.runAsync(() => signedIn()))!;
      Get.put(MoreController());
      await open(t, const Scaffold(body: MoreScreen()));
      await settle(t);
      for (final title in ['School calendar', 'Events', 'Raise a concern', 'Profile', 'Help', 'About', 'Delete account', 'Sign out']) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      expect(find.textContaining('Coming soon'), findsNothing);
      expect(h.auth.status.value, AuthStatus.authenticated);
      await t.tap(find.text('Raise a concern'));
      await settle(t);
      expect(find.text('went:/safeguarding'), findsOneWidget);
    });
  });

  group('Leave screen: the Apply button does not cover any card', () {
    testWidgets('the button sits in a bottom bar below the list: no card rectangle overlaps it, at the top and after scrolling to the end', (t) async {
      final lv = FakeLeaveRepository()
        ..balance = (() async => balanceOf())
        ..history = (() async => [for (var i = 0; i < 12; i++) leaveRow('64d00000000000000000b0${i.toString().padLeft(2, '0')}', type: 'sick')]);
      final c = Get.put(LeaveController(repository: lv));
      await open(t, const LeaveScreen(), size: const Size(430, 900));
      await t.runAsync(() => c.reload());
      await settle(t);
      final button = t.getRect(find.byKey(const Key('leave_apply')));
      final viewport = t.getRect(find.byType(ListView).first);
      // Cards are clipped to the list viewport; the viewport itself must end above the button, so no visible part of any card can sit under it.
      bool visibleOverlap() {
        for (final e in find.byWidgetPredicate((w) => w.key is ValueKey && (w.key as ValueKey).value.toString().startsWith('leave_64d')).evaluate()) {
          final visible = t.getRect(find.byWidget(e.widget)).intersect(viewport);
          if (visible.width > 0 && visible.height > 0 && visible.overlaps(button)) return true;
        }
        return false;
      }

      expect(viewport.bottom, lessThanOrEqualTo(button.top), reason: 'the list ends where the bar starts');
      expect(visibleOverlap(), isFalse, reason: 'at the top');
      await t.drag(find.byType(ListView).first, const Offset(0, -5000));
      await settle(t);
      expect(visibleOverlap(), isFalse, reason: 'at the end');
      expect(find.byKey(const ValueKey('leave_64d00000000000000000b011')), findsOneWidget, reason: 'the last card is reachable');
      expect(button.bottom, lessThanOrEqualTo(900));
    });
  });
}
