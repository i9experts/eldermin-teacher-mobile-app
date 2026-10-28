// ignore_for_file: invalid_use_of_protected_member
// T1 (controllers): no-section records / students, server-side filters, paging, edit mode, resolve data flow, points + trait labels.
import 'package:eldermin_teacher_app/app/modules/behaviour/controllers/behaviour_controller.dart';
import 'package:eldermin_teacher_app/app/modules/behaviour/controllers/behaviour_log_controller.dart';
import 'package:eldermin_teacher_app/app/modules/behaviour/controllers/behaviour_student_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/models/section_state.dart';
import 'package:eldermin_teacher_app/core/models/behaviour/behaviour_models.dart';
import 'package:eldermin_teacher_app/core/models/classroom/student_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_classroom_repositories.dart';
import '../support/fake_phase5b_repositories.dart';

BehaviourRecord rec(String id,
        {String sid = 'st1', String grade = 'Grade 5', String? section = 'A', String type = 'negative', String by = 'Someone', String? byId, String day = '2026-10-01', int points = -2, Map<String, Object?> extra = const {}}) =>
    BehaviourRecord.fromJson({
      '_id': id, 'studentId': sid, 'studentName': 'Zara', 'grade': grade, 'section': section, 'type': type, 'category': 'misconduct', 'title': 'T$id',
      'description': 'd', 'date': '${day}T00:00:00.000Z', 'points': points, 'reportedBy': by, if (byId != null) 'reportedById': byId, ...extra,
    });

