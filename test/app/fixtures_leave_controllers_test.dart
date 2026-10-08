// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';
import 'package:eldermin_teacher_app/app/modules/fixtures/controllers/fixtures_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/models/section_state.dart';
import 'package:eldermin_teacher_app/app/modules/leave/controllers/leave_apply_controller.dart';
import 'package:eldermin_teacher_app/app/modules/leave/controllers/leave_controller.dart';
import 'package:eldermin_teacher_app/core/models/home/teaching.dart';
import 'package:eldermin_teacher_app/core/models/leave/leave_models.dart';
import 'package:eldermin_teacher_app/core/utils/fixture_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_phase7b_repositories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 10, 8, 13, 0);

  setUp(() {
    Get.reset();
    Get.testMode = true;
  });
  tearDown(Get.reset);

  group('fixtures (FixturesController)', () {
    late FakeFixturesRepository repo;
    final rows = [
      fixture('c1'),
      fixture('c2', status: 'open', original: otherStaff, substitute: null),
      fixture('o1', original: myStaff, substitute: otherStaff),
      fixture('o2', original: myStaff, substitute: null, status: 'open'),
    ];

    Future<FixturesController> make({List<dynamic>? data}) async {
      final h = await signedIn();
      repo = FakeFixturesRepository()..list = (s, f) async => (data ?? rows).cast();
      final c = FixturesController(repository: repo, auth: h.auth, clock: () => now);
      await c.reload();
      return c;
    }

    test('one request with MY staff id and a 14-day-back window; tabs by side; the Not-covered row is on the second tab', () async {
      final h = await signedIn();
      String? seenStaff;
      DateTime? seenFrom;
      repo = FakeFixturesRepository()
        ..list = (s, f) async {
          seenStaff = s;
          seenFrom = f;
          return rows;
        };
      final c = FixturesController(repository: repo, auth: h.auth, clock: () => now);
      await c.reload();
      expect((seenStaff, seenFrom), (myStaff, DateTime.utc(2026, 9, 24)));
      expect(repo.calls, ['list']);
      expect(c.rows(FixtureTab.covering).map((s) => s.id), ['c1']);
      expect(c.rows(FixtureTab.covered).map((s) => s.id), ['o1', 'o2']);
    });

    test('opens on the second tab only when the first is empty and the teacher has not chosen', () async {
      final c = await make(data: [fixture('o1', original: myStaff, substitute: otherStaff)]);
      expect(c.tab.value, FixtureTab.covered);
      final d = await make();
      expect(d.tab.value, FixtureTab.covering);
      d.selectTab(FixtureTab.covered);
      await d.reload();
      expect(d.tab.value, FixtureTab.covered);
    });

    test('empty / 403 / 404 / 500 states', () async {
      final c = await make();
      repo.list = (s, f) async => [];
      await c.reload();
      expect(c.load.value.status, SectionStatus.empty);
      for (final e in {403: SectionStatus.forbidden, 404: SectionStatus.unavailable, 500: SectionStatus.error}.entries) {
        repo.list = (s, f) async => fail7b(e.key);
        await c.reload(userInitiated: true);
        expect(c.load.value.status, e.value, reason: '${e.key}');
      }
    });

    test('Mark complete: only my assigned cover; success flips the status and keeps the row; the server answer never drops who/where', () async {
      final c = await make();
      expect(c.canComplete(c.find('c1')!), isTrue);
      for (final id in ['c2', 'o1', 'o2']) {
        expect(c.canComplete(c.find(id)!), isFalse, reason: id);
        expect(await c.complete(id), isA<CompleteIgnored>());
      }
      expect(await c.complete('unknown'), isA<CompleteIgnored>());
      expect(repo.calls.where((x) => x.startsWith('complete')), isEmpty);
      repo.complete0 = (id) async => Substitution.fromJson({'_id': id, 'status': 'completed'}); // UNVERIFIED how complete the PATCH body is: only id + status here
      final r = await c.complete('c1');
      expect(r, isA<CompleteDone>());
      final s = c.find('c1')!;
      expect((s.status, s.substituteTeacherId, s.classLabel), ('completed', myStaff, 'Grade 4 - B'));
      expect(c.canComplete(s), isFalse, reason: 'completed: the button is gone');
      expect(repo.calls.where((x) => x.startsWith('complete')), ['complete:c1']);
    });

    test('Mark complete: one at a time, and a second tap on the same row sends nothing', () async {
      final c = await make();
      final gate = Completer<Substitution>();
      repo.complete0 = (id) => gate.future;
      final f = c.complete('c1');
      expect(c.completing.value, 'c1');
      expect(await c.complete('c1'), isA<CompleteIgnored>());
      gate.complete(fixture('c1', status: 'completed'));
      expect(await f, isA<CompleteDone>());
      expect(c.completing.value, isNull);
    });

    test('Mark complete rejected (404 not in an assigned state): the server text is shown and the list is re-read', () async {
      final c = await make();
      repo.complete0 = (id) async => fail7b(404, 'Fixture not found or not in an assigned state');
      repo.list = (s, f) async => [fixture('c1', status: 'completed'), ...rows.skip(1)];
      final r = await c.complete('c1') as CompleteFailed;
      expect(r.text, 'Fixture not found or not in an assigned state');
      expect(c.find('c1')!.status, 'completed');
      repo.complete0 = (id) async => fail7b(null, 'No connection');
      repo.list = (s, f) async => rows;
      await c.reload(userInitiated: true);
      expect(((await c.complete('c1')) as CompleteFailed).text, contains('Reconnect'));
      expect(c.find('c1')!.status, 'assigned', reason: 'an offline failure changes nothing');
    });

    test('resolve(id) finds a row, loading the list first when needed (deep link); an unknown id is null', () async {
      final h = await signedIn();
      repo = FakeFixturesRepository()..list = (s, f) async => rows;
      final c = FixturesController(repository: repo, auth: h.auth, clock: () => now);
      expect((await c.resolve('o1'))?.id, 'o1');
      expect(repo.calls, ['list']);
      expect(await c.resolve('zzz'), isNull);
      expect(repo.calls, ['list'], reason: 'loaded once');
    });
  });

  group('My leave list (LeaveController)', () {
    late FakeLeaveRepository repo;
    setUp(() => repo = FakeLeaveRepository());

    test('balance and history load independently; one failing never hides the other', () async {
      final c = LeaveController(repository: repo);
      repo.history = () async => fail7b(500);
      repo.balance = () async => balanceOf();
      await c.reload();
      expect(c.balance.value.status, SectionStatus.data);
      expect(c.history.value.status, SectionStatus.error);
      expect(c.wholeScreenStatus, isNull);
      repo.history = () async => [leaveRow('l1')];
      await c.loadHistory(userInitiated: true);
      expect(c.history.value.data!.map((l) => l.id), ['l1']);
    });

    test('empty history -> empty state; 403 on both -> one whole-screen forbidden; 404 on both -> unavailable', () async {
      final c = LeaveController(repository: repo);
      await c.reload();
      expect(c.history.value.status, SectionStatus.empty);
      repo.balance = () async => fail7b(403);
      repo.history = () async => fail7b(403);
      await c.reload(userInitiated: true);
      expect(c.wholeScreenStatus, SectionStatus.forbidden);
      repo.balance = () async => fail7b(404, 'Cannot GET /api/v1/hr/leave/self/balance');
      repo.history = () async => fail7b(404, 'Cannot GET /api/v1/hr/leave/self/history');
      await c.reload(userInitiated: true);
      expect(c.wholeScreenStatus, SectionStatus.unavailable);
    });

    test('a request just created is shown at the top at once and both sections are re-read', () async {
      final c = LeaveController(repository: repo);
      repo.history = () async => [leaveRow('old', status: 'approved')];
      await c.reload();
      repo.history = () async => [leaveRow('new1'), leaveRow('old', status: 'approved')];
      c.added(leaveRow('new1'));
      expect(c.rows.map((l) => l.id), ['new1', 'old']);
      await pumpEventQueue();
      expect(repo.calls.where((x) => x == 'balance').length, 2);
      expect(c.rows.map((l) => l.id), ['new1', 'old'], reason: 'no duplicate after the re-read');
    });
  });

  group('Apply for leave (LeaveApplyController)', () {
    late FakeLeaveRepository repo;
    late LeaveController list;
    setUp(() async {
      repo = FakeLeaveRepository();
      list = Get.put(LeaveController(repository: repo));
      await list.reload();
    });

    LeaveApplyController make() => LeaveApplyController(repository: repo, list: list);
    void fill(LeaveApplyController c, {String reason = 'Family wedding out of town'}) {
      c.setFrom(DateTime(2026, 11, 2));
      c.setTo(DateTime(2026, 11, 4));
      c.reasonC.text = reason;
    }

    test('empty form: dates and reason reported, nothing sent; the type defaults to annual', () async {
      final c = make();
      expect(c.type.value, StaffLeaveType.annual);
      final r = await c.submit() as ApplyInvalid;
      expect(r.errors.keys, containsAll(['from', 'to', 'reason']));
      expect(repo.lastApply, isNull);
    });

    test('picking the first day carries the last day along; an earlier last day is refused; a half day is one day', () async {
      final c = make();
      c.setFrom(DateTime(2026, 11, 2));
      expect(c.to.value, DateTime(2026, 11, 2));
      c.setTo(DateTime(2026, 11, 5));
      c.setFrom(DateTime(2026, 11, 3));
      expect(c.to.value, DateTime(2026, 11, 5), reason: 'still valid: kept');
      c.setFrom(DateTime(2026, 11, 9));
      expect(c.to.value, DateTime(2026, 11, 9), reason: 'pushed along');
      c.setTo(DateTime(2026, 11, 1));
      c.reasonC.text = 'A perfectly good reason';
      expect((await c.submit() as ApplyInvalid).errors['to'], contains('on or after'));
      c.setHalfDay(true);
      expect(c.to.value, c.from.value);
    });

    test('a valid request is sent exactly as typed (trimmed) and the list shows it at once; the controller then refuses a second send', () async {
      final c = make();
      c.setType(StaffLeaveType.sick);
      fill(c, reason: '  Fever and a doctor rest advice  ');
      final r = await c.submit();
      expect(r, isA<ApplyDone>());
      expect(repo.lastApply!.toJson(), {'leaveType': 'sick', 'fromDate': '2026-11-02', 'toDate': '2026-11-04', 'reason': 'Fever and a doctor rest advice', 'isHalfDay': false});
      expect(list.rows.first.typeWire, 'sick');
      expect(await c.submit(), isA<ApplyIgnored>());
      expect(repo.calls.where((x) => x == 'apply'), hasLength(1));
    });

    test('double submit while the request is in flight sends once', () async {
      final c = make();
      fill(c);
      final gate = Completer<StaffLeaveRequest>();
      repo.apply0 = (b) => gate.future;
      final f = c.submit();
      expect(c.saving.value, isTrue);
      expect(await c.submit(), isA<ApplyIgnored>());
      gate.complete(leaveRow('l9'));
      expect(await f, isA<ApplyDone>());
      expect(repo.calls.where((x) => x == 'apply'), hasLength(1));
    });

    test('server rejection (400 validation / 403 / 500 / offline): text shown, every field kept, retry works', () async {
      final c = make();
      fill(c);
      repo.apply0 = (b) async => fail7b(400, 'LeaveApplication validation failed: reason: Path `reason` is required.');
      var r = await c.submit() as ApplyFailed;
      expect(r.text, contains('validation failed'));
      expect(c.failureText.value, r.text);
      expect((c.from.value, c.reasonC.text), (DateTime(2026, 11, 2), 'Family wedding out of town'));
      repo.apply0 = (b) async => fail7b(403, 'Forbidden resource');
      r = await c.submit() as ApplyFailed;
      expect(r.failure.isForbidden, isTrue);
      repo.apply0 = (b) async => fail7b(500);
      expect((await c.submit() as ApplyFailed).failure.canRetry, isTrue);
      repo.apply0 = (b) async => fail7b(null, 'No connection');
      expect((await c.submit() as ApplyFailed).failure.canRetry, isTrue);
      repo.apply0 = (b) async => leaveRow('ok');
      expect(await c.submit(), isA<ApplyDone>());
    });

    test('hints are informational: balance warning and overlap show but never block', () async {
      repo.balance = () async => balanceOf(annualUsed: 20); // 1 left
      repo.history = () async => [leaveRow('p', status: 'pending', from: '2026-11-03', to: '2026-11-03')];
      await list.reload(userInitiated: true);
      final c = make();
      fill(c);
      expect(c.balanceHint, contains('more than the 1 annual day'));
      expect(c.overlaps.map((l) => l.id), ['p']);
      expect(c.daysHint, contains('3 calendar days'));
      expect(await c.submit(), isA<ApplyDone>(), reason: 'the server decides');
    });

    test('dirty tracking', () {
      final c = make();
      expect(c.isDirty, isFalse);
      c.reasonC.text = 'x';
      expect(c.isDirty, isTrue);
    });
  });
}
