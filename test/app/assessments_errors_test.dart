// ignore_for_file: invalid_use_of_protected_member
import 'package:dio/dio.dart';
import 'package:eldermin_teacher_app/app/common/action_failure.dart';
import 'package:eldermin_teacher_app/app/modules/assessments/controllers/assessments_controller.dart';
import 'package:eldermin_teacher_app/app/modules/assessments/controllers/marks_entry_controller.dart';
import 'package:eldermin_teacher_app/app/modules/assessments/controllers/quiz_controllers.dart';
import 'package:eldermin_teacher_app/app/modules/assessments/controllers/report_remarks_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/models/section_state.dart';
import 'package:eldermin_teacher_app/core/models/assessments/assessment_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/network/dio_exception_handler.dart';
import 'package:eldermin_teacher_app/core/services/assessment_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import '../support/auth_harness.dart';
import '../support/fake_assessment_repositories.dart';
import '../support/fake_classroom_repositories.dart';

/// The error the backend really sends: `{statusCode, message, timestamp, path}` (filters/sentry.filter.ts:43-48), run through the app's own
/// Dio mapping. The status codes and TEXTS of the hardening errors are copied from the landed backend commits (read from code, not run
/// end to end): 44b0a6e marks/bulk (400 'Marks must be between 0 and T for S. Invalid for N student(s): ...', 409 'Marks for N students
/// are verified and locked: ...'), 7795f1d quiz grading (400 'Invalid marks for N question(s): ...', 409 'This attempt is already
/// graded.', 403), 5b1244d quiz detail 403, 8150ffb remarks (403, 404 'Report card not found'). The app shows the server message verbatim.
ApiException serverError(int status, String message, {String path = '/api/v1/assessments/marks/bulk'}) {
  final ro = RequestOptions(path: path);
  return DioExceptionHandler.handle(DioException(
    requestOptions: ro,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: ro, statusCode: status, data: {'statusCode': status, 'message': message, 'timestamp': '2026-10-06T10:00:00.000Z', 'path': path}),
  ));
}

const maths5a = {'gradeLevel': 'Grade 5', 'sectionName': 'A', 'subjectName': 'Mathematics'};

