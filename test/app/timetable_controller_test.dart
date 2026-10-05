import 'package:eldermin_teacher_app/app/modules/home/models/section_state.dart';
import 'package:eldermin_teacher_app/app/modules/timetable/controllers/timetable_controller.dart';
import 'package:eldermin_teacher_app/core/models/home/timetable.dart';
import 'package:eldermin_teacher_app/core/utils/home_time.dart';
import 'package:eldermin_teacher_app/core/utils/timetable_week.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_home_repository.dart';

const me = '64a0000000000000000000a1';

/// What the server returns: one entry per requested date, `dayOfWeek` from the date string in UTC
/// (staff-teaching.service.ts:216), slots chosen by weekday.
MyTimetable serverWeek(DateTime from, DateTime to, Map<int, List<TimetableSlot>> byDow) {
  final days = <TimetableDay>[];
  for (var d = DateTime.utc(from.year, from.month, from.day); !d.isAfter(DateTime.utc(to.year, to.month, to.day)); d = d.add(const Duration(days: 1))) {
    final dow = d.weekday % 7;
    days.add(TimetableDay(date: '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}', dayOfWeek: dow, slots: byDow[dow] ?? const []));
  }
  return MyTimetable(from: ymdOf(from), to: ymdOf(to), days: days);
}

