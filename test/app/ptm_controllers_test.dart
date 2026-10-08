// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';
import 'package:eldermin_teacher_app/app/common/action_failure.dart';
import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/models/section_state.dart';
import 'package:eldermin_teacher_app/app/modules/ptm/controllers/ptm_controller.dart';
import 'package:eldermin_teacher_app/app/modules/ptm/controllers/ptm_create_controller.dart';
import 'package:eldermin_teacher_app/app/modules/ptm/controllers/ptm_detail_controller.dart';
import 'package:eldermin_teacher_app/core/models/ptm/ptm_models.dart';
import 'package:eldermin_teacher_app/core/utils/ptm_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_classroom_repositories.dart';
import '../support/fake_phase7b_repositories.dart';

const cls5a = {'gradeLevel': 'Grade 5', 'sectionName': 'A', 'subjectName': 'Mathematics'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakePtmRepository repo;
  final now = DateTime(2026, 10, 8, 13, 0);

  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakePtmRepository();
  });
  tearDown(Get.reset);

  Future<dynamic> auth({bool signed = true}) async {
    final h = await signedIn();
    h.api.assignments = const [cls5a];
    await h.auth.refreshProfile(force: true);
    return h;
  }

  group('list (PtmController)', () {
    final ahead = [meeting('up', status: 'confirmed', day: '2026-10-10'), meeting('today', status: 'requested', day: '2026-10-08', start: '15:00', end: '15:30')];
    final past = [meeting('old', status: 'completed', day: '2026-10-01'), meeting('can', status: 'cancelled', day: '2026-10-03')];

    Future<PtmController> make() async {
      final h = await auth();
      repo.list = (s, from, to) async => from != null ? ahead : past;
      return PtmController(repository: repo, auth: h.auth, clock: () => now);
    }

    test('two reads: from-today and before-today, both with MY staff id; tabs cut locally; opens on Today when something is on today', () async {
      final c = await make();
      await c.reload();
      expect(repo.calls, ['list:from', 'list:to']);
      expect(c.load.value.status, SectionStatus.data);
      expect(c.tabs.upcoming.map((m) => m.id), ['up']);
      expect(c.tabs.todayRemaining.map((m) => m.id), ['today']);
      expect(c.tabs.past.map((m) => m.id), ['old']);
      expect(c.tabs.cancelled.map((m) => m.id), ['can']);
      expect(c.tab.value, PtmTab.today);
    });

    test('opens on Upcoming when nothing is on today; a tab the teacher chose is never overridden by a later load', () async {
      final c = await make();
      repo.list = (s, from, to) async => from != null ? [ahead.first] : past;
      await c.reload();
      expect(c.tab.value, PtmTab.upcoming);
      c.selectTab(PtmTab.past);
      await c.reload();
      expect(c.tab.value, PtmTab.past);
    });

    test('nothing at all -> empty state; a full window flags that more may exist', () async {
      final c = await make();
      repo.list = (s, from, to) async => from != null ? List.generate(PtmController.serverLimit, (i) => meeting('a$i', day: '2026-10-1${i % 9}')) : [];
      await c.reload();
      expect(c.aheadCut.value, isTrue);
      expect(c.pastCut.value, isFalse);
      repo.list = (s, from, to) async => [];
      await c.reload();
      expect(c.load.value.status, SectionStatus.empty);
    });

    test('errors: 403 forbidden, 404 not deployed, 500 error; a failed refresh keeps the old data unless the teacher pulled', () async {
      final c = await make();
      await c.reload();
      repo.list = (s, from, to) async => fail7b(500);
      await c.reload();
      expect(c.load.value.status, SectionStatus.data, reason: 'silent refresh keeps what is on screen');
      await c.reload(userInitiated: true);
      expect(c.load.value.status, SectionStatus.error);
      repo.list = (s, from, to) async => fail7b(403);
      await c.reload(userInitiated: true);
      expect(c.load.value.status, SectionStatus.forbidden);
      repo.list = (s, from, to) async => fail7b(404);
      await c.reload(userInitiated: true);
      expect(c.load.value.status, SectionStatus.unavailable);
    });

    test('one failing window fails the screen (no half list that looks complete)', () async {
      final c = await make();
      repo.list = (s, from, to) async => from != null ? ahead : fail7b(500);
      await c.reload(userInitiated: true);
      expect(c.load.value.status, SectionStatus.error);
    });

    test('no staff id from /me -> an error, no request', () async {
      Get.reset();
      Get.testMode = true;
      final h = await signedIn();
      h.auth.staffMe.value = null;
      final c = PtmController(repository: repo, auth: h.auth, clock: () => now);
      await c.reload();
      expect(c.load.value.status, SectionStatus.error);
      expect(repo.calls, isEmpty);
    });

    test('a stale answer never overwrites a newer one (tokens)', () async {
      final c = await make();
      final slow = Completer<List<ParentMeeting>>();
      var n = 0;
      repo.list = (s, from, to) => (n++ < 2) ? slow.future : Future.value(from != null ? ahead : past);
      final first = c.reload();
      final second = c.reload(userInitiated: true);
      await second;
      slow.complete([meeting('stale')]);
      await first;
      expect(c.tabs.upcoming.map((m) => m.id), ['up']);
    });

    test('upsert replaces in place and re-cuts the tabs (confirm moves nothing, cancel moves to Cancelled)', () async {
      final c = await make();
      await c.reload();
      c.upsert(meeting('up', status: 'cancelled', day: '2026-10-10'));
      expect(c.tabs.upcoming, isEmpty);
      expect(c.tabs.cancelled.map((m) => m.id), containsAll(['up', 'can']));
      c.upsert(meeting('brand-new', status: 'requested', day: '2026-10-20'));
      expect(c.tabs.upcoming.map((m) => m.id), ['brand-new']);
    });
  });

  group('detail (PtmDetailController): actions only when allowed, one at a time, server truth after a rejection', () {
    Future<PtmDetailController> make(ParentMeeting m, {bool boot = true}) async {
      final h = await auth();
      repo.one = (id) async => m;
      final c = PtmDetailController(id: m.id, repository: repo, auth: h.auth, clock: () => now);
      if (boot) await c.reload();
      return c;
    }

    test('loads by id; allowed actions follow status AND ownership', () async {
      final c = await make(meeting('a', status: 'requested'));
      expect(c.state.value.status, SectionStatus.data);
      expect(c.isMine, isTrue);
      expect(c.allowed, contains(PtmAction.confirm));
      final other = await make(meeting('b', status: 'requested', teacherId: otherStaff));
      expect(other.isMine, isFalse);
      expect(other.allowed, isEmpty);
      expect(await other.confirm(), isA<PtmIgnored>());
      expect(await other.cancel('x'), isA<PtmIgnored>());
      expect(await other.setActionItem('i', done: true), isA<PtmIgnored>());
      expect(repo.calls.where((x) => x.startsWith('confirm') || x.startsWith('cancel') || x.startsWith('item')), isEmpty);
    });

    test('404 "Meeting not found" -> notFound (not an error); a not-deployed 404 is an unavailable section', () async {
      final h = await auth();
      repo.one = (id) async => fail7b(404, 'Meeting not found');
      var c = PtmDetailController(id: 'x', repository: repo, auth: h.auth);
      await c.reload();
      expect((c.notFound.value, c.state.value.status), (true, SectionStatus.empty));
      repo.one = (id) async => fail7b(404, 'Cannot GET /api/v1/teaching/ptm/x');
      c = PtmDetailController(id: 'x', repository: repo, auth: h.auth);
      await c.reload();
      expect((c.notFound.value, c.state.value.status), (false, SectionStatus.unavailable));
      repo.one = (id) async => fail7b(403);
      c = PtmDetailController(id: 'x', repository: repo, auth: h.auth);
      await c.reload();
      expect(c.state.value.status, SectionStatus.forbidden);
    });

    test('confirm: success replaces the meeting and says so; the list controller (if open) is updated', () async {
      final c = await make(meeting('a', status: 'requested'));
      final list = Get.put(PtmController(repository: repo, auth: Get.find<AuthController>(), clock: () => now));
      repo.list = (s, f, t) async => [];
      final r = await c.confirm();
      expect(r, isA<PtmDone>());
      expect(c.meeting!.status, PtmStatus.confirmed);
      expect(list.find('a')?.status, PtmStatus.confirmed);
      expect(c.allowed, isNot(contains(PtmAction.confirm)), reason: 'no confirm button for a confirmed meeting');
    });

    test('confirm rejected (404 not in a requested state): the meeting is re-read, the SERVER text is shown', () async {
      final c = await make(meeting('a', status: 'requested'));
      repo.confirm0 = (id) async => fail7b(404, 'Meeting not found or not in a requested state');
      repo.one = (id) async => meeting(id, status: 'confirmed');
      final r = await c.confirm();
      expect(r, isA<PtmFailed>());
      expect((r as PtmFailed).text, 'Meeting not found or not in a requested state');
      expect(c.meeting!.status, PtmStatus.confirmed, reason: 'reloaded: the server had it confirmed already');
      expect(c.busy.value, isNull);
    });

    test('one action at a time: a second tap while one is in flight is ignored (no double request)', () async {
      final c = await make(meeting('a', status: 'requested'));
      final gate = Completer<ParentMeeting>();
      repo.confirm0 = (id) => gate.future;
      final first = c.confirm();
      expect(c.busy.value, PtmAction.confirm);
      expect(await c.confirm(), isA<PtmIgnored>());
      expect(await c.cancel('reason'), isA<PtmIgnored>());
      gate.complete(meeting('a', status: 'confirmed'));
      expect(await first, isA<PtmDone>());
      expect(repo.calls.where((x) => x.startsWith('confirm')), hasLength(1));
    });

    test('reschedule: validated first (nothing sent), sends the day and both times, tells that confirmation is needed again', () async {
      final c = await make(meeting('a', status: 'confirmed'));
      var r = await c.reschedule(day: null, start: '10:00', end: '10:30');
      expect(r, isA<PtmInvalid>());
      expect((r as PtmInvalid).errors['day'], 'Choose a date');
      r = await c.reschedule(day: DateTime(2026, 10, 7), start: '10:00', end: '10:30') as PtmInvalid;
      expect(r.errors['day'], 'Choose today or a later date');
      r = await c.reschedule(day: DateTime(2026, 10, 9), start: '11:00', end: '10:30') as PtmInvalid;
      expect(r.errors['end'], isNotNull);
      expect(repo.calls.where((x) => x.startsWith('reschedule')), isEmpty);
      repo.reschedule0 = (id, d, s, e) async => meeting(id, status: 'requested', day: '2026-10-09', start: s!, end: e!);
      final ok = await c.reschedule(day: DateTime(2026, 10, 9), start: '11:00', end: '11:30');
      expect(ok, isA<PtmDone>());
      expect((ok as PtmDone).notice, contains('confirmed again'));
      expect(repo.lastReschedule!.day, DateTime(2026, 10, 9));
      expect((repo.lastReschedule!.start, repo.lastReschedule!.end), ('11:00', '11:30'));
      expect(c.meeting!.status, PtmStatus.requested, reason: 'the server resets the status');
    });

    test('reschedule 403 (not mine according to the server) / 404 closed: shown, meeting re-read, nothing lost', () async {
      final c = await make(meeting('a', status: 'confirmed'));
      repo.reschedule0 = (id, d, s, e) async => fail7b(403, 'You can only modify your own meetings');
      var r = await c.reschedule(day: DateTime(2026, 10, 9), start: '11:00', end: '11:30') as PtmFailed;
      expect(r.text, 'You can only modify your own meetings');
      expect(r.failure.isForbidden, isTrue);
      repo.reschedule0 = (id, d, s, e) async => fail7b(404, 'Meeting not found or already completed/cancelled');
      repo.one = (id) async => meeting(id, status: 'completed');
      r = await c.reschedule(day: DateTime(2026, 10, 9), start: '11:00', end: '11:30') as PtmFailed;
      expect(r.text, 'Meeting not found or already completed/cancelled');
      expect(c.meeting!.status, PtmStatus.completed);
      expect(c.allowed.contains(PtmAction.reschedule), isFalse);
    });

    test('outcome: attended -> completed, no-show -> no_show; invalid items stop before any request; items go as typed', () async {
      final c = await make(meeting('a', status: 'confirmed'));
      final bad = await c.recordOutcome(const PtmOutcomeRequest(parentAttended: true, actionItems: [ActionItemDraft(assignedTo: 'Parent')]));
      expect(bad, isA<PtmInvalid>());
      expect(repo.calls.where((x) => x.startsWith('outcome')), isEmpty);
      repo.outcome0 = (id, r) async => meeting(id, status: 'completed', attended: true, notes: r.meetingNotes, items: [item('i1', text: r.actionItems.first.description)]);
      final ok = await c.recordOutcome(PtmOutcomeRequest(parentAttended: true, meetingNotes: 'Good', actionItems: [ActionItemDraft(description: 'Read', dueDay: DateTime(2026, 10, 20))])) as PtmDone;
      expect(ok.notice, contains('attended'));
      expect(repo.lastOutcome!.actionItems.single.description, 'Read');
      expect(c.meeting!.status, PtmStatus.completed);
      expect(c.allowed, {PtmAction.toggleActionItems, PtmAction.messageGuardian}, reason: 'the outcome is final');
      expect(await c.recordOutcome(const PtmOutcomeRequest(parentAttended: false)), isA<PtmIgnored>());
    });

    test('no-show wording; 400 cancelled -> server text, meeting reloaded as cancelled', () async {
      final c = await make(meeting('a', status: 'confirmed'));
      repo.outcome0 = (id, r) async => fail7b(400, 'Cannot record an outcome for a cancelled meeting');
      repo.one = (id) async => meeting(id, status: 'cancelled', cancelledReason: 'x');
      final r = await c.recordOutcome(const PtmOutcomeRequest(parentAttended: false)) as PtmFailed;
      expect(r.text, 'Cannot record an outcome for a cancelled meeting');
      expect(c.meeting!.status, PtmStatus.cancelled);
      expect(c.allowed, isEmpty);
    });

    test('cancel: a reason is required (trimmed, <= 500); on success the meeting is cancelled and no action is left', () async {
      final c = await make(meeting('a', status: 'requested'));
      expect(((await c.cancel('   ')) as PtmInvalid).errors['reason'], isNotNull);
      expect(((await c.cancel('x' * 501)) as PtmInvalid).errors['reason'], isNotNull);
      expect(repo.calls.where((x) => x.startsWith('cancel')), isEmpty);
      final r = await c.cancel('  Parent is travelling ') as PtmDone;
      expect(r.notice, contains('cancelled'));
      expect(c.meeting!.status, PtmStatus.cancelled);
      expect(c.meeting!.cancelledReason, 'Parent is travelling');
      expect(c.allowed, isEmpty);
    });

    test('failures: offline keeps the sheet usable (retry possible), server 500 is generic', () async {
      final c = await make(meeting('a', status: 'requested'));
      repo.cancel0 = (id, r) async => fail7b(null, 'No connection');
      var r = await c.cancel('Travelling') as PtmFailed;
      expect(r.failure.kind, ActionFailureKind.offline);
      expect(r.failure.canRetry, isTrue);
      expect(c.meeting!.status, PtmStatus.requested, reason: 'nothing changed locally');
      repo.cancel0 = (id, r) async => fail7b(500);
      r = await c.cancel('Travelling') as PtmFailed;
      expect(r.failure.kind, ActionFailureKind.server);
    });

    test('action items: optimistic toggle, rollback on failure, one request per item at a time', () async {
      final c = await make(meeting('a', status: 'completed', items: [item('i1'), item('i2', status: 'done')]));
      final gate = Completer<ParentMeeting>();
      repo.item0 = (id, i, d) => gate.future;
      final f = c.setActionItem('i1', done: true);
      expect(c.meeting!.actionItems.first.done, isTrue, reason: 'optimistic');
      expect(c.itemBusy, contains('i1'));
      expect(await c.setActionItem('i1', done: false), isA<PtmIgnored>(), reason: 'same item in flight');
      gate.complete(meeting('a', status: 'completed', items: [item('i1', status: 'done'), item('i2', status: 'done')]));
      expect(await f, isA<PtmDone>());
      expect(c.itemBusy, isEmpty);
      repo.item0 = (id, i, d) async => fail7b(404, 'Action item not found');
      final r = await c.setActionItem('i2', done: false) as PtmFailed;
      expect(r.text, 'Action item not found');
      expect(c.meeting!.actionItems.last.done, isTrue, reason: 'rolled back');
      expect(await c.setActionItem('i1', done: true), isA<PtmIgnored>(), reason: 'no change');
      expect(await c.setActionItem('nope', done: true), isA<PtmIgnored>());
    });

    test('history loads once the meeting is known and excludes the meeting itself; failure is its own state', () async {
      final h = await auth();
      repo.one = (id) async => meeting(id, status: 'requested');
      repo.history = (sid) async => [meeting('a'), meeting('older', status: 'completed', day: '2026-09-01')];
      final c = PtmDetailController(id: 'a', repository: repo, auth: h.auth);
      await c.reload();
      await pumpEventQueue();
      expect(c.history.value.data!.map((m) => m.id), ['older']);
      repo.history = (sid) async => fail7b(500);
      await c.loadHistory(force: true);
      expect(c.history.value.status, SectionStatus.error);
      expect(c.meeting, isNotNull, reason: 'the history failing never hides the meeting');
    });

    test('Message guardian: a student to preselect only for my meetings that are not cancelled; no phone/email anywhere on it', () async {
      final c = await make(meeting('a', status: 'confirmed'));
      final s = c.messageStudent!;
      expect((s.id, s.fullName, s.grade, s.section), (oid(0x200), 'Zara Malik', 'Grade 5', 'A'));
      expect(s.toDebugMap().values.join(), isNot(contains('@')));
      expect((await make(meeting('b', status: 'cancelled'))).messageStudent, isNull);
      expect((await make(meeting('c', teacherId: otherStaff))).messageStudent, isNull);
    });
  });

  group('create (PtmCreateController)', () {
    final s1 = student(1), s2 = student(2, year: null), outsider = student(30, grade: 'Grade 9', section: 'Z');

    Future<PtmCreateController> make({bool noYear = false}) async {
      final h = await auth();
      final students = FakeStudentsRepository()..roster = (c) async => [s1, s2];
      final c = PtmCreateController(repository: repo, students: students, auth: h.auth, clock: () => now)..onInit();
      await pumpEventQueue();
      return c;
    }

    void fill(PtmCreateController c, {dynamic st}) {
      c.selectStudent(st ?? s1);
      c.setDay(DateTime(2026, 10, 9));
      c.setStart('10:00');
      c.setEnd('10:30');
    }

    test('empty form: every required field is reported, nothing is sent', () async {
      final c = await make();
      final r = await c.submit();
      expect(r, isA<PtmCreateInvalid>());
      expect((r as PtmCreateInvalid).errors.keys, containsAll(['student', 'day', 'start', 'end']));
      expect(repo.calls, isEmpty);
    });

    test('a valid form sends MY staff id from /me, the picked day as a date, the student\'s academic year, trimmed points', () async {
      final c = await make();
      fill(c);
      c.points.first.text = '  Maths progress ';
      c.addPoint();
      c.points.last.text = '';
      final r = await c.submit();
      expect(r, isA<PtmCreated>());
      final sent = repo.lastCreate!;
      expect((sent.teacherId, sent.studentId, sent.academicYear, sent.startTime, sent.endTime), (myStaff, s1.id, '2026-27', '10:00', '10:30'));
      expect(sent.toJson()['scheduledDate'], '2026-10-09');
      expect(sent.toJson()['discussionPoints'], ['Maths progress']);
    });

    test('academic year: the student\'s, else the roster\'s; with none the form cannot be saved (never invented)', () async {
      final c = await make();
      fill(c, st: s2); // no own year; the roster of the class has s1 with 2026-27
      expect(c.academicYear, '2026-27');
      Get.reset();
      Get.testMode = true;
      final h = await auth();
      final students = FakeStudentsRepository()..roster = (cl) async => [s2];
      final c2 = PtmCreateController(repository: repo, students: students, auth: h.auth, clock: () => now)..onInit();
      await pumpEventQueue();
      fill(c2, st: s2);
      expect(c2.academicYear, isNull);
      final r = await c2.submit() as PtmCreateInvalid;
      expect(r.errors['year'], contains('academic year'));
      expect(repo.calls, isEmpty);
    });

    test('a student outside my classes, a past day, end <= start are refused locally', () async {
      final c = await make();
      fill(c, st: outsider);
      expect(c.validate()['student'], 'This student is not in one of your classes');
      fill(c);
      c.setDay(DateTime(2026, 10, 7));
      expect(c.validate()['day'], 'Choose today or a later date');
      c.setDay(DateTime(2026, 10, 8));
      expect(c.validate().containsKey('day'), isFalse, reason: 'today is allowed');
      c.setEnd('09:00');
      expect(c.validate()['end'], isNotNull);
    });

    test('choosing a start suggests an end 30 minutes later only when none was chosen', () async {
      final c = await make();
      c.setStart('10:00');
      expect(c.end.value, '10:30');
      c.setEnd('11:15');
      c.setStart('10:10');
      expect(c.end.value, '11:15');
      c.setStart('23:50');
      expect(c.end.value, '11:15');
    });

    test('double submit: a second tap while saving, and after success, sends nothing more', () async {
      final c = await make();
      fill(c);
      final gate = Completer<ParentMeeting>();
      repo.create0 = (r) => gate.future;
      final first = c.submit();
      expect(c.saving.value, isTrue);
      expect(await c.submit(), isA<PtmCreateIgnored>());
      gate.complete(meeting('new1'));
      expect(await first, isA<PtmCreated>());
      expect(await c.submit(), isA<PtmCreateIgnored>());
      expect(repo.calls.where((x) => x == 'create'), hasLength(1));
    });

    test('403 "only for yourself" and 404 student are shown as the server said; the form keeps its values', () async {
      final c = await make();
      fill(c);
      repo.create0 = (r) async => fail7b(403, 'You can only create meetings for yourself');
      var r = await c.submit() as PtmCreateFailed;
      expect(r.text, 'You can only create meetings for yourself');
      expect(c.student.value, s1);
      expect(c.day.value, DateTime(2026, 10, 9));
      repo.create0 = (r) async => fail7b(404, 'Student not found');
      r = await c.submit() as PtmCreateFailed;
      expect(r.failure.kind, ActionFailureKind.notFound);
      repo.create0 = (r) async => fail7b(500);
      r = await c.submit() as PtmCreateFailed;
      expect(r.failure.kind, ActionFailureKind.server);
      repo.create0 = (r) async => meeting('ok1');
      expect(await c.submit(), isA<PtmCreated>(), reason: 'retry after a failure works');
    });

    test('dirty tracking and discussion-point limits', () async {
      final c = await make();
      expect(c.isDirty, isFalse);
      c.points.first.text = 'x' * (kPtmPointMax + 1);
      fill(c);
      expect(c.validate()['points'], isNotNull);
      expect(c.isDirty, isTrue);
      for (var i = 0; i < 20; i++) {
        c.addPoint();
      }
      expect(c.points.length, kPtmMaxPoints);
      c.removePoint(0);
      expect(c.points.length, kPtmMaxPoints - 1);
    });
  });
}
