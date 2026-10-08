// ignore_for_file: invalid_use_of_protected_member
import 'package:eldermin_teacher_app/app/modules/assessments/controllers/assessments_controller.dart';
import 'package:eldermin_teacher_app/app/modules/assessments/controllers/quiz_controllers.dart';
import 'package:eldermin_teacher_app/app/modules/assessments/controllers/report_remarks_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/models/section_state.dart';
import 'package:eldermin_teacher_app/core/models/assessments/assessment_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/services/assessment_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_assessment_repositories.dart';

const maths5a = {'gradeLevel': 'Grade 5', 'sectionName': 'A', 'subjectName': 'Mathematics'};
const sci6b = {'gradeLevel': 'Grade 6', 'sectionName': 'B', 'subjectName': 'Science'};

QuizAttempt attempt(String id, {String status = 'submitted', String subject = 'Mathematics', String section = 'A', String grade = 'Grade 5', List<double?> awarded = const [null, null], double total = 10, double auto = 2, double? obtained}) => QuizAttempt.fromJson({
      '_id': id,
      'studentName': 'Student $id',
      'subject': subject,
      'grade': grade,
      'section': section,
      'totalMarks': total,
      'autoGradedMarks': auto,
      'obtainedMarks': obtained,
      'status': status,
      'submittedAt': '2026-10-03T08:30:00.000Z',
      'answers': [
        {'questionId': 'q1', 'selectedOptionIndex': 0, 'needsManualGrading': false, 'isCorrect': true, 'marksAwarded': auto, 'question': {'_id': 'q1', 'type': 'mcq', 'questionText': 'MCQ', 'marks': 2, 'options': [{'text': 'a', 'isCorrect': true}]}},
        {'questionId': 'q2', 'textAnswer': 'short answer', 'needsManualGrading': true, 'marksAwarded': awarded[0], 'question': {'_id': 'q2', 'type': 'short', 'questionText': 'Explain', 'marks': 4, 'correctAnswer': 'model'}},
        {'questionId': 'q3', 'textAnswer': 'long answer', 'needsManualGrading': true, 'marksAwarded': awarded[1], 'question': {'_id': 'q3', 'type': 'long', 'questionText': 'Show', 'marks': 4}},
      ],
    });

