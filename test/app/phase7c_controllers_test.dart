// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';
import 'package:eldermin_teacher_app/app/common/action_failure.dart';
import 'package:eldermin_teacher_app/app/modules/about/controllers/about_controller.dart';
import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/app/modules/calendar/controllers/calendar_controller.dart';
import 'package:eldermin_teacher_app/app/modules/calendar/controllers/circulars_controller.dart';
import 'package:eldermin_teacher_app/app/modules/delete_account/controllers/delete_account_controller.dart';
import 'package:eldermin_teacher_app/app/modules/events/controllers/events_controller.dart';
import 'package:eldermin_teacher_app/app/modules/help/controllers/help_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/models/section_state.dart';
import 'package:eldermin_teacher_app/app/modules/profile/controllers/profile_controller.dart';
import 'package:eldermin_teacher_app/app/modules/safeguarding/controllers/safeguarding_controller.dart';
import 'package:eldermin_teacher_app/core/models/calendar/calendar_models.dart';
import 'package:eldermin_teacher_app/core/models/classroom/student_models.dart';
import 'package:eldermin_teacher_app/core/models/help/kb_models.dart';
import 'package:eldermin_teacher_app/core/models/safeguarding/safeguarding_models.dart';
import 'package:eldermin_teacher_app/core/services/account_repository.dart';
import 'package:eldermin_teacher_app/core/services/avatar_picker.dart';
import 'package:eldermin_teacher_app/core/services/circular_local_state.dart';
import 'package:eldermin_teacher_app/core/services/events_repository.dart';
import 'package:eldermin_teacher_app/core/services/school_calendar_repository.dart';
import 'package:eldermin_teacher_app/core/utils/avatar_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/auth_harness.dart';
import '../support/fake_classroom_repositories.dart';
import '../support/fake_phase7b_repositories.dart' show RecordingClient, myStaff;
import '../support/fake_phase7c_repositories.dart';

CalendarEntry entry(String id, String title, {String start = '2026-10-12T00:00:00.000Z', String? end, bool allDay = true, String type = 'event'}) => CalendarEntry.tryParse(calRow(id, title, start: start, end: end, allDay: allDay, type: type))!;
Circular circ(String id, String title, {bool ack = false, List<String> roles = const ['staff'], String status = 'published', String published = '2026-10-08T06:00:00.000Z', String scope = 'school', List<String> staffIds = const []}) =>
    Circular.tryParse(circRow(id, title, ack: ack, roles: roles, status: status, published: published, scope: scope, staffIds: staffIds))!;
SchoolEvent ev(String id, String title, {List<Map<String, Object?>>? sessions, String status = 'published', String visibility = 'public'}) => SchoolEvent.tryParse(eventRow(id, title, sessions: sessions, status: status, visibility: visibility))!;
StudentSummary stu(String id, String name, {String grade = 'Grade 5', String section = 'A'}) => StudentSummary.fromJson({'_id': id, 'firstName': name.split(' ').first, 'lastName': name.split(' ').last, 'currentGrade': grade, 'currentSection': section});