final fixedNow = DateTime(2026, 10, 5, 9, 30);
const cls5a = {'gradeLevel': 'Grade 5', 'sectionName': 'A', 'subjectName': 'Mathematics'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeBehaviourRepository repo;
  late FakeStudentsRepository students;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakeBehaviourRepository();
    students = FakeStudentsRepository()..grades = (() async => const GradesSections(grades: ['Grade 5'], sections: ['A', 'B']));
  });
  tearDown(Get.reset);

  Future<BehaviourController> makeList({List<String>? permissions}) async {
    final h = await signedIn(permissions: permissions);
    h.api.assignments = const [cls5a];
    await h.auth.refreshProfile(force: true);
    return BehaviourController(repository: repo, students: students, auth: h.auth, permissions: h.perms);
  }

  group('BehaviourController: records without a section', () {
    test('a record with a missing / empty / blank section appears for a sectioned class; another section and grade do not', () async {
      repo.gradeRecords = (g) async => [
            rec('a', section: 'A'),
            rec('none', section: null),
            rec('empty', section: ''),
            rec('blank', section: '   '),
            rec('b', section: 'B'),
            rec('g6', grade: 'Grade 6', section: ''),
          ];
      final c = await makeList();
      await c.load();
      expect(c.all.map((r) => r.id), unorderedEquals(['a', 'none', 'empty', 'blank']));
    });

    test('they are in "my classes"; "my entries" still means by author', () async {
      repo.gradeRecords = (g) async => [rec('none', section: '', byId: 'u'), rec('theirs', section: '', by: 'Omar')];
      final c = await makeList();
      await c.load();
      expect(c.visible.map((r) => r.id), ['none']);
      c.setScope(BehaviourScope.classes);
      expect(c.visible.map((r) => r.id), unorderedEquals(['none', 'theirs']));
    });
  });

  group('BehaviourController: filters (server-side) and paging', () {
    test('setFilters reloads from page 1 with the backend params; the first load sends none', () async {
      repo.gradeRecords = (g) async => [rec('x')];
      final c = await makeList();
      await c.load();
      expect(repo.queries.last.keys.toSet(), {'grade', 'section', 'studentId', 'mine', 'page', 'limit'});
      await c.setFilters(RecordFilters(type: 'negative', severity: 'high', resolved: false, from: DateTime(2026, 9, 1), to: DateTime(2026, 9, 30)));
      final q = repo.queries.last;
      expect(q['type'], 'negative');
      expect(q['severity'], 'high');
      expect(q['resolved'], 'false');
      expect(q['from'], '2026-09-01');
      expect(q['to'], '2026-09-30T23:59:59.999Z');
      expect(q['page'], 1);
    });

    test('a server that ignores a filter cannot show a non-matching record (client re-check)', () async {
      repo.gradeRecords = (g) async => [rec('neg', type: 'negative'), rec('pos', type: 'positive', points: 3, byId: 'u')];
      final c = await makeList();
      await c.load();
      c.setScope(BehaviourScope.classes);
      await c.setFilters(const RecordFilters(type: 'positive'));
      expect(c.visible.map((r) => r.id), ['pos']);
    });

    test('filter with no match keeps the controls (state stays data, visible empty); clearing restores the list', () async {
      repo.gradeRecords = (g) async => g.isEmpty ? [] : [rec('neg')];
      final c = await makeList();
      await c.load();
      c.setScope(BehaviourScope.classes);
      repo.gradeRecords = (g) async => [];
      await c.setFilters(const RecordFilters(severity: 'critical'));
      expect(c.state.value.status, SectionStatus.data);
      expect(c.visible, isEmpty);
      repo.gradeRecords = (g) async => [rec('neg')];
      await c.setFilters(RecordFilters.none);
      expect(c.visible.map((r) => r.id), ['neg']);
    });

    test('submitSearch sends the text to the server once and filters locally while typing', () async {
      repo.gradeRecords = (g) async => [rec('x'), rec('y')];
      final c = await makeList();
      await c.load();
      c.setScope(BehaviourScope.classes);
      c.query.value = 'Tx';
      expect(c.visible.map((r) => r.id), ['x']);
      await c.submitSearch('Tx');
      expect(repo.queries.last['search'], 'Tx');
      final before = repo.queries.length;
      await c.submitSearch('Tx');
      expect(repo.queries.length, before, reason: 'same text: no second request');
    });

    test('paging: page 1 shows hasMore; loadMore appends older records without duplicates until the end', () async {
      repo.pageSize = 2;
      repo.gradeRecords = (g) async => [for (var i = 1; i <= 5; i++) rec('r$i', day: '2026-10-0${6 - i}')];
      final c = await makeList();
      await c.load();
      expect(c.all, hasLength(2));
      expect(c.hasMore.value, isTrue);
      await c.loadMore();
      expect(c.all, hasLength(4));
      expect(c.hasMore.value, isTrue);
      await c.loadMore();
      expect(c.all.map((r) => r.id), ['r1', 'r2', 'r3', 'r4', 'r5']);
      expect(c.hasMore.value, isFalse);
      await c.loadMore(); // nothing left: no request
      expect(repo.queries.map((q) => q['page']), [1, 2, 3]);
    });

    test('everything on one page: no "load more"', () async {
      repo.gradeRecords = (g) async => [rec('a')];
      final c = await makeList();
      await c.load();
      expect(c.hasMore.value, isFalse);
    });

    test('loadMore failure keeps the list, shows a message, and a retry works', () async {
      repo.pageSize = 1;
      var fail = false;
      repo.gradeRecords = (g) async {
        if (fail) throw ApiException('offline');
        return [rec('r1'), rec('r2')];
      };
      final c = await makeList();
      await c.load();
      fail = true;
      await c.loadMore();
      expect(c.all, hasLength(1));
      expect(c.loadMoreError.value, isNotNull);
      expect(c.hasMore.value, isTrue);
      fail = false;
      await c.loadMore();
      expect(c.loadMoreError.value, isNull);
      expect(c.all, hasLength(2));
    });

    test('replaceRecord swaps an edited / resolved record in place', () async {
      repo.gradeRecords = (g) async => [rec('x'), rec('y')];
      final c = await makeList();
      await c.load();
      c.replaceRecord(rec('x', extra: {'resolved': true, 'resolvedNote': 'done'}));
      expect(c.all.firstWhere((r) => r.id == 'x').resolved, isTrue);
      expect(c.all, hasLength(2));
      c.replaceRecord(rec('unknown'));
      expect(c.all, hasLength(2));
    });
  });

  group('BehaviourLogController: new fields and edit mode', () {
    Future<BehaviourLogController> make({BehaviourRecord? editing, StudentSummary? initial}) async {
      final h = await signedIn();
      h.api.assignments = const [cls5a];
      await h.auth.refreshProfile(force: true);
      final list = BehaviourController(repository: repo, students: students, auth: h.auth, permissions: h.perms);
      final c = BehaviourLogController(repository: repo, students: students, auth: h.auth, permissions: h.perms, list: list, clock: () => fixedNow, initialStudent: initial, editing: editing);
      c.onInit();
      addTearDown(c.onClose);
      await Future<void>.delayed(Duration.zero);
      return c;
    }

    final z = student(1);

    test('create sends consequence, location, follow-up and parent-notified when set', () async {
      final c = await make(initial: z);
      c.setCategory('helping_others');
      c.descriptionC.text = 'Helped';
      c.setConsequence('verbal_warning');
      c.locationC.text = 'Playground';
      c.setFollowUp(true);
      c.setParentNotified(true);
      final r = await c.submit();
      expect(r, isA<LogSaved>());
      final b = repo.bodies.single;
      expect(b['consequence'], 'verbal_warning');
      expect(b['location'], 'Playground');
      expect(b['followUpRequired'], true);
      expect(b['parentNotified'], true);
      expect(repo.calls, contains('create'));
    });

    test('the consequence chip toggles off on a second tap; untouched new fields keep the old payload', () async {
      final c = await make(initial: z);
      c.setConsequence('detention');
      c.setConsequence('detention');
      expect(c.consequence.value, '');
      c.setCategory('helping_others');
      c.descriptionC.text = 'x';
      await c.submit();
      final b = repo.bodies.single;
      expect(b.containsKey('consequence'), isFalse);
      expect(b.containsKey('location'), isFalse);
      expect(b['parentNotified'], false);
      expect(b['followUpRequired'], false);
    });

    test('the new fields count as unsaved changes', () async {
      for (final change in <void Function(BehaviourLogController)>[
        (c) => c.setConsequence('detention'),
        (c) => c.locationC.text = 'x',
        (c) => c.setFollowUp(true),
        (c) => c.setParentNotified(true),
      ]) {
        final c = await make(initial: z);
        expect(c.isDirty, isFalse);
        change(c);
        expect(c.isDirty, isTrue);
      }
    });

    test('picker rosters are requested with the no-section rule; a no-section student can be selected and logged', () async {
      students.roster = (cls) async => [student(1, section: '')];
      final c = await make();
      await c.loadPickerClass();
      expect(students.rosterIncludeUnsectioned, isNotEmpty);
      expect(students.rosterIncludeUnsectioned.every((v) => v), isTrue);
      final s = student(1, section: '');
      c.selectStudent(s);
      c.setCategory('helping_others');
      c.descriptionC.text = 'ok';
      expect(c.validate(), isEmpty, reason: 'a student without a section is in the class by grade');
    });

    group('edit', () {
      final mine = rec('e1', byId: 'u', extra: {
        'type': 'negative', 'severity': 'high', 'points': -3, 'category': 'misconduct', 'title': 'Disrupted', 'description': 'Talked', 'location': 'Hall',
        'consequence': 'detention', 'followUpRequired': true, 'parentNotified': true, 'resolved': false,
      }, section: 'A');

      test('opens prefilled with the record, student fixed, and is NOT dirty until something changes', () async {
        final c = await make(editing: mine);
        expect(c.isEditing, isTrue);
        expect(c.kind.value, BehaviourKind.demerit);
        expect(c.category.value, 'misconduct');
        expect(c.severity.value, 'high');
        expect(c.magnitude.value, 3);
        expect(c.titleC.text, 'Disrupted');
        expect(c.descriptionC.text, 'Talked');
        expect(c.locationC.text, 'Hall');
        expect(c.consequence.value, 'detention');
        expect(c.followUpRequired.value, isTrue);
        expect(c.student.value!.id, 'st1');
        expect(c.isDirty, isFalse);
        c.titleC.text = 'Disrupted again';
        expect(c.isDirty, isTrue);
        c.titleC.text = 'Disrupted';
        expect(c.isDirty, isFalse, reason: 'back to the opened state');
      });

      test('save sends a PUT with only the edited fields, never POSTs, never loads the picker', () async {
        final c = await make(editing: mine);
        expect(students.calls.where((x) => x.startsWith('roster')), isEmpty);
        c.titleC.text = 'New title';
        c.locationC.text = '';
        c.setConsequence('detention'); // tap on the current value clears it
        final r = await c.submit();
        expect(r, isA<LogSaved>());
        expect(repo.calls, contains('update:e1'));
        expect(repo.calls, isNot(contains('create')));
        final b = repo.bodies.single;
        expect(b['title'], 'New title');
        expect(b['location'], '');
        expect(b['consequence'], '');
        for (final k in ['studentId', 'reportedBy', 'reportedById', 'parentNotified', 'schoolSlug']) {
          expect(b.containsKey(k), isFalse, reason: k);
        }
      });

      test('the saved record replaces the old one in the list (no duplicate)', () async {
        repo.gradeRecords = (g) async => [mine];
        final h = await signedIn();
        h.api.assignments = const [cls5a];
        await h.auth.refreshProfile(force: true);
        final list = BehaviourController(repository: repo, students: students, auth: h.auth, permissions: h.perms);
        await list.load();
        repo.onUpdate = (id, b) async => rec(id, byId: 'u', extra: {...b, 'title': 'Edited on server'});
        final c = BehaviourLogController(repository: repo, students: students, auth: h.auth, permissions: h.perms, list: list, clock: () => fixedNow, editing: mine);
        c.onInit();
        addTearDown(c.onClose);
        c.titleC.text = 'x';
        await c.submit();
        expect(list.all, hasLength(1));
        expect(list.all.single.title, 'Edited on server');
      });

      test('a record with an unusual points magnitude keeps it selectable', () async {
        final c = await make(editing: rec('e2', byId: 'u', points: -7));
        expect(c.magnitudeChoices, contains(7));
        expect(c.magnitude.value, 7);
        expect(BehaviourLogController.pointChoices, isNot(contains(7)));
      });

      test('403 from the server (not my record): friendly failure, form kept, saving flag released', () async {
        repo.onUpdate = (id, b) async => throw ApiException('You can only edit behaviour records you logged yourself.', statusCode: 403);
        final c = await make(editing: mine);
        c.titleC.text = 'x';
        final r = await c.submit();
        expect(r, isA<LogFailed>());
        expect(c.failure.value!.message, isNotEmpty);
        expect(c.titleC.text, 'x');
        expect(c.saving.value, isFalse);
      });

      test('required fields are still checked in edit mode', () async {
        final c = await make(editing: mine);
        c.titleC.text = '  ';
        final r = await c.submit();
        expect(r, isA<LogInvalid>());
        expect((r as LogInvalid).errors.keys, contains('title'));
        expect(repo.calls, isNot(contains('update:e1')));
      });
    });
  });

  group('BehaviourStudentController: sections, paging, points, labels', () {
    Future<BehaviourStudentController> make({String id = 'st1', StudentSummary? initial}) async {
      final h = await signedIn();
      h.api.assignments = const [cls5a];
      await h.auth.refreshProfile(force: true);
      return BehaviourStudentController(studentId: id, initial: initial, repository: repo, students: students, auth: h.auth, permissions: h.perms);
    }

    test('a student WITHOUT a section is resolved (deep link and preselected) and opens', () async {
      final noSection = StudentSummary(id: 'st9', firstName: 'N', lastName: 'S', grade: 'Grade 5', section: '');
      repo.studentRecords = (id) async => [rec('r1', sid: 'st9')];
      var c = await make(id: 'st9', initial: noSection);
      await c.load();
      expect(c.student.value.status, SectionStatus.data);
      students.roster = (cls) async => [noSection];
      c = await make(id: 'st9');
      await c.load();
      expect(c.student.value.data!.id, 'st9');
      expect(students.rosterIncludeUnsectioned.every((v) => v), isTrue);
    });

    test('a student of another grade is still refused even without a section', () async {
      final other = StudentSummary(id: 'st8', firstName: 'N', lastName: 'S', grade: 'Grade 6', section: '');
      final c = await make(id: 'st8', initial: other);
      await c.load();
      expect(c.student.value.status, SectionStatus.empty);
      expect(repo.calls.where((x) => x.startsWith('student:')), isEmpty);
    });

    test('records page: loadMoreRecords appends; failure keeps them and a retry works', () async {
      repo.pageSize = 2;
      var fail = false;
      repo.studentRecords = (id) async {
        if (fail) throw ApiException('offline');
        return [for (var i = 1; i <= 3; i++) rec('r$i', day: '2026-10-0${4 - i}')];
      };
      final c = await make(initial: student(1).copyForTest());
      await c.load();
      expect(c.records.value.data, hasLength(2));
      expect(c.recordsHasMore.value, isTrue);
      fail = true;
      await c.loadMoreRecords();
      expect(c.recordsLoadMoreError.value, isNotNull);
      expect(c.records.value.data, hasLength(2));
      fail = false;
      await c.loadMoreRecords();
      expect(c.records.value.data!.map((r) => r.id), ['r1', 'r2', 'r3']);
      expect(c.recordsHasMore.value, isFalse);
    });

    test('points: the server total wins (counts every record); without it the loaded records are summed', () async {
      repo.studentRecords = (id) async => [rec('r1', points: 5), rec('r2', points: -2)];
      repo.points = (id) async => 42;
      var c = await make(initial: student(1).copyForTest());
      await c.load();
      expect(c.totalPoints, 42);
      repo.points = (id) async => throw ApiException('nope', statusCode: 403);
      c = await make(initial: student(1).copyForTest());
      await c.load();
      expect(c.totalPoints, 3);
    });

    test('trait labels: the school settings when they load, the built-in names when not (never an error)', () async {
      repo.settings = () async => const CharacterSettings(moduleDisplayName: 'Akhlaq', traitLabels: {'sidq': 'Honesty'});
      var c = await make(initial: student(1).copyForTest());
      await c.load();
      expect(c.settings.value.programName, 'Akhlaq');
      expect(c.settings.value.labelFor('sidq'), 'Honesty');
      repo.settings = () async => throw ApiException('forbidden', statusCode: 403);
      c = await make(initial: student(1).copyForTest());
      await c.load();
      expect(c.settings.value.programName, 'Tarbiyah');
      expect(c.settings.value.labelFor('sidq'), 'Truthfulness (Sidq)');
      expect(c.student.value.status, SectionStatus.data, reason: 'a failed side request never hides the student');
    });

    test('replaceRecord updates the history in place', () async {
      repo.studentRecords = (id) async => [rec('r1'), rec('r2')];
      final c = await make(initial: student(1).copyForTest());
      await c.load();
      c.replaceRecord(rec('r1', extra: {'resolved': true}));
      expect(c.records.value.data!.firstWhere((r) => r.id == 'r1').resolved, isTrue);
    });
  });
}

extension _Copy on StudentSummary {
  /// The fake roster students have ids like st000...; the history screens here use 'st1'.
  StudentSummary copyForTest() => StudentSummary(id: 'st1', firstName: firstName, lastName: lastName, grade: grade, section: section, rollNumber: rollNumber, academicYear: academicYear);
}