QuizAttempt attempt(String id, {String status = 'submitted', String subject = 'Mathematics', String section = 'A', String grade = 'Grade 5', List<double?> awarded = const [null, null], double? obtained}) => QuizAttempt.fromJson({
      '_id': id,
      'studentName': 'Student $id',
      'subject': subject,
      'grade': grade,
      'section': section,
      'totalMarks': 10,
      'autoGradedMarks': 2,
      'obtainedMarks': obtained,
      'status': status,
      'submittedAt': '2026-10-03T08:30:00.000Z',
      'answers': [
        {'questionId': 'q1', 'selectedOptionIndex': 0, 'needsManualGrading': false, 'isCorrect': true, 'marksAwarded': 2, 'question': {'_id': 'q1', 'type': 'mcq', 'questionText': 'MCQ', 'marks': 2, 'options': [{'text': 'a', 'isCorrect': true}]}},
        {'questionId': 'q2', 'textAnswer': 'short answer', 'needsManualGrading': true, 'marksAwarded': awarded[0], 'question': {'_id': 'q2', 'type': 'short', 'questionText': 'Explain', 'marks': 4}},
        {'questionId': 'q3', 'textAnswer': 'long answer', 'needsManualGrading': true, 'marksAwarded': awarded[1], 'question': {'_id': 'q3', 'type': 'long', 'questionText': 'Show', 'marks': 4}},
      ],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeAssessmentRepository repo;
  late FakeStudentsRepository students;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakeAssessmentRepository();
    students = FakeStudentsRepository();
    repo.onOne = (id) async => asm('a1');
    students.roster = (cls) async => [for (var i = 1; i <= 5; i++) student(i)];
  });
  tearDown(Get.reset);

  group('ActionFailure mapping of the real error shape', () {
    test('400 / 403 / 404 / 409 show the SERVER message; retry only for offline / 5xx', () {
      final bad = ActionFailure.from(serverError(400, 'Marks must be between 0 and 50 for Mathematics. Invalid for 1 student(s): Ayesha (roll 1): 60'), what: 'save these marks');
      expect((bad.kind, bad.message, bad.canRetry), (ActionFailureKind.validation, 'Marks must be between 0 and 50 for Mathematics. Invalid for 1 student(s): Ayesha (roll 1): 60', false));
      final locked = ActionFailure.from(serverError(409, 'Marks for 1 students are verified and locked: Ayesha (roll 1)'), what: 'save these marks');
      expect((locked.kind, locked.message, locked.canRetry), (ActionFailureKind.conflict, 'Marks for 1 students are verified and locked: Ayesha (roll 1)', false));
      final forbidden = ActionFailure.from(serverError(403, 'Only the class teacher of this class can edit report card remarks.'), what: 'save these remarks');
      expect(forbidden.kind, ActionFailureKind.forbidden);
      expect(forbidden.message, contains('Only the class teacher of this class can edit report card remarks.'));
      expect(forbidden.canRetry, isFalse);
      final gone = ActionFailure.from(serverError(404, 'Report card not found'), what: 'save these remarks');
      expect(gone.kind, ActionFailureKind.notFound);
      expect(gone.message, contains('Report card not found'));
      final boom = ActionFailure.from(serverError(500, 'Internal server error'), what: 'save these marks');
      expect((boom.kind, boom.canRetry), (ActionFailureKind.server, true));
      expect(ActionFailure.from(ApiException('No internet', statusCode: null), what: 'x').canRetry, isTrue);
    });

    test('an array message is joined by the app and an empty 409 text still says something useful', () {
      expect(ActionFailure.from(serverError(409, ''), what: 'save these marks').message, contains('changed on the server'));
    });
  });

  group('marks save errors keep the sheet', () {
    Future<MarksEntryController> make() async {
      final h = await signedIn();
      h.api.assignments = const [maths5a];
      await h.auth.refreshProfile(force: true);
      final c = MarksEntryController(assessmentId: 'a1', subject: 'Mathematics', repository: repo, students: students, auth: h.auth, permissions: h.perms);
      await c.load();
      return c;
    }

    MarkEntryRow row(MarksEntryController c, int i) => c.rows.firstWhere((r) => r.student.id == student(i).id);

    test('400 marks above the total: message shown verbatim, every typed value kept, no auto-retry, nothing locked', () async {
      final c = await make();
      c.setMarks(student(1).id, '40');
      c.setMarks(student(2).id, '30');
      repo.onSave = (_) async => throw serverError(400, 'Marks must be between 0 and 50 for Mathematics. Invalid for 2 student(s): Student 1 (roll 1): 60; Student 2 (roll 2): 70');
      final r = await c.save();
      expect(r, isA<MarksSaveFailed>());
      expect(c.saveFailure.value!.message, 'Marks must be between 0 and 50 for Mathematics. Invalid for 2 student(s): Student 1 (roll 1): 60; Student 2 (roll 2): 70');
      expect(c.saveFailure.value!.canRetry, isFalse);
      expect(row(c, 1).text, '40');
      expect(row(c, 2).text, '30');
      expect(c.hasUnsavedChanges, isTrue);
      expect(c.saving.value, isFalse);
      expect(repo.saves, hasLength(1));
    });

    for (final status in [403, 409]) {
      test('$status "verified and locked": the verified row locks (server value shown), the other typed values stay, message shown', () async {
        final c = await make();
        c.setMarks(student(1).id, '40');
        c.setMarks(student(2).id, '30');
        repo.onSave = (_) async => throw serverError(status, 'Marks for 1 students are verified and locked: Student 1 (roll 1)');
        repo.onMarks = (_, __) async => AllPages([mark(student(1), 25, verified: true)]); // verified meanwhile by the coordinator
        final r = await c.save();
        expect(r, isA<MarksSaveFailed>());
        expect(c.saveFailure.value!.message, contains('verified and locked'));
        expect(c.saveFailure.value!.canRetry, isFalse);
        expect(row(c, 1).locked, isTrue);
        expect(row(c, 1).text, '25'); // the server's value, not the refused one
        expect(row(c, 2).text, '30');
        expect(row(c, 2).locked, isFalse);
        expect(c.dirtyCount, 1);
        // saving again sends only the unlocked row
        repo.onSave = null;
        expect(await c.save(), isA<MarksSaved>());
        expect(repo.saves.last.marks.map((m) => m['studentId']), [student(2).id]);
      });
    }

    test('500 keeps state and DOES offer retry; the same body is resent', () async {
      final c = await make();
      c.setMarks(student(1).id, '40');
      repo.onSave = (_) async => throw serverError(500, 'Internal server error');
      await c.save();
      expect(c.saveFailure.value!.canRetry, isTrue);
      repo.onSave = null;
      expect(await c.save(), isA<MarksSaved>());
      expect(repo.saves, hasLength(2));
      expect(repo.saves.first.marks, repo.saves.last.marks);
    });
  });

  group('quiz grading errors', () {
    Future<({QuizAttemptDetailController d, QuizAttemptsController list})> open() async {
      final h = await signedIn();
      h.api.assignments = const [maths5a];
      await h.auth.refreshProfile(force: true);
      final list = QuizAttemptsController(repository: repo, auth: h.auth, permissions: h.perms);
      repo.onPending = () async => [attempt('t1')];
      await list.load();
      repo.onAttempt = (id) async => attempt(id);
      final d = QuizAttemptDetailController(id: 't1', list: list, repository: repo);
      await d.load();
      return (d: d, list: list);
    }

    test('400 bounds: server message shown, typed marks kept, no retry button', () async {
      final r = await open();
      r.d.setMark('q2', '3');
      repo.onGrade = (_, __) async => throw serverError(400, 'Invalid marks for 1 question(s): q2: 9 (allowed 0..4)', path: '/api/v1/assessments/quiz-attempts/t1/grade');
      expect(await r.d.submit(), isA<GradeFailed>());
      expect(r.d.failure.value!.message, 'Invalid marks for 1 question(s): q2: 9 (allowed 0..4)');
      expect(r.d.failure.value!.canRetry, isFalse);
      expect(r.d.inputs['q2'], '3');
      expect(r.d.editable, isTrue);
      expect(r.list.items.map((a) => a.id), ['t1']);
    });

    test('409 already graded: the attempt is re-read, becomes read-only, leaves the queue, the message stays', () async {
      final r = await open();
      r.d.setMark('q2', '3');
      repo.onGrade = (_, __) async => throw serverError(409, 'This attempt is already graded.');
      repo.onAttempt = (id) async => attempt(id, status: 'graded', awarded: [2, 2], obtained: 8);
      expect(await r.d.submit(), isA<GradeFailed>());
      expect(r.d.failure.value!.message, contains('already graded'));
      expect(r.d.editable, isFalse);
      expect(r.d.attempt!.isGraded, isTrue);
      expect(r.list.state.value.status, SectionStatus.empty);
    });

    test('403 on the grade call (not my class): server message shown, no retry, typed marks kept', () async {
      final r = await open();
      r.d.setMark('q2', '3');
      repo.onGrade = (_, __) async => throw serverError(403, 'You can only grade quiz attempts for classes you teach.');
      expect(await r.d.submit(), isA<GradeFailed>());
      expect(r.d.failure.value!.message, contains('You can only grade quiz attempts for classes you teach.'));
      expect(r.d.failure.value!.canRetry, isFalse);
      expect(r.d.inputs['q2'], '3');
    });

    test('403 when opening an attempt of a class that is not mine: no-access state, nothing shown', () async {
      final r = await open();
      repo.onAttempt = (_) async => throw serverError(403, 'You can only review quiz attempts for classes you teach.');
      final d = QuizAttemptDetailController(id: 'foreign', list: r.list, repository: repo);
      await d.load();
      expect(d.state.value.status, SectionStatus.forbidden);
      expect(d.attempt, isNull);
    });

    test('409 whose re-read fails keeps the typed marks and the message', () async {
      final r = await open();
      r.d.setMark('q2', '3');
      repo.onGrade = (_, __) async => throw serverError(409, 'Already graded');
      repo.onAttempt = (id) async => throw serverError(500, 'boom');
      await r.d.submit();
      expect(r.d.failure.value!.message, contains('Already graded'));
      expect(r.d.inputs['q2'], '3');
    });
  });

  group('quiz list shows only my classes', () {
    Future<QuizAttemptsController> make({List<Map<String, Object?>> assignments = const [maths5a]}) async {
      final h = await signedIn();
      h.api.assignments = assignments;
      await h.auth.refreshProfile(force: true);
      return QuizAttemptsController(repository: repo, auth: h.auth, permissions: h.perms);
    }

    test('a server that ignores scoping (or scopes loosely) cannot leak other classes into the list; spelling variants still match', () async {
      repo.onPending = () async => [
            attempt('mine1'),
            attempt('mine2', grade: '5', section: 'a'), // "5" / "a" is the same class
            attempt('mine3', grade: ' grade 5 ', section: 'A '),
            attempt('otherSection', section: 'B'),
            attempt('otherGrade', grade: 'Grade 6'),
            attempt('otherGradeNoSection', grade: 'Grade 7', section: ''),
            attempt('otherSubject', subject: 'English'),
          ];
      final c = await make();
      await c.load();
      expect(c.items.map((a) => a.id), ['mine1', 'mine2', 'mine3']);
    });

    test('only other classes: empty state (not an error), nothing openable', () async {
      repo.onPending = () async => [attempt('x1', section: 'B'), attempt('x2', grade: 'Grade 9')];
      final c = await make();
      await c.load();
      expect(c.state.value.status, SectionStatus.empty);
      expect(c.items, isEmpty);
    });

    test('a teacher with no classes sees nothing', () async {
      repo.onPending = () async => [attempt('x1')];
      final c = await make(assignments: const []);
      await c.load();
      expect(c.state.value.status, SectionStatus.empty);
    });

    test('opening an outside attempt by id is refused BEFORE it is shown or graded', () async {
      final c = await make();
      repo.onPending = () async => [attempt('t1')];
      await c.load();
      repo.onAttempt = (id) async => attempt(id, section: 'B');
      final d = QuizAttemptDetailController(id: 'foreign', list: c, repository: repo);
      await d.load();
      expect(d.state.value.status, SectionStatus.error);
      expect(d.state.value.message, contains("isn't from your class or one of your subjects"));
      expect(d.attempt, isNull);
      expect(d.editable, isFalse);
      d.setMark('q2', '3');
      expect(await d.submit(), isA<GradeIgnored>());
      expect(repo.grades, isEmpty);
    });
  });

  group('remarks errors', () {
    Future<ReportRemarksController> make() async {
      final h = await signedIn(classTeacher: true);
      h.api.assignments = const [];
      await h.auth.refreshProfile(force: true);
      final list = AssessmentsController(repository: repo, auth: h.auth, permissions: h.perms);
      repo.onList = () async => AllPages([asm('a2', cards: true, status: 'completed', section: null)]);
      repo.onCards = (id) async => AllPages([
            ReportCard.fromJson({'_id': 'c1', 'assessmentId': 'a2', 'studentName': 'S1', 'grade': 'Grade 5', 'section': 'A', 'classPosition': 1}),
          ]);
      final c = ReportRemarksController(repository: repo, list: list);
      await c.load();
      return c;
    }

    test('403 for a non-class-teacher: server message shown, the typed text stays, no retry', () async {
      final c = await make();
      repo.onRemarks = (_, __) async => throw serverError(403, 'Only the class teacher of this class can edit report card remarks.', path: '/api/v1/assessments/report-cards/c1/remarks');
      final r = await c.saveRemarks(c.cards.single, 'Good');
      expect(r, isA<RemarksFailed>());
      final f = (r as RemarksFailed).failure;
      expect(f.message, contains('Only the class teacher of this class can edit report card remarks.'));
      expect(f.canRetry, isFalse);
      expect(c.cards.single.classTeacherRemarks, ''); // the card in the list is unchanged
      expect(c.saving, isEmpty);
    });

    test('404 for an unknown report card id: message shown, card stays in the list', () async {
      final c = await make();
      repo.onRemarks = (_, __) async => throw serverError(404, 'Report card not found');
      final r = await c.saveRemarks(c.cards.single, 'Good');
      expect((r as RemarksFailed).failure.kind, ActionFailureKind.notFound);
      expect(r.failure.message, contains('Report card not found'));
      expect(c.cards, hasLength(1));
    });
  });
}
