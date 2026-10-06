// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';
import 'package:eldermin_teacher_app/app/modules/home/models/section_state.dart';
import 'package:eldermin_teacher_app/app/modules/syllabus/controllers/syllabus_controller.dart';
import 'package:eldermin_teacher_app/app/modules/syllabus/controllers/syllabus_detail_controller.dart';
import 'package:eldermin_teacher_app/app/modules/syllabus/controllers/weekly_planner_controller.dart';
import 'package:eldermin_teacher_app/core/models/academic/syllabus_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_academic_repositories.dart';

const cls5a = {'gradeLevel': 'Grade 5', 'sectionName': 'A', 'subjectName': 'Mathematics'};
const cls6b = {'gradeLevel': 'Grade 6', 'sectionName': 'B', 'subjectName': 'Science'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeSyllabusRepository repo;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakeSyllabusRepository();
  });
  tearDown(Get.reset);

  Future<({SyllabusController list, dynamic h})> makeList({List<String>? permissions, List<Map<String, Object?>> assignments = const [cls5a, cls6b]}) async {
    final h = await signedIn(permissions: permissions);
    h.api.assignments = assignments;
    await h.auth.refreshProfile(force: true);
    return (list: SyllabusController(repository: repo, auth: h.auth, permissions: h.perms), h: h);
  }

  String idOf(SyllabusController c, String subject, String grade) => c.items.firstWhere((s) => s.subjectName == subject && s.gradeLevel == grade).id;

  group('SyllabusController: which syllabi are mine', () {
    test('asks by teacherId (staff + profile) and once per grade of MY assignments', () async {
      final c = (await makeList()).list;
      await c.load();
      expect(repo.queries, [
        {'teacherId': myStaff6},
        {'teacherId': myProfile6},
        {'gradeLevel': 'Grade 5'},
        {'gradeLevel': 'Grade 6'},
      ]);
    });

    test('keeps assigned-to-me and my class + subject; drops a colleague\'s other subject and archived ones', () async {
      final c = (await makeList()).list;
      await c.load();
      final names = c.items.map((s) => '${s.subjectName} ${s.classLabel}').toList();
      expect(names, containsAll(['Mathematics Grade 5 - A', 'Science Grade 6 - B', 'Mathematics Grade 5']));
      expect(names, isNot(contains('English Grade 5 - A'))); // not my subject
      final shared = c.items.firstWhere((s) => s.subjectName == 'Mathematics' && s.sectionName.isEmpty);
      expect(c.assignedToMe(shared), isFalse); // whole-grade scheme of a colleague: "Your class"
      expect(c.forMyClass(shared), isTrue);
      final legacy = c.items.firstWhere((s) => s.gradeLevel == 'Grade 7');
      expect(c.assignedToMe(legacy), isTrue); // keyed by my teacher-profile id
    });

    test('archived syllabi are never listed', () async {
      repo.onList = (q) async => [Syllabus.fromJson({'_id': 'x', 'subjectName': 'Mathematics', 'gradeLevel': 'Grade 5', 'sectionName': 'A', 'status': 'archived', 'teacherId': myStaff6})];
      final c = (await makeList()).list;
      await c.load();
      expect(c.state.value.status, SectionStatus.empty);
    });

    test('a failing class query does not hide the syllabi assigned to me', () async {
      repo.onList = (q) async {
        if (q.containsKey('gradeLevel')) throw ApiException('boom', statusCode: 500);
        return q['teacherId'] == myStaff6 ? [allSyllabi().firstWhere((s) => s.teacherId == myStaff6)] : [];
      };
      final c = (await makeList()).list;
      await c.load();
      expect(c.state.value.status, SectionStatus.data);
    });

    test('a failing teacherId query is an error with retry; 403 is forbidden; no permission asks nothing', () async {
      repo.onList = (q) async => throw ApiException('boom', statusCode: 500);
      final c = (await makeList()).list;
      await c.load();
      expect(c.state.value.status, SectionStatus.error);
      repo.onList = (q) async => throw ApiException('Forbidden resource', statusCode: 403);
      await c.load(force: true);
      expect(c.state.value.status, SectionStatus.forbidden);
      Get.reset();
      Get.testMode = true;
      final r = await makeList(permissions: ['dashboard:view']);
      await r.list.load();
      expect(r.list.state.value.status, SectionStatus.forbidden);
      expect(repo.queries.where((q) => q.isEmpty), isEmpty);
    });

    test('no assignment and no syllabus assigned: honest empty state; a teacher with no class asks only by id', () async {
      repo.onList = (q) async => [];
      final c = (await makeList(assignments: const [])).list;
      await c.load();
      expect(c.state.value.status, SectionStatus.empty);
      expect(repo.queries.every((q) => q.containsKey('teacherId')), isTrue);
    });

    test('filters: behind / completed with counts', () async {
      final c = (await makeList()).list;
      await c.load();
      expect(c.countFor(SyllabusFilter.behind), 1);
      c.setFilter(SyllabusFilter.behind);
      expect(c.filtered.single.subjectName, 'Science');
      c.setFilter(SyllabusFilter.completed);
      expect(c.filtered, isEmpty);
      expect(c.state.value.status, SectionStatus.data);
    });
  });

  group('Marking coverage: optimistic with rollback', () {
    Future<(SyllabusController, String)> ready() async {
      final c = (await makeList()).list;
      await c.load();
      return (c, idOf(c, 'Mathematics', 'Grade 5').isEmpty ? '' : c.items.firstWhere((s) => s.subjectName == 'Mathematics' && s.sectionName == 'A').id);
    }

    test('the tick flips BEFORE the server answers and the totals follow; success applies the server copy', () async {
      final slow = Completer<Syllabus>();
      repo.onMark = (id, u, t, s, covered) => slow.future;
      final (c, id) = await ready();
      final before = c.byId(id)!.progress.covered;
      final f = c.markSubTopic(id, 1, 1, 3, true);
      expect(c.byId(id)!.topicAt(1, 1)!.subTopics.last.isCovered, isTrue); // optimistic
      expect(c.byId(id)!.topicAt(1, 1)!.covered, isTrue); // derived parent
      expect(c.byId(id)!.progress.covered, before + 1);
      expect(c.isPending(id, 1, 1, 3), isTrue);
      slow.complete(c.byId(id)!.withSubTopicCovered(1, 1, 3, true));
      expect(await f, isA<MarkOk>());
      expect(c.isPending(id, 1, 1, 3), isFalse);
      expect(c.byId(id)!.progress.covered, before + 1);
    });

    test('failure rolls back ONLY that item and says why (403, 404, offline)', () async {
      final (c, id) = await ready();
      final before = c.byId(id)!.progress.covered;
      for (final e in [
        ApiException('Forbidden resource', statusCode: 403),
        ApiException('Topic 9 not found in unit 1', statusCode: 404),
        ApiException('No internet connection.'),
      ]) {
        repo.onMark = (i, u, t, s, covered) async => throw e;
        final r = await c.markSubTopic(id, 1, 1, 3, true);
        expect(r, isA<MarkFailed>());
        expect(c.byId(id)!.topicAt(1, 1)!.subTopics.last.isCovered, isFalse);
        expect(c.byId(id)!.progress.covered, before);
        expect(c.isPending(id, 1, 1, 3), isFalse);
        if (e.statusCode == 403) expect((r as MarkFailed).failure.message, contains("can't update this syllabus"));
        if (e.statusCode == null) expect((r as MarkFailed).failure.message, contains('put back'));
      }
    });

    test('sends exactly the unit/topic/sub-topic numbers, the value and MY name as coveredBy', () async {
      final (c, id) = await ready();
      await c.markSubTopic(id, 1, 1, 3, true);
      await c.markTopic(id, 2, 2, true);
      expect(repo.marks[0], (id: id, u: 1, t: 1, s: 3, covered: true, by: 'Tess Teacher'));
      expect(repo.marks[1], (id: id, u: 2, t: 2, s: null, covered: true, by: 'Tess Teacher'));
    });

    test('a topic that has sub-topics is never marked directly; marking the current value is a no-op', () async {
      final (c, id) = await ready();
      expect(await c.markTopic(id, 1, 1, true), isA<MarkIgnored>());
      expect(await c.markSubTopic(id, 1, 1, 1, true), isA<MarkIgnored>()); // already covered
      expect(repo.marks, isEmpty);
    });

    test('a tap on an item with a request in flight is ignored (no double request)', () async {
      final slow = Completer<Syllabus>();
      repo.onMark = (id, u, t, s, covered) => slow.future;
      final (c, id) = await ready();
      final f = c.markSubTopic(id, 1, 1, 3, true);
      expect(await c.markSubTopic(id, 1, 1, 3, false), isA<MarkIgnored>());
      slow.complete(c.byId(id)!);
      await f;
      expect(repo.marks, hasLength(1));
    });

    test('two ticks in flight: one failing does not undo the other, one succeeding does not undo the pending one', () async {
      final a = Completer<Syllabus>(), b = Completer<Syllabus>();
      repo.onMark = (id, u, t, s, covered) => s == 3 ? a.future : b.future;
      final (c, id) = await ready();
      final base = c.byId(id)!;
      final f1 = c.markSubTopic(id, 1, 1, 3, true); // mixed numbers
      final f2 = c.markSubTopic(id, 1, 2, 1, true); // place value
      // server answers #2 first with its own copy (which does not yet include #1)
      b.complete(base.withSubTopicCovered(1, 2, 1, true));
      await f2;
      expect(c.byId(id)!.topicAt(1, 1)!.subTopics.last.isCovered, isTrue); // #1 still shown (pending, re-applied)
      expect(c.byId(id)!.topicAt(1, 2)!.subTopics.first.isCovered, isTrue);
      a.completeError(ApiException('boom', statusCode: 500));
      expect(await f1, isA<MarkFailed>());
      expect(c.byId(id)!.topicAt(1, 1)!.subTopics.last.isCovered, isFalse); // #1 rolled back
      expect(c.byId(id)!.topicAt(1, 2)!.subTopics.first.isCovered, isTrue); // #2 kept
    });

    test('unticking works the same way and re-rolls the parent', () async {
      final (c, id) = await ready();
      expect(await c.markSubTopic(id, 1, 1, 1, false), isA<MarkOk>());
      expect(c.byId(id)!.topicAt(1, 1)!.subTopics.first.isCovered, isFalse);
      expect(repo.marks.single.covered, isFalse);
    });

    test('a plain topic: tick and rollback', () async {
      final (c, id) = await ready();
      await c.markTopic(id, 2, 2, true);
      expect(c.byId(id)!.topicAt(2, 2)!.isCovered, isTrue);
      repo.onMark = (i, u, t, s, covered) async => throw ApiException('x', statusCode: 500);
      await c.markTopic(id, 2, 2, false);
      expect(c.byId(id)!.topicAt(2, 2)!.isCovered, isTrue); // rolled back to covered
    });

    test('progress after each mark matches the server rollup (9 items, percent rounded)', () async {
      final (c, id) = await ready();
      expect(c.byId(id)!.progress.percent, 33);
      await c.markSubTopic(id, 1, 1, 3, true);
      expect(c.byId(id)!.progress.percent, 44); // 4/9
      await c.markTopic(id, 2, 2, true);
      expect(c.byId(id)!.progress.percent, 56); // 5/9
    });
  });

  group('SyllabusDetailController', () {
    test('shows a syllabus from the list; a cold link to one that is not mine is refused and dropped', () async {
      final h = await makeList();
      final d = SyllabusDetailController(id: allSyllabi().firstWhere((s) => s.subjectName == 'English').id, list: h.list, repository: repo);
      repo.onOne = (id) async => allSyllabi().firstWhere((s) => s.id == id);
      await d.load();
      expect(d.state.value.status, SectionStatus.error);
      expect(d.state.value.message, contains("isn't one of yours"));
      expect(h.list.byId(d.id), isNull);
    });

    test('a cold link to one of mine that the class queries missed is fetched and added', () async {
      final h = await makeList();
      repo.onList = (q) async => [];
      final target = allSyllabi().firstWhere((s) => s.subjectName == 'Mathematics' && s.sectionName == 'A');
      repo.onOne = (id) async => target;
      final d = SyllabusDetailController(id: target.id, list: h.list, repository: repo);
      await d.load();
      expect(d.state.value.status, SectionStatus.data);
      expect(h.list.byId(target.id), isNotNull);
    });

    test('404 and 403 on the cold fetch', () async {
      final h = await makeList();
      repo.onList = (q) async => [];
      final d = SyllabusDetailController(id: 'zz', list: h.list, repository: repo);
      await d.load();
      expect(d.state.value.status, SectionStatus.unavailable);
      repo.onOne = (id) async => throw ApiException('Forbidden', statusCode: 403);
      await d.load();
      expect(d.state.value.status, SectionStatus.forbidden);
    });

    test('lessons: only http(s) links are opened', () async {
      final opened = <Uri>[];
      final h = await makeList();
      final d = SyllabusDetailController(id: 'x', list: h.list, repository: repo, opener: (u) async {
        opened.add(u);
        return true;
      });
      expect(await d.openLesson(const SyllabusLesson(no: 1, url: 'https://example.test/v')), isTrue);
      expect(await d.openLesson(const SyllabusLesson(no: 2, url: 'javascript:alert(1)')), isFalse);
      expect(await d.openLesson(const SyllabusLesson(no: 3)), isFalse);
      expect(await d.openLesson(const SyllabusLesson(no: 4, fileUrl: 'file:///etc/passwd')), isFalse);
      expect(opened.map((u) => u.toString()), ['https://example.test/v']);
    });

    test('topic expansion toggles', () async {
      final h = await makeList();
      final d = SyllabusDetailController(id: 'x', list: h.list, repository: repo);
      d.toggleTopic(1, 2);
      expect(d.expanded, {'1:2'});
      d.toggleTopic(1, 2);
      expect(d.expanded, isEmpty);
    });
  });

  group('WeeklyPlannerController', () {
    var now = DateTime(2026, 10, 5, 9, 0);

    Future<WeeklyPlannerController> make() async {
      final h = await makeList();
      await h.list.load();
      final c = WeeklyPlannerController(repository: repo, syllabi: h.list, auth: h.h.auth, clock: () => now);
      return c;
    }

    setUp(() => now = DateTime(2026, 10, 5, 9, 0));

    test('asks for the planner with MY ids (staff + profile) and shows the server\'s current week', () async {
      final c = await make();
      await c.load();
      expect(repo.plannerCalls.single, [myStaff6, myProfile6]);
      expect(c.state.value.status, SectionStatus.data);
      expect(c.offset.value, 0);
      expect(c.weekLabel, 'This week');
      final k = c.cards;
      expect(k.map((e) => e.week).toSet(), {5});
      final maths = k.firstWhere((e) => e.entry.subjectName == 'Mathematics');
      expect(maths.rows.map((r) => r.sub.name).toSet(), {'Mixed numbers', 'Place value'});
    });

    test('week navigation: next shows the sub-topics planned for the next week, labels and bounds', () async {
      final c = await make();
      await c.load();
      c.later();
      expect(c.weekLabel, 'Next week');
      final maths = c.cards.firstWhere((e) => e.entry.subjectName == 'Mathematics');
      expect(maths.week, 6);
      expect(maths.rows.map((r) => r.sub.name), ['Rounding']);
      expect(maths.earlier, isEmpty); // "earlier" is only shown for this week
      c.later();
      expect(c.weekLabel, 'In 2 weeks');
      c.thisWeek();
      expect(c.offset.value, 0);
      c.earlier();
      expect(c.weekLabel, 'Last week');
      expect(c.cards.firstWhere((e) => e.entry.subjectName == 'Mathematics').rows.map((r) => r.sub.name), ['Unlike denominators']);
      for (var i = 0; i < 10; i++) {
        c.earlier();
      }
      expect(c.canGoEarlier, isFalse);
      expect(c.cards.every((e) => e.week >= 1), isTrue);
      expect(c.weekLabel, '4 weeks ago');
    });

    test('later stops at the last planned week of any syllabus', () async {
      final c = await make();
      await c.load();
      for (var i = 0; i < 30; i++) {
        c.later();
      }
      expect(c.canGoLater, isFalse);
      expect(c.offset.value, lessThan(13));
    });

    test('this week also lists sub-topics planned for EARLIER weeks and still not covered (real plannedWeek data)', () async {
      final c = await make();
      await c.load();
      final science = c.cards.firstWhere((e) => e.entry.subjectName == 'Science');
      expect(science.earlier.map((r) => r.sub.name), ['Outputs']); // planned week 3, not covered
      final maths = c.cards.firstWhere((e) => e.entry.subjectName == 'Mathematics');
      expect(maths.earlier, isEmpty);
    });

    test('empty planner, error then retry, 403', () async {
      final c = await make();
      repo.onPlanner = (_) async => [];
      await c.load();
      expect(c.state.value.status, SectionStatus.empty);
      repo.onPlanner = (_) async => throw ApiException('boom', statusCode: 500);
      await c.load(force: true);
      expect(c.state.value.status, SectionStatus.error);
      repo.onPlanner = (_) async => throw ApiException('Forbidden resource', statusCode: 403);
      await c.load(force: true);
      expect(c.state.value.status, SectionStatus.forbidden);
    });

    test('a tick made in the planner updates the syllabus (optimistic) and shows in the planner row', () async {
      final c = await make();
      await c.load();
      final maths = c.cards.firstWhere((e) => e.entry.subjectName == 'Mathematics');
      final id = maths.entry.syllabusId;
      final f = c.syllabi.markSubTopic(id, 1, 1, 3, true);
      expect(c.cards.firstWhere((e) => e.entry.syllabusId == id).rows.firstWhere((r) => r.sub.name == 'Mixed numbers').sub.isCovered, isTrue);
      await f;
    });

    test('the anchor week goes stale when the CALENDAR DAY changes (injectable clock, no wall clock)', () async {
      final c = await make();
      await c.load();
      expect(c.fetchedDay, DateTime(2026, 10, 5));
      c.later();
      now = DateTime(2026, 10, 5, 23, 59);
      await c.refreshIfStale();
      expect(repo.plannerCalls, hasLength(1)); // same day: no reload, offset kept
      expect(c.offset.value, 1);
      now = DateTime(2026, 10, 6, 0, 1);
      await c.refreshIfStale();
      expect(repo.plannerCalls, hasLength(2));
      expect(c.offset.value, 0); // re-anchored to "this week"
      expect(c.fetchedDay, DateTime(2026, 10, 6));
    });

    test('without teaching:view nothing is requested', () async {
      final h = await makeList(permissions: ['dashboard:view']);
      final c = WeeklyPlannerController(repository: repo, syllabi: h.list, auth: h.h.auth, clock: () => now);
      await c.load();
      expect(c.state.value.status, SectionStatus.forbidden);
      expect(repo.plannerCalls, isEmpty);
    });
  });
}