final now = DateTime(2026, 10, 9, 12);
const cls5a = {'gradeLevel': 'Grade 5', 'sectionName': 'A', 'subjectName': 'Mathematics'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    Get.reset();
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(Get.reset);

  group('CalendarController', () {
    late FakeSchoolCalendarRepository repo;
    setUp(() => repo = FakeSchoolCalendarRepository());
    CalendarController make() => CalendarController(repository: repo, clock: () => now);

    test('first load asks for the month grid window in UTC days (month -7 .. +7 days)', () async {
      repo.events = (f, t) async => [entry('a', 'Holiday', type: 'holiday')];
      final c = make();
      await c.load();
      expect((repo.windows.single.from, repo.windows.single.to), (DateTime(2026, 9, 24), DateTime(2026, 11, 7)));
      expect(c.state.value.status, SectionStatus.data);
    });

    test('day list: all-day first, then timed by time; multi-day shows on every day inclusive', () async {
      repo.events = (f, t) async => [
            entry('t', 'Training', start: DateTime(2026, 10, 12, 14).toUtc().toIso8601String(), end: DateTime(2026, 10, 12, 15).toUtc().toIso8601String(), allDay: false), // local 14:00-15:00 on the 12th, in any zone
            entry('a', 'Break', type: 'holiday', start: '2026-10-12T00:00:00.000Z', end: '2026-10-14T00:00:00.000Z'),
            entry('b', 'Another all day', start: '2026-10-12T00:00:00.000Z'),
          ];
      final c = make();
      await c.load();
      final firstDay = c.entriesOn(DateTime(2026, 10, 12)).map((e) => e.id).toList();
      expect(firstDay.take(2).toSet(), {'a', 'b'});
      expect(firstDay.length, 3);
      expect(c.entriesOn(DateTime(2026, 10, 13)).map((e) => e.id), ['a']);
      expect(c.entriesOn(DateTime(2026, 10, 14)).map((e) => e.id), ['a']);
      expect(c.entriesOn(DateTime(2026, 10, 15)), isEmpty);
      expect(c.entriesOn(DateTime(2026, 10, 11)), isEmpty);
    });

    test('agenda: only days with entries, ascending, multi-day repeated, clipped to the month', () async {
      repo.events = (f, t) async => [
            entry('a', 'Break', type: 'holiday', start: '2026-10-30T00:00:00.000Z', end: '2026-11-02T00:00:00.000Z'),
            entry('b', 'Fair', start: '2026-10-05T00:00:00.000Z'),
          ];
      final c = make();
      await c.load();
      final ag = c.agendaFor(DateTime(2026, 10, 9));
      expect(ag.keys.toList(), [DateTime(2026, 10, 5), DateTime(2026, 10, 30), DateTime(2026, 10, 31)]);
      expect(ag[DateTime(2026, 10, 31)]!.single.id, 'a');
    });

    test('months are fetched once and cached; going to another month fetches it; Today returns to this month without refetching', () async {
      repo.events = (f, t) async => [entry('a', 'Fair', start: '2026-10-05T00:00:00.000Z')];
      final c = make();
      await c.load();
      c.setFocused(DateTime(2026, 11, 1));
      await pumpEventQueue();
      expect(repo.windows.length, 2);
      expect(repo.windows.last.from, DateTime(2026, 10, 25));
      c.goToToday();
      await pumpEventQueue();
      expect(repo.windows.length, 2, reason: 'October is cached');
      expect(c.selectedDay.value, DateTime(2026, 10, 9));
      expect(c.state.value.status, SectionStatus.data);
    });

    test('selecting a day of another month moves the focus and loads that month', () async {
      repo.events = (f, t) async => [];
      final c = make();
      await c.load();
      c.selectDay(DateTime(2026, 11, 3));
      await pumpEventQueue();
      expect(c.focusedDay.value, DateTime(2026, 11, 3));
      expect(repo.windows.length, 2);
    });

    test('empty month, 403, 404, 500 states; a failed background reload keeps the data, a user retry shows the error', () async {
      repo.events = (f, t) async => [];
      final c = make();
      await c.load();
      expect(c.state.value.status, SectionStatus.empty);
      for (final e in {403: SectionStatus.forbidden, 404: SectionStatus.unavailable, 500: SectionStatus.error}.entries) {
        repo.events = (f, t) async => fail7c(e.key);
        await c.reload();
        expect(c.state.value.status, e.value, reason: '${e.key}');
      }
      repo.events = (f, t) async => [entry('a', 'Fair')];
      await c.reload();
      expect(c.state.value.hasData, isTrue);
      repo.events = (f, t) async => fail7c(500);
      await c.load(force: true); // background: keeps the data
      expect(c.state.value.hasData, isTrue);
      await c.reload();
      expect(c.state.value.status, SectionStatus.error);
    });

    test('a slow answer for a month the teacher already left is ignored', () async {
      final slow = Completer<List<CalendarEntry>>();
      var n = 0;
      repo.events = (f, t) => n++ == 0 ? slow.future : Future.value([entry('n', 'November', start: '2026-11-10T00:00:00.000Z')]);
      final c = make();
      final first = c.load();
      c.setFocused(DateTime(2026, 11, 1));
      await pumpEventQueue();
      slow.complete([entry('o', 'October', start: '2026-10-10T00:00:00.000Z')]);
      await first;
      expect(c.entriesInMonth(DateTime(2026, 11, 1)).map((e) => e.id), ['n']);
      expect(c.state.value.status, SectionStatus.data);
    });

    test('end to end with the real repository: a fee row in the payload never becomes an entry', () async {
      final client = RecordingClient([calRow('a', 'Holiday', type: 'holiday'), feeRow('2026-10-12')]);
      final c = CalendarController(repository: SchoolCalendarRepository(client), clock: () => now);
      await c.load();
      expect(c.all.map((e) => e.id), ['a']);
      expect(c.entriesOn(DateTime(2026, 10, 12)).map((e) => e.id), ['a'], reason: 'the fee row of that day is not there');
    });

    test('wrong shape is an error state with a message, not an empty calendar', () async {
      final c = CalendarController(repository: SchoolCalendarRepository(RecordingClient({'events': []})), clock: () => now);
      await c.load();
      expect(c.state.value.status, SectionStatus.error);
      expect(c.state.value.message, contains('Something went wrong'));
    });
  });

  group('CircularsController', () {
    late FakeSchoolCalendarRepository repo;
    setUp(() => repo = FakeSchoolCalendarRepository());

    Future<CircularsController> make({CircularLocalState? local}) async {
      final h = await signedIn();
      final c = CircularsController(repository: repo, auth: h.auth, local: local ?? memoryLocal());
      return c;
    }

    test('keeps only published circulars for staff / me, newest first', () async {
      repo.circulars = () async => [
            circ('1', 'Older', published: '2026-10-01T06:00:00.000Z'),
            circ('2', 'Parents only', roles: ['parent']),
            circ('3', 'Draft', status: 'draft'),
            circ('4', 'Newest', published: '2026-10-08T06:00:00.000Z'),
            circ('5', 'For someone else', scope: 'individual', staffIds: ['zzz']),
            circ('6', 'For me', scope: 'individual', staffIds: [myStaff], published: '2026-10-05T06:00:00.000Z'),
          ];
      final c = await make();
      await c.load();
      expect(c.rows.map((x) => x.id), ['4', '6', '1']);
    });

    test('states: empty after filtering, 403, 404, 500 and keep-on-background-failure', () async {
      final c = await make();
      repo.circulars = () async => [circ('2', 'Parents only', roles: ['parent'])];
      await c.load();
      expect(c.state.value.status, SectionStatus.empty);
      for (final e in {403: SectionStatus.forbidden, 404: SectionStatus.unavailable, 500: SectionStatus.error}.entries) {
        repo.circulars = () async => fail7c(e.key);
        await c.load(userInitiated: true);
        expect(c.state.value.status, e.value);
      }
      repo.circulars = () async => [circ('1', 'A')];
      await c.load(userInitiated: true);
      repo.circulars = () async => fail7c(500);
      await c.load();
      expect(c.state.value.hasData, isTrue);
    });

    test('acknowledge gating: only circulars that ask for it; never twice; one request per tap', () async {
      final a = circ('1', 'Needs ack', ack: true), b = circ('2', 'No ack');
      repo.circulars = () async => [a, b];
      final c = await make();
      await c.load();
      expect(c.needsAck(a), isTrue);
      expect(c.needsAck(b), isFalse);
      expect(c.pendingAcks, 1);
      expect(await c.acknowledge(b), isFalse);
      expect(repo.calls.where((x) => x.startsWith('ack')), isEmpty);
      final gate = Completer<CircularAck>();
      repo.ack0 = (id) => gate.future;
      final f1 = c.acknowledge(a);
      expect(await c.acknowledge(a), isFalse, reason: 'a second tap while in flight');
      gate.complete(CircularAck(DateTime.utc(2026, 10, 9)));
      expect(await f1, isTrue);
      expect(await c.acknowledge(a), isFalse, reason: 'already acknowledged');
      expect(repo.calls.where((x) => x.startsWith('ack')), ['ack:1']);
      expect(c.pendingAcks, 0);
    });

    test('acknowledge failure keeps the button state and shows the reason; 403 / 404 / offline are different texts', () async {
      final a = circ('1', 'Needs ack', ack: true);
      repo.circulars = () async => [a];
      final c = await make();
      await c.load();
      for (final s in [403, 404, 500, null]) {
        repo.ack0 = (id) async => fail7c(s, 'Circular not found');
        expect(await c.acknowledge(a), isFalse);
        expect(c.acked.contains('1'), isFalse);
        expect(c.ackFailure['1'], isNotNull, reason: '$s');
        expect(c.acking, isEmpty);
      }
      expect(c.ackFailure['1']!.kind, ActionFailureKind.offline);
      repo.ack0 = (id) async => fail7c(403, 'Forbidden resource');
      await c.acknowledge(a);
      expect(c.ackFailure['1']!.isForbidden, isTrue);
      repo.ack0 = (id) async => CircularAck(null);
      expect(await c.acknowledge(a), isTrue);
      expect(c.ackFailure['1'], isNull);
    });

    test('acknowledged / opened ids survive a restart of the screen (ids only)', () async {
      final a = circ('1', 'Needs ack', ack: true);
      repo.circulars = () async => [a];
      final local = memoryLocal();
      final c1 = await make(local: local);
      await c1.load();
      expect(c1.isNew(a), isTrue);
      await c1.markOpened(a);
      await c1.acknowledge(a);
      final c2 = await make(local: local);
      await c2.load();
      expect(c2.isNew(a), isFalse);
      expect(c2.needsAck(a), isFalse);
    });

    test('the acknowledgment-status route (which lists other users) is never called', () async {
      repo.circulars = () async => [circ('1', 'A', ack: true)];
      final c = await make();
      await c.load();
      await c.acknowledge(c.rows.first);
      expect(repo.calls, ['circulars', 'ack:1']);
    });
  });

  group('EventsController', () {
    late FakeEventsRepository repo;
    setUp(() => repo = FakeEventsRepository());

    test('upcoming soonest first, past most recent first, no-date events sit in upcoming', () async {
      repo.list = () async => [
            ev('past1', 'Old', sessions: [session('a', '2026-09-01T09:00:00.000Z', '2026-09-01T10:00:00.000Z')]),
            ev('up2', 'Later', sessions: [session('a', '2026-11-01T09:00:00.000Z', '2026-11-01T10:00:00.000Z')]),
            ev('up1', 'Sooner', sessions: [session('a', '2026-10-20T09:00:00.000Z', '2026-10-20T10:00:00.000Z')]),
            ev('past2', 'Older', sessions: [session('a', '2026-08-01T09:00:00.000Z', '2026-08-01T10:00:00.000Z')]),
            ev('nodate', 'TBC', sessions: []),
          ];
      final c = EventsController(repository: repo, clock: () => now);
      await c.load();
      expect(c.upcoming.map((e) => e.id), ['up1', 'up2', 'nodate']);
      expect(c.past.map((e) => e.id), ['past1', 'past2']);
    });

    test('empty / 403 / 404 / 500 / wrong shape', () async {
      final c = EventsController(repository: repo, clock: () => now);
      await c.load();
      expect(c.state.value.status, SectionStatus.empty);
      for (final e in {403: SectionStatus.forbidden, 404: SectionStatus.unavailable, 500: SectionStatus.error}.entries) {
        repo.list = () async => fail7c(e.key);
        await c.load(userInitiated: true);
        expect(c.state.value.status, e.value);
      }
      final bad = EventsController(repository: EventsRepository(RecordingClient({'events': []})), clock: () => now);
      await bad.load();
      expect(bad.state.value.status, SectionStatus.error);
    });

    test('detail: starts from the list row, refreshes, a vanished event (404) replaces it, a draft by id is refused', () async {
      repo.one = (id) async => ev(id, 'Fresh title');
      final c = EventDetailController(repository: repo, eventId: 'e1', initial: ev('e1', 'Old title'));
      expect(c.state.value.data!.title, 'Old title');
      await c.load();
      expect(c.state.value.data!.title, 'Fresh title');
      repo.one = (id) async => fail7c(500);
      await c.load();
      expect(c.state.value.data!.title, 'Fresh title', reason: 'background failure keeps what is shown');
      repo.one = (id) async => fail7c(404, 'Event not found');
      await c.load(userInitiated: true);
      expect(c.state.value.status, SectionStatus.unavailable);
      repo.one = (id) async => ev(id, 'Draft one', status: 'draft');
      await c.load(userInitiated: true);
      expect(c.state.value.status, SectionStatus.error);
      repo.one = (id) async => ev(id, 'Private', visibility: 'private');
      await c.load(userInitiated: true);
      expect(c.state.value.status, SectionStatus.error);
    });
  });

  group('SafeguardingController', () {
    late FakeSafeguardingRepository repo;
    late FakeStudentsRepository students;
    setUp(() {
      repo = FakeSafeguardingRepository();
      students = FakeStudentsRepository();
    });

    Future<SafeguardingController> make({bool withClasses = true}) async {
      final h = await signedIn();
      if (withClasses) {
        h.api.assignments = [cls5a];
        await h.auth.refreshProfile(force: true);
      }
      return SafeguardingController(repository: repo, students: students, auth: h.auth, clock: () => now);
    }

    void fill(SafeguardingController c) {
      c.titleC.text = 'Worrying bruise';
      c.descriptionC.text = 'Saw a bruise on her arm';
      c.setType(ConcernType.physical);
    }

    test('required fields: type, summary and description; each error clears when fixed; nothing is sent while invalid', () async {
      final c = await make();
      final r = await c.submit();
      expect(r, isA<ConcernInvalid>());
      expect((r as ConcernInvalid).errors.keys.toSet(), {'type', 'title', 'description'});
      expect(repo.bodies, isEmpty);
      c.setType(ConcernType.other);
      expect(c.errors.containsKey('type'), isFalse);
      c.titleC.text = '   ';
      c.descriptionC.text = '\n';
      expect((await c.submit() as ConcernInvalid).errors.keys.toSet(), {'title', 'description'}, reason: 'whitespace only is empty');
    });

    test('the request carries EXACTLY the allow-listed keys (with a student)', () async {
      final c = await make();
      fill(c);
      c.actionsC.text = 'Spoke to her';
      c.setSeverity(ConcernSeverity.high);
      c.selectStudent(stu('64d000000000000000000501', 'Zara Malik'));
      final r = await c.submit();
      expect(r, isA<ConcernSent>());
      expect(repo.bodies.single.keys.toSet(), kSafeguardingRequestKeys);
      expect(repo.bodies.single['severity'], 'high');
      expect(repo.bodies.single['reportedDate'], '2026-10-09');
    });

    test('not about a specific student: no student keys at all', () async {
      final c = await make();
      fill(c);
      await c.submit();
      expect(repo.bodies.single.keys.toSet(), {'title', 'description', 'type', 'severity', 'reportedDate'});
    });

    test('a student outside my classes is refused client-side', () async {
      final c = await make();
      fill(c);
      c.selectStudent(stu('64d000000000000000000999', 'Other Child', grade: 'Grade 9', section: 'Z'));
      final r = await c.submit();
      expect((r as ConcernInvalid).errors['student'], contains('not in one of your classes'));
      expect(repo.bodies, isEmpty);
    });

    test('the picker only reads rosters of MY classes', () async {
      final c = await make();
      students.roster = (cls) async => [stu('1', 'Zara Malik')];
      await c.loadPickerClass();
      expect(students.calls.where((x) => x.startsWith('roster')), ['roster:Grade 5 - A']);
      expect(c.pickerVisible.single.fullName, 'Zara Malik');
      c.pickerQuery.value = 'zzz';
      expect(c.pickerVisible, isEmpty);
    });

    test('double submit: a second tap while sending is ignored, exactly one request', () async {
      final c = await make();
      fill(c);
      final gate = Completer<SafeguardingReceipt>();
      repo.submit0 = (_) => gate.future;
      final first = c.submit();
      expect(c.sending.value, isTrue);
      expect(await c.submit(), isA<ConcernIgnored>());
      gate.complete(const SafeguardingReceipt(null));
      expect(await first, isA<ConcernSent>());
      expect(repo.bodies.length, 1);
      expect(await c.submit(), isA<ConcernIgnored>(), reason: 'after success there is nothing left to send');
      expect(repo.bodies.length, 1);
    });

    test('success wipes everything typed at once and keeps only the optional reference', () async {
      final c = await make();
      fill(c);
      c.actionsC.text = 'x';
      c.selectStudent(stu('1', 'Zara Malik'));
      await c.submit();
      expect(c.sent.value, isTrue);
      expect(c.reference.value, 'SC-2026-123');
      expect((c.titleC.text, c.descriptionC.text, c.actionsC.text, c.type.value, c.student.value), ('', '', '', null, null));
      expect(c.isDirty, isFalse);
    });

    test('no reference from the server: no reference shown', () async {
      final c = await make();
      fill(c);
      repo.submit0 = (_) async => const SafeguardingReceipt(null);
      await c.submit();
      expect(c.sent.value, isTrue);
      expect(c.reference.value, isNull);
    });

    test('failure keeps the whole form; 403 is flagged; 400 shows the server text; offline may retry', () async {
      final c = await make();
      fill(c);
      c.selectStudent(stu('1', 'Zara Malik'));
      for (final s in [403, 400, 500, null]) {
        repo.submit0 = (_) async => fail7c(s, s == 400 ? 'description should not be empty' : 'nope');
        final r = await c.submit();
        expect(r, isA<ConcernFailed>(), reason: '$s');
        expect((c.titleC.text, c.descriptionC.text, c.type.value, c.student.value?.id), ('Worrying bruise', 'Saw a bruise on her arm', ConcernType.physical, '1'));
        expect(c.sent.value, isFalse);
        expect(c.sending.value, isFalse);
      }
      expect(c.failure.value!.kind, ActionFailureKind.offline);
      repo.submit0 = (_) async => fail7c(403, 'Forbidden resource');
      await c.submit();
      expect(c.failure.value!.isForbidden, isTrue);
      repo.submit0 = (_) async => fail7c(400, 'description should not be empty');
      await c.submit();
      expect(c.failure.value!.message, 'description should not be empty');
      repo.submit0 = (_) async => const SafeguardingReceipt('SC-1');
      expect(await c.submit(), isA<ConcernSent>(), reason: 'the same form can be sent after a failure');
    });

    test('dirty tracking drives the Discard dialog: any typed text, kind, student, severity or day', () async {
      final c = await make();
      expect(c.isDirty, isFalse);
      c.titleC.text = ' ';
      expect(c.isDirty, isTrue);
      c.wipe();
      expect(c.isDirty, isFalse);
      c.setType(ConcernType.other);
      expect(c.isDirty, isTrue);
      c.wipe();
      c.setSeverity(ConcernSeverity.low);
      expect(c.isDirty, isTrue);
      c.wipe();
      c.setDay(DateTime(2026, 10, 1));
      expect(c.isDirty, isTrue);
    });

    test('the date cannot be in the future', () async {
      final c = await make();
      c.setDay(DateTime(2026, 12, 1));
      expect(c.day.value, DateTime(2026, 10, 9));
    });

    test('PRIVACY: nothing is persisted to SharedPreferences, and closing the controller wipes the draft', () async {
      final c = Get.put(await make());
      fill(c);
      c.actionsC.text = 'secret detail';
      c.selectStudent(stu('1', 'Zara Malik'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty, reason: 'typing stores nothing');
      expect(c.isDirty, isTrue);
      final title = c.titleC;
      c.wipe();
      expect(c.titleC.text, '');
      c.titleC.text = 'again';
      Get.delete<SafeguardingController>(force: true);
      expect(c.type.value, isNull);
      expect(c.student.value, isNull);
      expect(title.hasListeners, isFalse, reason: 'text controllers are disposed with the screen');
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    });

    test('no classes: the picker is empty but a report not about a student can still be sent', () async {
      final c = await make(withClasses: false);
      expect(c.classes, isEmpty);
      fill(c);
      expect(await c.submit(), isA<ConcernSent>());
    });
  });

  group('ProfileController (avatar)', () {
    late FakeProfileRepository repo;
    late FakeAvatarPicker picker;
    setUp(() {
      repo = FakeProfileRepository();
      picker = FakeAvatarPicker();
    });
    Future<(ProfileController, AuthController)> make() async {
      final h = await signedIn();
      return (ProfileController(repository: repo, picker: picker, auth: h.auth), h.auth);
    }

    test('success: the cached user and staff identity get the new URL (app bar avatar updates)', () async {
      final (c, auth) = await make();
      expect(auth.user.value!.avatarUrl, isNull);
      await c.choosePhoto(AvatarSource.gallery);
      expect(repo.uploads.single.mime, 'image/jpeg');
      expect(c.outcome.value, AvatarOutcome.uploaded);
      expect(auth.user.value!.avatarUrl, 'https://files.test/avatars/new.png');
      expect(auth.staffMe.value!.user.avatarUrl, 'https://files.test/avatars/new.png');
      expect(c.localPreviewPath.value, '/tmp/me.jpg');
      expect(c.avatarBusy.value, isFalse);
    });

    test('camera and gallery are both routed to the picker with the right source', () async {
      final (c, _) = await make();
      await c.choosePhoto(AvatarSource.camera);
      await c.choosePhoto(AvatarSource.gallery);
      expect(picker.sources, [AvatarSource.camera, AvatarSource.gallery]);
    });

    test('cancel: nothing happens', () async {
      final (c, auth) = await make();
      picker.result = (_) async => null;
      await c.choosePhoto(AvatarSource.gallery);
      expect(c.outcome.value, AvatarOutcome.none);
      expect(repo.uploads, isEmpty);
      expect(auth.user.value!.avatarUrl, isNull);
    });

    test('permission denied (camera / library): a calm explanation, no upload, Settings offered via deniedSource', () async {
      final (c, _) = await make();
      picker.result = (s) async => throw AvatarPickDenied(s);
      await c.choosePhoto(AvatarSource.camera);
      expect((c.outcome.value, c.deniedSource.value), (AvatarOutcome.denied, AvatarSource.camera));
      expect(c.outcomeMessage.value, contains('camera'));
      expect(repo.uploads, isEmpty);
      await c.choosePhoto(AvatarSource.gallery);
      expect(c.deniedSource.value, AvatarSource.gallery);
      expect(c.outcomeMessage.value, contains('photos'));
      picker.result = (s) async => throw StateError('picker exploded');
      await c.choosePhoto(AvatarSource.gallery);
      expect(c.outcome.value, AvatarOutcome.failed);
    });

    test('size and type guards: nothing is uploaded', () async {
      final (c, _) = await make();
      picker.result = (_) async => const PickedAvatar(path: '/tmp/big.jpg', name: 'big.jpg', size: kAvatarMaxBytes + 1);
      await c.choosePhoto(AvatarSource.gallery);
      expect(c.outcome.value, AvatarOutcome.rejected);
      expect(c.outcomeMessage.value, contains('10 MB'));
      picker.result = (_) async => const PickedAvatar(path: '/tmp/a.gif', name: 'a.gif', size: 100);
      await c.choosePhoto(AvatarSource.gallery);
      expect(c.outcomeMessage.value, contains('JPG, PNG or WebP'));
      expect(repo.uploads, isEmpty);
    });

    test('503 (storage not configured): Upload unavailable, and NO further requests until the teacher refreshes', () async {
      final (c, auth) = await make();
      repo.upload = (p, n, m) async => fail7c(503, 'File uploads are not available on this server (storage is not configured).');
      await c.choosePhoto(AvatarSource.gallery);
      expect(c.outcome.value, AvatarOutcome.unavailable);
      expect(c.uploadUnavailable.value, isTrue);
      expect(auth.user.value!.avatarUrl, isNull);
      for (var i = 0; i < 5; i++) {
        await c.choosePhoto(AvatarSource.gallery);
      }
      expect(repo.uploads.length, 1, reason: 'no retry hammering');
      expect(picker.sources.length, 1);
      await c.load(userInitiated: true);
      expect(c.uploadUnavailable.value, isFalse);
    });

    test('403 / 400 / 500 / offline map to their own outcomes; the app bar stays unchanged', () async {
      final (c, auth) = await make();
      for (final e in {403: AvatarOutcome.forbidden, 400: AvatarOutcome.rejected, 413: AvatarOutcome.rejected, 500: AvatarOutcome.failed}.entries) {
        repo.upload = (p, n, m) async => fail7c(e.key, 'server said no');
        await c.choosePhoto(AvatarSource.gallery);
        expect(c.outcome.value, e.value, reason: '${e.key}');
      }
      repo.upload = (p, n, m) async => fail7c(null, 'No connection');
      await c.choosePhoto(AvatarSource.gallery);
      expect(c.outcome.value, AvatarOutcome.failed);
      expect(auth.user.value!.avatarUrl, isNull);
    });

    test('one upload at a time', () async {
      final (c, _) = await make();
      final gate = Completer<String>();
      repo.upload = (p, n, m) => gate.future;
      final f = c.choosePhoto(AvatarSource.gallery);
      await pumpEventQueue();
      expect(c.avatarBusy.value, isTrue);
      await c.choosePhoto(AvatarSource.gallery);
      gate.complete('https://files.test/a.png');
      await f;
      expect(repo.uploads.length, 1);
    });

    test('account load: data, 403, 404, error, keep-on-background-failure', () async {
      final (c, _) = await make();
      await c.load();
      expect(c.account.value.data!.email, 't@s.test');
      repo.account = () async => fail7c(500);
      await c.load();
      expect(c.account.value.hasData, isTrue);
      await c.load(userInitiated: true);
      expect(c.account.value.status, SectionStatus.error);
      repo.account = () async => fail7c(403);
      await c.load(userInitiated: true);
      expect(c.account.value.status, SectionStatus.forbidden);
      repo.account = () async => fail7c(404);
      await c.load(userInitiated: true);
      expect(c.account.value.status, SectionStatus.unavailable);
    });
  });

  group('Help controllers', () {
    late FakeKbRepository repo;
    setUp(() => repo = FakeKbRepository());
    const a1 = KbArticle(module: 'hr', tabKey: 'a', title: 'A', order: 2);
    const a2 = KbArticle(module: 'hr', tabKey: 'b', title: 'B', order: 1);
    const g1 = KbArticle(module: 'general', tabKey: 'g', title: 'G', order: 1);

    test('list grouped by module, articles by order; states', () async {
      repo.listRows = () async => [a1, a2, g1];
      final c = HelpController(repository: repo);
      await c.load();
      expect(c.grouped.keys.toList(), ['hr', 'general']);
      expect(c.grouped['hr']!.map((a) => a.tabKey), ['b', 'a']);
      repo.listRows = () async => [];
      await c.load(userInitiated: true);
      expect(c.list.value.status, SectionStatus.empty);
      for (final e in {403: SectionStatus.forbidden, 404: SectionStatus.unavailable, 500: SectionStatus.error}.entries) {
        repo.listRows = () async => fail7c(e.key);
        await c.load(userInitiated: true);
        expect(c.list.value.status, e.value);
      }
    });

    test('search: submitted text is trimmed; blank clears the results; results empty / error; stale answers ignored', () async {
      repo.listRows = () async => [a1];
      final c = HelpController(repository: repo);
      await c.load();
      repo.search0 = (q) async => [a1];
      await c.search('  leave  ');
      expect(repo.calls.last, 'search:leave');
      expect(c.results.value!.data!.single.key, 'hr/a');
      await c.search('   ');
      expect(c.results.value, isNull);
      expect(c.searching, isFalse);
      repo.search0 = (q) async => [];
      await c.search('zzz');
      expect(c.results.value!.status, SectionStatus.empty);
      repo.search0 = (q) async => fail7c(500);
      await c.search('zzz');
      expect(c.results.value!.status, SectionStatus.error);
      final slow = Completer<List<KbArticle>>();
      repo.search0 = (q) => q == 'slow' ? slow.future : Future.value([g1]);
      final f = c.search('slow');
      await c.search('fast');
      slow.complete([a1]);
      await f;
      expect(c.results.value!.data!.single.key, 'general/g');
    });

    test('article: shown at once, refreshed by key, 404 shown', () async {
      repo.one = (m, t) async => const KbArticle(module: 'hr', tabKey: 'a', title: 'Fresh');
      final c = HelpArticleController(repository: repo, module: 'hr', tabKey: 'a', initial: a1);
      expect(c.state.value.data!.title, 'A');
      await c.load();
      expect(c.state.value.data!.title, 'Fresh');
      expect(repo.calls, ['article:hr/a']);
      repo.one = (m, t) async => fail7c(404, 'No KB article found for hr/a');
      await c.load(userInitiated: true);
      expect(c.state.value.status, SectionStatus.unavailable);
    });
  });

  group('AboutController', () {
    test('version and build from the loader; a failing loader shows Unavailable, never throws; the host never includes the path or secrets', () async {
      final c = AboutController(loader: () async => const AppInfo('Eldermin Teacher', '1.2.3', '45'));
      await c.load();
      expect((c.info.value!.version, c.info.value!.build), ('1.2.3', '45'));
      final bad = AboutController(loader: () async => throw StateError('x'));
      await bad.load();
      expect((bad.info.value, bad.failed.value), (null, true));
      expect(AboutController.hostOf('https://api.eldermin.com/api/v1?token=abc'), 'api.eldermin.com');
      expect(AboutController.hostOf('http://localhost:3977'), 'localhost:3977');
      expect(AboutController.hostOf('https://user:pw@api.example.test:443/x'), 'api.example.test');
      expect(AboutController.hostOf('nonsense'), '');
    });
  });

  group('DeleteAccountController', () {
    late FakeAccountRepository repo;
    setUp(() => repo = FakeAccountRepository());

    test('type-to-confirm: DELETE (any case, trimmed) enables the button; anything else does not; nothing is sent until then', () async {
      final c = DeleteAccountController(repository: repo);
      expect(c.canSubmit, isFalse);
      for (final v in ['', 'delet', 'DELETE ME', 'yes']) {
        c.onConfirmChanged(v);
        expect(c.canSubmit, isFalse, reason: v);
        expect(await c.submit(), isFalse);
      }
      expect(repo.reasons, isEmpty);
      c.onConfirmChanged(' delete ');
      expect(c.canSubmit, isTrue);
    });

    test('sends the reason (or none), shows the status; NEVER signs the user out', () async {
      final h = await signedIn();
      final c = DeleteAccountController(repository: repo);
      c.reasonC.text = ' moving abroad ';
      c.onConfirmChanged('DELETE');
      expect(await c.submit(), isTrue);
      expect(repo.reasons, [' moving abroad ']);
      expect(c.result.value!.status, 'pending');
      expect(c.result.value!.alreadyRequested, isFalse);
      expect(c.canSubmit, isFalse, reason: 'sent: the button is gone');
      expect(h.auth.status.value, AuthStatus.authenticated);
      expect(h.auth.user.value, isNotNull);
    });

    test('already requested is shown as such', () async {
      repo.request0 = (_) async => const DeletionRequestResult(requestId: 'r1', status: 'pending', alreadyRequested: true);
      final c = DeleteAccountController(repository: repo);
      c.onConfirmChanged('DELETE');
      await c.submit();
      expect(c.result.value!.alreadyRequested, isTrue);
    });

    test('403 / 404 / 400 / offline keep the form and allow another try; double submit sends once', () async {
      final c = DeleteAccountController(repository: repo);
      c.reasonC.text = 'because';
      c.onConfirmChanged('DELETE');
      for (final s in [403, 404, 400, null]) {
        repo.request0 = (_) async => fail7c(s, 'text');
        expect(await c.submit(), isFalse);
        expect(c.result.value, isNull);
        expect(c.failure.value, isNotNull, reason: '$s');
        expect(c.reasonC.text, 'because');
        expect(c.canSubmit, isTrue);
      }
      expect(c.failure.value!.kind, ActionFailureKind.offline);
      final gate = Completer<DeletionRequestResult>();
      repo.request0 = (_) => gate.future;
      repo.reasons.clear();
      final first = c.submit();
      expect(await c.submit(), isFalse);
      gate.complete(const DeletionRequestResult(requestId: 'r', status: 'pending', alreadyRequested: false));
      expect(await first, isTrue);
      expect(repo.reasons.length, 1);
    });

    test('a reason longer than the DTO limit blocks the button', () async {
      final c = DeleteAccountController(repository: repo);
      c.reasonC.text = 'x' * (kDeleteReasonMax + 1);
      c.onConfirmChanged('DELETE');
      expect(c.canSubmit, isFalse);
    });
  });
}