ReportCard card(String id, {String section = 'A', bool published = false, int pos = 1, String remarks = ''}) =>
    ReportCard.fromJson({'_id': id, 'assessmentId': 'a2', 'studentName': 'S$id', 'grade': 'Grade 5', 'section': section, 'published': published, 'classPosition': pos, 'classTeacherRemarks': remarks, 'overallPercentage': 70});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeAssessmentRepository repo;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakeAssessmentRepository();
  });
  tearDown(Get.reset);

  Future<({AssessmentsController list, dynamic h})> makeList({List<Map<String, Object?>> assignments = const [maths5a, sci6b], bool classTeacher = false, List<String>? permissions}) async {
    final h = await signedIn(classTeacher: classTeacher, permissions: permissions);
    h.api.assignments = assignments;
    await h.auth.refreshProfile(force: true);
    return (list: AssessmentsController(repository: repo, auth: h.auth, permissions: h.perms), h: h);
  }

  group('AssessmentsController', () {
    test('lists only MY assessments (class + subject), newest first, drafts and other grades dropped', () async {
      repo.onList = () async => AllPages(fixtureAssessments());
      final c = (await makeList()).list;
      await c.load();
      final titles = c.items.map((a) => a.title.split(' (').first).toList();
      expect(titles.toSet(), {'Final Exam', 'Unit Test 1 - Fractions', 'Class Test - Plants', 'Online Quiz - Fractions', 'Mid-Term Exam', 'Term 1 Result', 'Cancelled Quiz'});
      final dates = c.items.map((a) => a.startDate!).toList();
      expect(dates, [...dates]..sort((a, b) => b.compareTo(a)));
      expect(c.subjectsOf(c.items.firstWhere((a) => a.title.startsWith('Unit Test 1'))), ['Mathematics']);
    });

    test('filters and counts: marks open / upcoming / published / all', () async {
      repo.onList = () async => AllPages(fixtureAssessments());
      final c = (await makeList()).list;
      await c.load();
      expect(c.countFor(AssessmentFilter.open), 4); // unit test, mid-term (completed), plants, online quiz
      expect(c.countFor(AssessmentFilter.upcoming), 1);
      expect(c.countFor(AssessmentFilter.published), 1);
      expect(c.countFor(AssessmentFilter.all), 7);
      expect(c.filtered.every((a) => a.status == 'ongoing' || a.status == 'completed'), isTrue);
      c.setFilter(AssessmentFilter.published);
      expect(c.filtered.single.title, startsWith('Term 1 Result'));
    });

    test('empty / error / 403 / no permission / truncated notice / retry', () async {
      final h = await makeList();
      var c = h.list;
      repo.onList = () async => const AllPages([]);
      await c.load();
      expect(c.state.value.status, SectionStatus.empty);
      repo.onList = () async => throw ApiException('Forbidden resource', statusCode: 403);
      await c.load(force: true);
      expect(c.state.value.status, SectionStatus.forbidden);
      var fail = true;
      repo.onList = () async => fail ? throw ApiException('x', statusCode: 500) : AllPages(fixtureAssessments(), truncated: true);
      await c.load(force: true);
      expect(c.state.value.status, SectionStatus.error);
      fail = false;
      await c.load(force: true);
      expect(c.state.value.status, SectionStatus.data);
      expect(c.truncated.value, isTrue);
      Get.reset();
      Get.testMode = true;
      repo = FakeAssessmentRepository();
      c = (await makeList(permissions: ['teaching:view'])).list;
      await c.load();
      expect(c.state.value.status, SectionStatus.forbidden);
      expect(repo.calls, isEmpty);
    });

    test('class teacher: sees her class assessments, can write remarks only when report cards exist', () async {
      repo.onList = () async => AllPages([asm('a1'), asm('a2', cards: true, status: 'completed', subjects: const [('Science', 100, 40)])]);
      final c = (await makeList(assignments: const [], classTeacher: true)).list;
      await c.load();
      expect(c.items, hasLength(2));
      expect(c.isClassTeacher, isTrue);
      expect(c.subjectsOf(c.items.first), isEmpty);
      expect(c.canWriteRemarks(c.byId('a2')!), isTrue);
      expect(c.canWriteRemarks(c.byId('a1')!), isFalse);
      final s = c.byId('a1')!.subjects.first;
      expect(c.accessFor(c.byId('a1')!, s), MarksAccess.notMySubject);
    });

    test('a teacher who is not a class teacher never gets remarks', () async {
      repo.onList = () async => AllPages([asm('a2', cards: true)]);
      final c = (await makeList()).list;
      await c.load();
      expect(c.canWriteRemarks(c.items.single), isFalse);
    });

    test('detail: from the list cache; cold link loads the list first; an assessment that is not mine is refused', () async {
      repo.onList = () async => AllPages([asm('a1')]);
      repo.onOne = (id) async => id == 'zz' ? asm('zz', grade: 'Grade 9', section: 'Z') : asm(id);
      final c = (await makeList()).list;
      final d = AssessmentDetailController(id: 'a1', list: c, repository: repo);
      await d.load();
      expect(d.state.value.data!.id, 'a1');
      expect(repo.calls.where((x) => x.startsWith('one:')), isEmpty);
      final other = AssessmentDetailController(id: 'zz', list: c, repository: repo);
      await other.load();
      expect(other.state.value.status, SectionStatus.error);
      expect(other.state.value.message, contains("isn't one of yours"));
      repo.onOne = (_) async => throw ApiException('Assessment not found', statusCode: 404);
      final gone = AssessmentDetailController(id: 'nope', list: c, repository: repo);
      await gone.load();
      expect(gone.state.value.status, SectionStatus.unavailable);
    });
  });

  group('ReportRemarksController', () {
    Future<ReportRemarksController> makeRemarks({bool classTeacher = true, String? initial, List<ReportCard>? cards}) async {
      final h = await makeList(assignments: const [], classTeacher: classTeacher);
      repo.onList = () async => AllPages([asm('a2', cards: true, status: 'completed', section: null), asm('a1', cards: false), asm('a3', cards: true, status: 'result_published', published: true)]);
      repo.onCards = (id) async => AllPages(cards ?? [card('c2', pos: 2), card('c1', pos: 1), card('cb', section: 'B'), card('cp', published: true, pos: 3)]);
      return ReportRemarksController(repository: repo, list: h.list, initialAssessmentId: initial);
    }

    test('only assessments with generated report cards of MY class-teacher class; cards of other sections are dropped; sorted by position', () async {
      final c = await makeRemarks();
      await c.load();
      expect(c.candidates.map((a) => a.id), ['a2', 'a3']);
      expect(c.selectedId.value, 'a2');
      expect(c.cards.map((x) => x.id), ['c1', 'c2', 'cp']);
      expect(repo.calls, contains('cards:a2'));
    });

    test('initial assessment id is honoured; switching reloads', () async {
      final c = await makeRemarks(initial: 'a3');
      await c.load();
      expect(c.selectedId.value, 'a3');
      await c.select('a2');
      expect(repo.calls.where((x) => x.startsWith('cards:')), ['cards:a3', 'cards:a2']);
    });

    test('a teacher who is not a class teacher gets the empty state and no cards request', () async {
      final c = await makeRemarks(classTeacher: false);
      await c.load();
      expect(c.state.value.status, SectionStatus.empty);
      expect(c.candidates, isEmpty);
      expect(repo.calls.where((x) => x.startsWith('cards:')), isEmpty);
    });

    test('save sends ONLY the trimmed class-teacher text; the card is replaced; published cards are read-only; one request at a time', () async {
      final c = await makeRemarks();
      await c.load();
      final c1 = c.cards.firstWhere((x) => x.id == 'c1');
      final r = await c.saveRemarks(c1, '  Very good progress  ');
      expect(r, isA<RemarksSaved>());
      expect(repo.remarks.single, (id: 'c1', text: 'Very good progress'));
      expect(c.cards.firstWhere((x) => x.id == 'c1').classTeacherRemarks, 'Very good progress');
      final published = c.cards.firstWhere((x) => x.id == 'cp');
      expect(c.canEdit(published), isFalse);
      expect(await c.saveRemarks(published, 'x'), isA<RemarksIgnored>());
      expect(repo.remarks, hasLength(1));
    });

    test('validation: more than 500 characters is refused before any request', () async {
      final c = await makeRemarks();
      await c.load();
      final r = await c.saveRemarks(c.cards.first, 'x' * 501);
      expect(r, isA<RemarksInvalid>());
      expect(repo.remarks, isEmpty);
      expect(await c.saveRemarks(c.cards.first, 'x' * 500), isA<RemarksSaved>());
    });

    test('failures keep the text for retry: 403 message, offline, and the empty-200 not-found', () async {
      final c = await makeRemarks();
      await c.load();
      repo.onRemarks = (_, __) async => throw ApiException('Forbidden resource', statusCode: 403);
      var r = await c.saveRemarks(c.cards.first, 'hi');
      expect(r, isA<RemarksFailed>());
      expect((r as RemarksFailed).failure.message, contains("You can't save these remarks"));
      repo.onRemarks = (_, __) async => throw ApiException('No internet connection.');
      r = await c.saveRemarks(c.cards.first, 'hi') as RemarksFailed;
      expect(r.failure.message, contains('Your text is kept'));
      repo.onRemarks = (_, __) async => throw ApiException('This report card was not found on the server.', statusCode: 404);
      r = await c.saveRemarks(c.cards.first, 'hi') as RemarksFailed;
      expect(r.failure.kind.name, 'notFound');
      expect(c.saving, isEmpty);
    });

    test('a blank remark clears the text (sent as an empty string)', () async {
      final c = await makeRemarks(cards: [card('c1', remarks: 'old')]);
      await c.load();
      await c.saveRemarks(c.cards.single, '   ');
      expect(repo.remarks.single.text, '');
    });

    test('403 on the cards list = forbidden', () async {
      final c = await makeRemarks();
      repo.onCards = (_) async => throw ApiException('Forbidden resource', statusCode: 403);
      await c.load();
      expect(c.state.value.status, SectionStatus.forbidden);
    });
  });

  group('Quiz grading', () {
    Future<QuizAttemptsController> makeQuiz() async {
      final h = await makeList();
      return QuizAttemptsController(repository: repo, auth: h.h.auth, permissions: h.h.perms);
    }

    test('list: only attempts of MY class and subject waiting for review', () async {
      repo.onPending = () async => [attempt('t1'), attempt('t2', section: 'B'), attempt('t3', subject: 'English'), attempt('t4', grade: 'Grade 7'), attempt('t5', status: 'graded'), attempt('t6', subject: 'Science', grade: 'Grade 6', section: 'B')];
      final c = await makeQuiz();
      await c.load();
      expect(c.items.map((a) => a.id), ['t1', 't6']);
    });

    test('empty / 403 / error', () async {
      final c = await makeQuiz();
      repo.onPending = () async => [];
      await c.load();
      expect(c.state.value.status, SectionStatus.empty);
      repo.onPending = () async => throw ApiException('Forbidden resource', statusCode: 403);
      await c.load(force: true);
      expect(c.state.value.status, SectionStatus.forbidden);
      repo.onPending = () async => throw ApiException('x', statusCode: 500);
      await c.load(force: true);
      expect(c.state.value.status, SectionStatus.error);
    });

    group('visibility rule: class teacher = all subjects of own class; subject teacher = own subjects in classes taught; union', () {
      Future<QuizAttemptsController> quizFor({bool classTeacher = false, List<Map<String, Object?>> assignments = const [maths5a, sci6b]}) async {
        final r = await makeList(classTeacher: classTeacher, assignments: assignments);
        return QuizAttemptsController(repository: repo, auth: r.h.auth, permissions: r.h.perms);
      }

      final all = [
        attempt('m5a'), // Maths, 5-A
        attempt('e5a', subject: 'English'), // English, 5-A
        attempt('s5a', subject: 'Science'), // Science, 5-A
        attempt('m5b', section: 'B'), // Maths, 5-B
        attempt('e6b', subject: 'English', grade: 'Grade 6', section: 'B'),
        attempt('s6b', subject: 'Science', grade: 'Grade 6', section: 'B'),
        attempt('m7c', grade: 'Grade 7', section: 'C'),
      ];

      test('class teacher of 5-A (teaches nothing there): ALL subjects of 5-A, nothing else', () async {
        repo.onPending = () async => all;
        final c = await quizFor(classTeacher: true, assignments: const []);
        await c.load();
        expect(c.items.map((a) => a.id).toSet(), {'m5a', 'e5a', 's5a'});
        expect(c.subjects, ['English', 'Mathematics', 'Science']);
      });

      test('subject teacher: only their subjects in the classes they teach', () async {
        repo.onPending = () async => all;
        final c = await quizFor(); // Maths in 5-A, Science in 6-B, class teacher of nothing
        await c.load();
        expect(c.items.map((a) => a.id).toSet(), {'m5a', 's6b'});
        expect(c.subjects, ['Mathematics', 'Science']);
      });

      test('UNION: class teacher of 5-A who also teaches English in 6-B = all of 5-A + English in 6-B', () async {
        repo.onPending = () async => all;
        final c = await quizFor(classTeacher: true, assignments: const [
          {'gradeLevel': 'Grade 6', 'sectionName': 'B', 'subjectName': 'English'}
        ]);
        await c.load();
        expect(c.items.map((a) => a.id).toSet(), {'m5a', 'e5a', 's5a', 'e6b'});
      });

      test('class teacher who also teaches in their own class: still every subject there; other classes only their subject', () async {
        repo.onPending = () async => all;
        final c = await quizFor(classTeacher: true, assignments: const [maths5a, sci6b]);
        await c.load();
        expect(c.items.map((a) => a.id).toSet(), {'m5a', 'e5a', 's5a', 's6b'});
      });

      test('tolerant matching: "5"/"a" spellings and a subject spelled in another case', () async {
        repo.onPending = () async => [attempt('x1', grade: '5', section: 'a', subject: 'MATHEMATICS'), attempt('x2', grade: 'Class 6', section: 'Section B', subject: 'science'), attempt('x3', grade: '5', section: 'a', subject: 'English')];
        final c = await quizFor();
        await c.load();
        expect(c.items.map((a) => a.id).toSet(), {'x1', 'x2'});
      });

      test('a teacher with NEITHER role: empty, hasNoScope explains why', () async {
        repo.onPending = () async => all;
        final c = await quizFor(assignments: const []);
        await c.load();
        expect(c.state.value.status, SectionStatus.empty);
        expect(c.hasNoScope, isTrue);
        expect((await quizFor()).hasNoScope, isFalse);
      });

      test('subject chips: All + one per subject present; filter narrows; a vanished subject falls back to All', () async {
        repo.onPending = () async => all;
        final c = await quizFor(classTeacher: true, assignments: const []);
        await c.load();
        expect(c.subjectFilter.value, isNull);
        expect(c.visible, hasLength(3));
        c.setSubjectFilter('English');
        expect(c.visible.map((a) => a.id), ['e5a']);
        expect(c.countFor('Mathematics'), 1);
        expect(c.countFor(null), 3);
        c.remove('e5a'); // the filtered subject has no attempt left
        expect(c.subjectFilter.value, isNull);
        expect(c.visible.map((a) => a.id).toSet(), {'m5a', 's5a'});
      });

      test('direct open by id follows the same rule: class teacher may open another subject of her class, not another class', () async {
        repo.onPending = () async => all;
        final c = await quizFor(classTeacher: true, assignments: const []);
        await c.load();
        repo.onAttempt = (id) async => attempt(id, subject: 'English');
        final ok = QuizAttemptDetailController(id: 'e5a', list: c, repository: repo);
        await ok.load();
        expect(ok.state.value.status, SectionStatus.data);
        repo.onAttempt = (id) async => attempt(id, subject: 'English', section: 'B');
        final no = QuizAttemptDetailController(id: 'e5b', list: c, repository: repo);
        await no.load();
        expect(no.state.value.status, SectionStatus.error);
        expect(no.state.value.message, contains("isn't from your class or one of your subjects"));
        final subjOnly = await quizFor();
        repo.onAttempt = (id) async => attempt(id, subject: 'English');
        final no2 = QuizAttemptDetailController(id: 'e5a', list: subjOnly, repository: repo);
        await no2.load();
        expect(no2.state.value.status, SectionStatus.error);
      });
    });

    Future<({QuizAttemptDetailController d, QuizAttemptsController list})> openDetail({QuizAttempt? a}) async {
      final list = await makeQuiz();
      repo.onPending = () async => [attempt('t1')];
      await list.load();
      repo.onAttempt = (id) async => a ?? attempt(id);
      final d = QuizAttemptDetailController(id: a?.id ?? 't1', list: list, repository: repo);
      await d.load();
      return (d: d, list: list);
    }

    test('detail: written answers are inputs, bounded by each question\'s marks', () async {
      final d = (await openDetail()).d;
      expect(d.inputs.keys, ['q2', 'q3']);
      expect(d.editable, isTrue);
      for (final (text, ok) in [('0', true), ('4', true), ('3.5', true), ('4.01', false), ('5', false), ('-1', false), ('x', false), ('', true)]) {
        d.setMark('q2', text);
        expect(d.errorFor('q2') == null, ok, reason: text);
      }
      d.setMark('q2', '9');
      expect(d.errorFor('q2'), "Can't be more than 4.");
      expect(d.hasErrors, isTrue);
    });

    test('a question without details cannot be graded; an invalid submit sends nothing', () async {
      final a = QuizAttempt.fromJson({'_id': 't1', 'grade': 'Grade 5', 'section': 'A', 'subject': 'Mathematics', 'status': 'submitted', 'answers': [{'questionId': 'q9', 'needsManualGrading': true}]});
      final d = (await openDetail(a: a)).d;
      d.setMark('q9', '1');
      expect(d.errorFor('q9'), contains('missing'));
      expect(await d.submit(), isA<GradeInvalid>());
      expect(repo.grades, isEmpty);
    });

    test('partial grading: sends only typed marks, the attempt stays pending and in the list', () async {
      final r = await openDetail();
      repo.onGrade = (id, g) async => attempt(id, awarded: [3, null]);
      r.d.setMark('q2', '3');
      expect(r.d.complete, isFalse);
      expect(r.d.previewTotal, isNull);
      final res = await r.d.submit();
      expect(res, isA<GradeSaved>());
      expect((res as GradeSaved).complete, isFalse);
      expect(repo.grades.single.grades, [(questionId: 'q2', marks: 3.0)]);
      expect(r.list.items.map((a) => a.id), ['t1']);
      expect(r.d.inputs['q2'], '3');
      expect(r.d.editable, isTrue);
    });

    test('complete grading: preview total = auto marks + typed marks; graded attempt leaves the queue and becomes read-only', () async {
      final r = await openDetail();
      r.d.setMark('q2', '3');
      r.d.setMark('q3', '2.5');
      expect(r.d.complete, isTrue);
      expect(r.d.previewTotal, 7.5);
      repo.onGrade = (id, g) async => attempt(id, status: 'graded', awarded: [3, 2.5], obtained: 7.5);
      final res = await r.d.submit();
      expect((res as GradeSaved).complete, isTrue);
      expect(repo.grades.single.grades, [(questionId: 'q2', marks: 3.0), (questionId: 'q3', marks: 2.5)]);
      expect(r.list.state.value.status, SectionStatus.empty);
      expect(r.d.editable, isFalse);
      r.d.setMark('q2', '1');
      expect(r.d.inputs['q2'], '3');
      expect(await r.d.submit(), isA<GradeIgnored>());
    });

    test('an already graded attempt opened by link is read-only (a re-grade would overwrite the mark entry)', () async {
      final d = (await openDetail(a: attempt('t1', status: 'graded', awarded: [3, 2], obtained: 7))).d;
      expect(d.editable, isFalse);
      expect(await d.submit(), isA<GradeIgnored>());
      expect(repo.grades, isEmpty);
    });

    test('failure keeps every typed mark; retry resends; double submit is ignored', () async {
      final r = await openDetail();
      r.d.setMark('q2', '3');
      var fail = true;
      final gate = <Future<QuizAttempt>>[];
      repo.onGrade = (id, g) {
        if (fail) return Future.error(ApiException('Internal server error', statusCode: 500));
        return Future.value(attempt(id, awarded: [3, null]));
      };
      final res = await r.d.submit();
      expect(res, isA<GradeFailed>());
      expect(r.d.failure.value!.message, contains("couldn't save these marks"));
      expect(r.d.inputs['q2'], '3');
      expect(r.d.saving.value, isFalse);
      fail = false;
      final first = r.d.submit();
      expect(await r.d.submit(), isA<GradeIgnored>());
      expect(await first, isA<GradeSaved>());
      expect(repo.grades, hasLength(2));
      expect(gate, isEmpty);
    });

    test('nothing typed: invalid; a scope mismatch (someone else\'s class) is refused; 404 = unavailable', () async {
      final r = await openDetail();
      expect(await r.d.submit(), isA<GradeInvalid>());
      repo.onAttempt = (id) async => attempt(id, section: 'B');
      final other = QuizAttemptDetailController(id: 'x', list: r.list, repository: repo);
      await other.load();
      expect(other.state.value.status, SectionStatus.error);
      repo.onAttempt = (id) async => throw ApiException('Quiz attempt not found', statusCode: 404);
      final gone = QuizAttemptDetailController(id: 'y', list: r.list, repository: repo);
      await gone.load();
      expect(gone.state.value.status, SectionStatus.unavailable);
    });
  });
}
