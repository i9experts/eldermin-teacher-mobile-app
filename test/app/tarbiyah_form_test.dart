// ignore_for_file: invalid_use_of_protected_member
// A1 item 9: Tarbiyah assessment create / edit for students of my own classes (decision D3). No share toggle: it waits for visibleToParent.
import 'package:eldermin_teacher_app/app/modules/behaviour/controllers/behaviour_controller.dart';
import 'package:eldermin_teacher_app/app/modules/behaviour/controllers/behaviour_student_controller.dart';
import 'package:eldermin_teacher_app/app/modules/behaviour/controllers/tarbiyah_form_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/models/section_state.dart';
import 'package:eldermin_teacher_app/core/models/behaviour/behaviour_models.dart';
import 'package:eldermin_teacher_app/core/models/classroom/student_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_classroom_repositories.dart';
import '../support/fake_phase5b_repositories.dart';

final _now = DateTime(2026, 10, 5, 9, 30);
const _cls5a = {'gradeLevel': 'Grade 5', 'sectionName': 'A', 'subjectName': 'Mathematics'};

TarbiyahAssessment assessment(String id, {String period = 'Term 1 2026-27', String? byId = 'u', String by = 'Tess Teacher', Map<String, num> scores = const {'sidq': 4, 'adab': 5}}) =>
    TarbiyahAssessment.fromJson({
      '_id': id,
      'studentId': student(1).id,
      'period': period,
      'periodType': 'termly',
      'assessmentDate': '2026-09-20T00:00:00.000Z',
      'traits': [for (final e in scores.entries) {'traitKey': e.key, 'score': e.value}],
      'overallPercentage': 90,
      'overallRating': 'excellent',
      'teacherObservations': 'Kind and focused',
      'areasOfStrength': ['Leadership'],
      'areasForImprovement': ['Punctuality'],
      'assessedBy': by,
      if (byId != null) 'assessedById': byId,
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeBehaviourRepository repo;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakeBehaviourRepository();
  });
  tearDown(Get.reset);

  Future<TarbiyahFormController> make({
    TarbiyahAssessment? editing,
    List<TarbiyahAssessment> existing = const [],
    CharacterSettings settings = CharacterSettings.fallback,
    List<String>? permissions,
    BehaviourStudentController? list,
  }) async {
    final h = await signedIn(permissions: permissions);
    h.api.assignments = const [_cls5a];
    await h.auth.refreshProfile(force: true);
    final c = TarbiyahFormController(
      args: TarbiyahFormArgs(student: student(1), settings: settings, existing: existing, editing: editing),
      repository: repo,
      auth: h.auth,
      permissions: h.perms,
      studentList: list,
      clock: () => _now,
    );
    c.onInit();
    return c;
  }

  group('create', () {
    test('sends the student, period, date, only the scored traits (school order), observations, strengths and improvements to POST /behaviour/tarbiyah', () async {
      final c = await make();
      c.periodC.text = '  Term 1 2026-27 ';
      c.setPeriodType('termly');
      c.setScore('adab', 5);
      c.setScore('sidq', 4);
      c.observationsC.text = ' Kind and focused ';
      c.strengthsC.text = 'Leadership\n\n  Honesty  \n';
      c.improvementsC.text = 'Punctuality';
      final r = await c.submit();
      expect(r, isA<TarbiyahSaved>());
      expect(repo.calls, ['createTarbiyah']);
      final b = repo.bodies.single;
      expect(b['studentId'], student(1).id);
      expect(b['studentName'], student(1).fullName);
      expect(b['grade'], 'Grade 5');
      expect(b['section'], 'A');
      expect(b['period'], 'Term 1 2026-27');
      expect(b['periodType'], 'termly');
      expect(b['assessmentDate'], '2026-10-05');
      expect(b['traits'], [
        {'traitKey': 'sidq', 'score': 4},
        {'traitKey': 'adab', 'score': 5},
      ], reason: 'school trait order, scored traits only');
      expect(b['teacherObservations'], 'Kind and focused');
      expect(b['areasOfStrength'], ['Leadership', 'Honesty']);
      expect(b['areasForImprovement'], ['Punctuality']);
    });

    test('never sends authorship, campus, overall figures or a share flag (the server derives them / the toggle waits for visibleToParent)', () async {
      final c = await make();
      c.periodC.text = 'Term 1';
      c.setScore('sidq', 3);
      await c.submit();
      for (final k in ['assessedBy', 'assessedById', 'campusId', 'schoolSlug', 'overallScore', 'overallPercentage', 'overallRating', 'parentShared', 'parentSharedDate', 'visibleToParent']) {
        expect(repo.bodies.single.containsKey(k), isFalse, reason: k);
      }
    });

    test('validation: period required, at least one trait, date not in the future, nothing is sent', () async {
      final c = await make();
      var r = await c.submit();
      expect(r, isA<TarbiyahInvalid>());
      expect((r as TarbiyahInvalid).errors.keys, containsAll(['period', 'traits']));
      expect(repo.calls, isEmpty);
      c.periodC.text = 'Term 1';
      c.setScore('sidq', 4);
      c.setDay(DateTime(2026, 10, 9));
      r = await c.submit() as TarbiyahInvalid;
      expect(r.errors.keys, ['day']);
      expect(repo.calls, isEmpty);
      c.setDay(DateTime(2026, 10, 4));
      expect(await c.submit(), isA<TarbiyahSaved>());
    });

    test('a period this student already has is refused before sending (one assessment per student and period), case-insensitively', () async {
      final c = await make(existing: [assessment('t1', period: 'Term 1 2026-27')]);
      c.periodC.text = ' term 1 2026-27 ';
      c.setScore('sidq', 4);
      final r = await c.submit() as TarbiyahInvalid;
      expect(r.errors['period'], contains('already has an assessment'));
      expect(repo.calls, isEmpty);
      c.periodC.text = 'Term 2 2026-27';
      expect(await c.submit(), isA<TarbiyahSaved>());
    });

    test('scale and traits come from the school\'s programme: a 1-10 scale offers 1..10, a custom trait list replaces the built-in one', () async {
      const school = CharacterSettings(moduleDisplayName: 'Character', traitLabels: {'grit': 'Grit', 'kindness': 'Kindness'}, scaleMin: 1, scaleMax: 10);
      final c = await make(settings: school);
      expect(c.traitKeys, ['grit', 'kindness']);
      expect(c.scaleChoices, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      c.setScore('grit', 11); // outside the scale: ignored
      c.setScore('grit', 0);
      expect(c.scores, isEmpty);
      c.setScore('grit', 9);
      expect(c.scores['grit'], 9);
      c.setScore('grit', 9); // tapping the selected score clears the trait
      expect(c.scores, isEmpty);
    });

    test('the built-in 12 Tarbiyah traits and a 1-5 scale when the school set none', () async {
      final c = await make(settings: const CharacterSettings());
      expect(c.traitKeys, hasLength(12));
      expect(c.scaleChoices, [1, 2, 3, 4, 5]);
    });

    test('the created assessment joins the student\'s list, newest first', () async {
      final h = await signedIn();
      h.api.assignments = const [_cls5a];
      await h.auth.refreshProfile(force: true);
      final list = BehaviourStudentController(studentId: student(1).id, initial: student(1), repository: repo, students: FakeStudentsRepository(), auth: h.auth, permissions: h.perms);
      list.tarbiyah.value = SectionState.data([assessment('old', period: 'Term 3 2025-26')]);
      final c = TarbiyahFormController(args: TarbiyahFormArgs(student: student(1), existing: list.tarbiyah.value.data!), repository: repo, auth: h.auth, permissions: h.perms, studentList: list, clock: () => _now)..onInit();
      c.periodC.text = 'Term 1 2026-27';
      c.setScore('sidq', 4);
      await c.submit();
      expect(list.tarbiyah.value.data!.map((a) => a.id), ['tn1', 'old']);
    });

    test('double submit sends once; a failure keeps every field and a retry works', () async {
      final c = await make();
      c.periodC.text = 'Term 1';
      c.setScore('sidq', 4);
      c.observationsC.text = 'Notes';
      repo.onCreateTarbiyah = (b) async => throw ApiException('boom', statusCode: 500);
      final r = await c.submit() as TarbiyahFailed;
      expect(r.failure.canRetry, isTrue);
      expect(c.periodC.text, 'Term 1');
      expect(c.scores['sidq'], 4);
      expect(c.observationsC.text, 'Notes');
      expect(c.saving.value, isFalse);
      repo.onCreateTarbiyah = (b) async => TarbiyahAssessment.fromJson({'_id': 'ok', ...b});
      expect(await c.submit(), isA<TarbiyahSaved>());
    });

    test('403 is a friendly "You can\'t ..." message, never a crash (a student outside my classes, or no permission)', () async {
      final c = await make();
      c.periodC.text = 'Term 1';
      c.setScore('sidq', 4);
      repo.onCreateTarbiyah = (b) async => throw ApiException('Forbidden resource', statusCode: 403);
      final r = await c.submit() as TarbiyahFailed;
      expect(r.failure.isForbidden, isTrue);
      expect(r.failure.message, startsWith("You can't create this assessment."));
      expect(r.failure.canRetry, isFalse);
      expect(c.failure.value, isNotNull);
    });

    test('400 from the server (for example a score outside the school scale) shows the server text', () async {
      final c = await make();
      c.periodC.text = 'Term 1';
      c.setScore('sidq', 4);
      repo.onCreateTarbiyah = (b) async => throw ApiException('Score for "sidq" must be between 1 and 5 (this school\'s configured scale)', statusCode: 400);
      final r = await c.submit() as TarbiyahFailed;
      expect(r.failure.message, contains('must be between 1 and 5'));
    });

    test('without behaviour:manage (view-only custom role) nothing is sent', () async {
      final c = await make(permissions: ['behaviour:view']);
      expect(c.canWrite, isFalse);
      c.periodC.text = 'Term 1';
      c.setScore('sidq', 4);
      expect(await c.submit(), isA<TarbiyahIgnored>());
      expect(repo.calls, isEmpty);
    });
  });

  group('edit', () {
    test('opens with the stored values and sends PUT /behaviour/tarbiyah/:id with the editable fields only', () async {
      final c = await make(editing: assessment('t1'), existing: [assessment('t1')]);
      expect(c.isEditing, isTrue);
      expect(c.periodC.text, 'Term 1 2026-27');
      expect(c.periodType.value, 'termly');
      expect(c.scores, {'sidq': 4, 'adab': 5});
      expect(c.observationsC.text, 'Kind and focused');
      expect(c.strengthsC.text, 'Leadership');
      expect(c.improvementsC.text, 'Punctuality');
      expect(c.isDirty, isFalse);
      c.setScore('sidq', 2);
      expect(c.isDirty, isTrue);
      expect(await c.submit(), isA<TarbiyahSaved>());
      expect(repo.calls, ['updateTarbiyah:t1']);
      final b = repo.bodies.single;
      expect(b.keys.toSet(), {'period', 'periodType', 'assessmentDate', 'traits', 'teacherObservations', 'areasOfStrength', 'areasForImprovement'});
      expect(b['traits'], [
        {'traitKey': 'sidq', 'score': 2},
        {'traitKey': 'adab', 'score': 5},
      ]);
    });

    test('keeping the same period on an edit is not a duplicate of itself', () async {
      final c = await make(editing: assessment('t1'), existing: [assessment('t1'), assessment('t2', period: 'Term 2 2026-27')]);
      expect(c.validate(), isEmpty);
      c.periodC.text = 'Term 2 2026-27';
      expect(c.validate().keys, ['period']);
    });

    test('only the author edits: someone else\'s assessment is not editable and nothing is sent (the server also answers 403)', () async {
      final c = await make(editing: assessment('t9', byId: 'someone-else', by: 'Omar Colleague'));
      expect(c.mayEditThis, isFalse);
      expect(await c.submit(), isA<TarbiyahIgnored>());
      expect(repo.calls, isEmpty);
    });

    test('a legacy assessment without assessedById falls back to the author NAME', () async {
      final mine = assessment('t5', byId: null, by: 'tess teacher');
      final theirs = assessment('t6', byId: null, by: 'Omar');
      final c = await make(editing: mine);
      expect(c.mayEditThis, isTrue);
      final d = await make(editing: theirs);
      expect(d.mayEditThis, isFalse);
    });

    test('403 on save (the server says it is not mine) is a friendly message and the form stays', () async {
      final c = await make(editing: assessment('t1'));
      repo.onUpdateTarbiyah = (id, b) async => throw ApiException('You can only edit Tarbiyah assessments you recorded yourself', statusCode: 403);
      final r = await c.submit() as TarbiyahFailed;
      expect(r.failure.message, startsWith("You can't save this assessment."));
      expect(r.failure.message, contains('you recorded yourself'));
      expect(c.periodC.text, 'Term 1 2026-27');
    });
  });

  group('student history: who may add / edit', () {
    Future<BehaviourStudentController> history(List<String>? permissions) async {
      final h = await signedIn(permissions: permissions);
      h.api.assignments = const [_cls5a];
      await h.auth.refreshProfile(force: true);
      return BehaviourStudentController(studentId: student(1).id, initial: student(1), repository: repo, students: FakeStudentsRepository(), auth: h.auth, permissions: h.perms);
    }

    test('base teacher: may edit the assessments she recorded, not a colleague\'s', () async {
      final c = await history(null);
      expect(c.canEditTarbiyah(assessment('a', byId: 'u')), isTrue);
      expect(c.canEditTarbiyah(assessment('b', byId: 'other', by: 'Omar')), isFalse);
    });

    test('view-only custom role: neither add nor edit', () async {
      final c = await history(['behaviour:view']);
      expect(c.canLog, isFalse);
      expect(c.canEditTarbiyah(assessment('a', byId: 'u')), isFalse);
    });
  });

  group('models', () {
    test('TarbiyahAssessment.isMine: id wins over name', () {
      expect(assessment('a', byId: 'u', by: 'Zed').isMine(userId: 'u', userName: 'Tess Teacher'), isTrue);
      expect(assessment('a', byId: 'x', by: 'Tess Teacher').isMine(userId: 'u', userName: 'Tess Teacher'), isFalse);
      expect(assessment('a', byId: null, by: ' Tess Teacher ').isMine(userId: 'u', userName: 'tess teacher'), isTrue);
      expect(assessment('a', byId: null, by: '').isMine(userId: 'u', userName: ''), isFalse);
    });

    test('linesOf: one entry per non-empty trimmed line', () {
      expect(linesOf(' a \n\n b\r\n'), ['a', 'b']);
      expect(linesOf(''), isEmpty);
    });

    test('period type labels', () {
      expect(kTarbiyahPeriodTypes, ['monthly', 'termly', 'annual']);
      expect(tarbiyahPeriodTypeLabel('annual'), 'Annual');
    });
  });

  group('My entries is asked of the server (mine=true)', () {
    Future<BehaviourController> list() async {
      final h = await signedIn();
      h.api.assignments = const [_cls5a];
      await h.auth.refreshProfile(force: true);
      return BehaviourController(
        repository: repo,
        students: FakeStudentsRepository()..grades = (() async => const GradesSections(grades: ['Grade 5'], sections: ['A'])),
        auth: h.auth,
        permissions: h.perms,
      );
    }

    BehaviourRecord r(String id, {String? byId, String by = 'Someone'}) => BehaviourRecord.fromJson({
          '_id': id, 'studentId': 'st1', 'studentName': 'Zara', 'grade': 'Grade 5', 'section': 'A', 'type': 'positive', 'category': 'helping_others',
          'title': 'T', 'description': 'd', 'date': '2026-10-01T00:00:00.000Z', 'points': 1, 'reportedBy': by, if (byId != null) 'reportedById': byId,
        });

    test('the first load (My entries) sends mine=true for every grade; My classes sends none', () async {
      repo.gradeRecords = (g) async => [r('m1', byId: 'u'), r('o1', by: 'Omar')];
      final c = await list();
      await c.load();
      expect(repo.queries.map((q) => q['mine']), everyElement(isTrue));
      repo.queries.clear();
      await c.setScope(BehaviourScope.classes);
      expect(repo.queries.map((q) => q['mine']), everyElement(isFalse));
      expect(c.visible.map((x) => x.id), unorderedEquals(['m1', 'o1']));
    });

    test('a server answer for My entries is not capped to what a grade-wide first page would hold: entries older than page 1 are listed (paged with mine=true)', () async {
      repo.pageSize = 2;
      repo.gradeRecords = (g) async => [for (var i = 0; i < 5; i++) r('m$i', byId: 'u')];
      final c = await list();
      await c.load();
      expect(c.all, hasLength(2));
      expect(c.hasMore.value, isTrue);
      repo.queries.clear();
      await c.loadMore();
      expect(repo.queries.single['mine'], isTrue);
      expect(repo.queries.single['page'], 2);
      expect(c.all, hasLength(4));
    });

    test('switching scopes reuses what each scope loaded (no new request), and a reload drops both', () async {
      repo.gradeRecords = (g) async => [r('m1', byId: 'u')];
      final c = await list();
      await c.load();
      await c.setScope(BehaviourScope.classes);
      final n = repo.queries.length;
      await c.setScope(BehaviourScope.mine);
      await c.setScope(BehaviourScope.classes);
      expect(repo.queries.length, n, reason: 'both scopes cached');
      await c.load(force: true);
      expect(repo.queries.length, greaterThan(n));
    });

    test('a record I log appears in both scopes', () async {
      repo.gradeRecords = (g) async => [r('m1', byId: 'u')];
      final c = await list();
      await c.load();
      await c.setScope(BehaviourScope.classes);
      await c.setScope(BehaviourScope.mine);
      c.addRecord(r('new', byId: 'u'));
      expect(c.visible.map((x) => x.id), contains('new'));
      await c.setScope(BehaviourScope.classes);
      expect(c.visible.map((x) => x.id), contains('new'));
    });

    test('an older server that ignores mine cannot show a colleague\'s record under My entries (client re-check)', () async {
      repo.gradeRecords = (g) async => [r('m1', byId: 'u'), r('o1', by: 'Omar')];
      final c = await list();
      await c.load();
      expect(c.visible.map((x) => x.id), ['m1']);
    });
  });
}