String ymdOf(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const mon = [
  TimetableSlot(periodNo: 1, startTime: '08:00', endTime: '08:45', subject: 'Maths', gradeLevel: 'Grade 5', sectionName: 'A', roomNo: '101'),
  TimetableSlot(periodNo: 2, startTime: '09:00', endTime: '09:45', subject: 'Science', gradeLevel: 'Grade 6', sectionName: 'B', weekCycle: 'A'),
  TimetableSlot(periodNo: 2, startTime: '09:00', endTime: '09:45', subject: 'Science rev', gradeLevel: 'Grade 6', sectionName: 'B', weekCycle: 'B'),
  TimetableSlot(periodNo: 3, startTime: '11:00', endTime: '11:45', subject: 'Lab', gradeLevel: 'Grade 7', sectionName: 'C', splitGroup: SlotSplitGroup(name: 'Group 1', roomNo: 'Lab 1')),
];
const tue = [TimetableSlot(periodNo: 1, startTime: '10:00', endTime: '10:45', subject: 'English', gradeLevel: 'Grade 5', sectionName: 'A')];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeHomeRepository repo;
  late DateTime now;
  final requests = <(DateTime, DateTime)>[];

  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakeHomeRepository();
    now = DateTime(2026, 10, 5, 8, 10); // Monday
    requests.clear();
    repo.myTimetable = (f, t) async {
      requests.add((f, t));
      return serverWeek(f, t, {1: mon, 2: tue});
    };
  });
  tearDown(Get.reset);

  Future<TimetableController> make({List<String>? permissions}) async {
    final h = await signedIn(permissions: permissions);
    return TimetableController(repository: repo, auth: h.auth, permissions: h.perms, clock: () => now, tick: null);
  }

  test('loads Sunday..Saturday of the current week in ONE request (<=14 days) and exposes day + week data', () async {
    final c = await make();
    await c.load();
    expect(requests.single, (DateTime(2026, 10, 4), DateTime(2026, 10, 10)));
    expect(c.week.value.status, SectionStatus.data);
    expect(c.isTodaySelected, isTrue);
    final today = c.dayPeriods(DateTime(2026, 10, 5));
    expect(today.map((p) => p.period.subject), ['Maths', 'Science', 'Science rev', 'Lab']);
    expect(today.first.phase, PeriodPhase.current); // 08:10 within 08:00-08:45
    expect(today[1].phase, PeriodPhase.next); // A and B variants both "next": never guessed
    expect(today[2].phase, PeriodPhase.next);
    expect(today.map((p) => p.period.weekCycleTag), [null, 'A', 'B', null]);
    expect(today.last.period.splitLabel, 'Group 1');
    expect(c.showsWeekTags, isTrue);
    expect(c.dayPeriods(DateTime(2026, 10, 6)).single.phase, PeriodPhase.later); // Tuesday: no phase
    expect(c.dayPeriods(DateTime(2026, 10, 8)), isEmpty); // empty day inside a non-empty week
  });

  test('week navigation reloads only when the week changes; refresh forces; retry after error reloads', () async {
    final c = await make();
    await c.load();
    c.selectDate(DateTime(2026, 10, 7)); // same week
    await Future<void>.delayed(Duration.zero);
    expect(requests, hasLength(1));
    c.nextWeek();
    await Future<void>.delayed(Duration.zero);
    expect(requests.last, (DateTime(2026, 10, 11), DateTime(2026, 10, 17)));
    c.previousWeek();
    await Future<void>.delayed(Duration.zero);
    expect(requests.last, (DateTime(2026, 10, 4), DateTime(2026, 10, 10)));
    final before = requests.length;
    await c.refreshWeek();
    expect(requests.length, before + 1);
  });

  test('404 falls back to the old whole-class endpoint filtered to me; 403 and 500 never fall back', () async {
    repo.myTimetable = (_, __) async => failWith(404);
    repo.timetable = (id) async => [
          TimetableDoc(id: 'd', gradeLevel: 'Grade 5', sectionName: 'A', periods: [
            const TimetablePeriod(day: 1, periodNo: 1, startTime: '08:00', endTime: '08:45', subject: 'Maths', teacherId: me),
            const TimetablePeriod(day: 1, periodNo: 2, startTime: '09:00', endTime: '09:45', subject: 'English', teacherId: 'someone-else'),
          ])
        ];
    var c = await make();
    await c.load();
    expect(repo.calls, contains('timetable:$me'));
    expect(c.dayPeriods(DateTime(2026, 10, 5)).map((p) => p.period.subject), ['Maths']);

    for (final code in [403, 500]) {
      Get.reset();
      Get.testMode = true;
      repo = FakeHomeRepository()..myTimetable = (_, __) async => failWith(code);
      c = await make();
      await c.load();
      expect(repo.calls, isNot(contains('timetable:$me')), reason: '$code must not fall back');
      expect(c.week.value.status, code == 403 ? SectionStatus.forbidden : SectionStatus.error);
    }
  });

  test('error then retry succeeds (state recovers, request repeated)', () async {
    var fail = true;
    repo.myTimetable = (f, t) async {
      if (fail) failWith(500);
      return serverWeek(f, t, {1: mon});
    };
    final c = await make();
    await c.load();
    expect(c.week.value.status, SectionStatus.error);
    fail = false;
    await c.load(force: true);
    expect(c.week.value.status, SectionStatus.data);
  });

  test('an entirely empty week is the empty state; no permission is forbidden without any request', () async {
    repo.myTimetable = (f, t) async => serverWeek(f, t, {});
    var c = await make();
    await c.load();
    expect(c.week.value.status, SectionStatus.empty);

    Get.reset();
    Get.testMode = true;
    repo = FakeHomeRepository();
    c = await make(permissions: ['students:view']);
    await c.load();
    expect(c.week.value.status, SectionStatus.forbidden);
    expect(repo.calls, isEmpty);
  });

  test('midnight rollover moves "today" and follows it to the next week when it was selected', () async {
    now = DateTime(2026, 10, 10, 23, 59); // Saturday
    final c = await make();
    await c.load();
    expect(c.weekStart, DateTime(2026, 10, 4));
    now = DateTime(2026, 10, 11, 0, 1); // Sunday: a new week
    c.advanceClock();
    await Future<void>.delayed(Duration.zero);
    expect(c.isTodaySelected, isTrue);
    expect(c.weekStart, DateTime(2026, 10, 11));
    expect(requests.last, (DateTime(2026, 10, 11), DateTime(2026, 10, 17)));
  });

  test('rollover does NOT yank the user away from a date they picked', () async {
    final c = await make();
    await c.load();
    c.selectDate(DateTime(2026, 10, 7));
    now = DateTime(2026, 10, 6, 0, 5);
    c.advanceClock();
    expect(c.selectedDate.value, DateTime(2026, 10, 7));
    expect(c.today, DateTime(2026, 10, 6));
  });

  test('a stale response from a previous week never overwrites the current week', () async {
    final c = await make();
    final slow = <DateTime, Future<MyTimetable> Function()>{};
    repo.myTimetable = (f, t) => slow[f]?.call() ?? Future.value(serverWeek(f, t, {1: mon}));
    var release = () {};
    slow[DateTime(2026, 10, 4)] = () async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      release();
      return serverWeek(DateTime(2026, 10, 4), DateTime(2026, 10, 10), {2: tue});
    };
    final first = c.load();
    c.nextWeek(); // user moves on while week 1 is still loading
    await first;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(c.weekStart, DateTime(2026, 10, 11));
    expect(c.dayPeriods(DateTime(2026, 10, 12)).map((p) => p.period.subject), contains('Maths'));
    expect(c.dayPeriods(DateTime(2026, 10, 13)), isEmpty); // week-1 data (Tuesday English) did not leak in
  });

  group('wall-clock zones', () {
    final zones = {
      'UTC': const Duration(),
      'Pacific/Auckland': const Duration(hours: 13),
      'America/Los_Angeles': const Duration(hours: -7),
      'Asia/Karachi': const Duration(hours: 5),
    };
    for (final z in zones.entries) {
      test('${z.key}: request window and NOW come from the device wall clock', () async {
        final u = DateTime.utc(2026, 10, 10, 20, 0); // Sat 20:00Z
        final w = u.add(z.value);
        now = DateTime(w.year, w.month, w.day, w.hour, w.minute);
        final c = await make();
        await c.load();
        final start = weekStartOf(now);
        expect(requests.single, (start, addDays(start, 6)));
        expect(requests.single.$1.weekday, DateTime.sunday);
        expect(c.isTodaySelected, isTrue);
        expect(ymdOf(c.today), ymdOf(DateTime(w.year, w.month, w.day)));
      });
    }
  });
}
