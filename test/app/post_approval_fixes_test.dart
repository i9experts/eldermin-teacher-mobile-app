// ignore_for_file: invalid_use_of_protected_member
// Owner decisions of 2026-10-08 (post-approval fixes), controller level: drafts listed, locked marks, stale header refresh, upload 503.
import 'package:dio/dio.dart' hide Response;
import 'package:dio/dio.dart' as dio show Response;
import 'package:eldermin_teacher_app/app/common/action_failure.dart';
import 'package:eldermin_teacher_app/app/modules/assessments/controllers/assessments_controller.dart';
import 'package:eldermin_teacher_app/app/modules/assessments/controllers/marks_entry_controller.dart';
import 'package:eldermin_teacher_app/app/modules/homework/controllers/homework_controller.dart';
import 'package:eldermin_teacher_app/app/modules/homework/controllers/homework_form_controller.dart';
import 'package:eldermin_teacher_app/core/models/assessments/assessment_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/network/dio_exception_handler.dart';
import 'package:eldermin_teacher_app/core/services/assessment_repository.dart';
import 'package:eldermin_teacher_app/core/services/attachment_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_assessment_repositories.dart';
import '../support/fake_classroom_repositories.dart';
import '../support/fake_phase5b_repositories.dart';

const maths5a = {'gradeLevel': 'Grade 5', 'sectionName': 'A', 'subjectName': 'Mathematics'};

ApiException serverError(int status, String message) {
  final ro = RequestOptions(path: '/api/v1/x');
  return DioExceptionHandler.handle(DioException(
    requestOptions: ro,
    type: DioExceptionType.badResponse,
    response: dio.Response(requestOptions: ro, statusCode: status, data: {'statusCode': status, 'message': message, 'timestamp': '2026-10-08T10:00:00.000Z', 'path': '/api/v1/x'}),
  ));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeAssessmentRepository repo;
  late FakeStudentsRepository students;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakeAssessmentRepository();
    students = FakeStudentsRepository();
    students.roster = (cls) async => [for (var i = 1; i <= 3; i++) student(i)];
  });
  tearDown(Get.reset);

  group('drafts are listed (owner decision 2026-10-08)', () {
    test('a draft of my class and subject is in "My assessments" under its own Drafts filter; marks access = draft', () async {
      final h = await signedIn();
      h.api.assignments = const [maths5a];
      await h.auth.refreshProfile(force: true);
      repo.onList = () async => AllPages([asm('d1', status: 'draft', title: 'Draft Test'), asm('o1', title: 'Open Test')]);
      final c = AssessmentsController(repository: repo, auth: h.auth, permissions: h.perms);
      await c.load();
      expect(c.items.map((a) => a.title), containsAll(['Draft Test', 'Open Test']));
      expect(c.countFor(AssessmentFilter.drafts), 1);
      expect(c.countFor(AssessmentFilter.open), 1);
      c.setFilter(AssessmentFilter.drafts);
      expect(c.filtered.single.title, 'Draft Test');
      final d = c.filtered.single;
      expect(c.accessFor(d, d.subjects.first), MarksAccess.draft);
      expect(MarksAccess.draft.explanation, "Draft assessments can't take marks yet.");
    });
  });

  group('marks grid after a server rejection: header refresh (stale total 50 -> 20)', () {
    Future<MarksEntryController> make(Assessment a) async {
      final h = await signedIn();
      h.api.assignments = const [maths5a];
      await h.auth.refreshProfile(force: true);
      repo.onOne = (_) async => a;
      final c = MarksEntryController(assessmentId: 'a1', subject: 'Mathematics', repository: repo, students: students, auth: h.auth, permissions: h.perms);
      await c.load();
      return c;
    }

    MarkEntryRow row(MarksEntryController c, int i) => c.rows.firstWhere((r) => r.student.id == student(i).id);

    test('400: total / pass marks come from the fresh copy, typed values are re-validated (35 flagged against 20), nothing auto-changed or auto-sent', () async {
      final c = await make(asm('a1'));
      expect(c.total, 50);
      c.setMarks(student(1).id, '35');
      c.setMarks(student(2).id, '15');
      repo.onSave = (_) async => throw serverError(400, 'Marks must be between 0 and 20 for Mathematics. Invalid for 1 student(s): Student 1 (roll 1): 35');
      repo.onOne = (_) async => asm('a1', subjects: const [('Mathematics', 20, 8)]);
      expect(await c.save(), isA<MarksSaveFailed>());
      expect(c.total, 20);
      expect(c.passing, 8);
      expect(c.errorOf(row(c, 1)), "Can't be more than 20.");
      expect(c.errorOf(row(c, 2)), isNull);
      expect(c.invalidRows, hasLength(1));
      expect(row(c, 1).text, '35');
      expect(row(c, 2).text, '15');
      expect(repo.saves, hasLength(1)); // not re-sent
      expect(c.editable, isTrue);
    });

    test('the refresh also picks up a status change: published meanwhile = locked, typed values kept', () async {
      final c = await make(asm('a1'));
      c.setMarks(student(1).id, '10');
      repo.onSave = (_) async => throw serverError(409, 'Marks for 1 students are verified and locked: Student 3 (roll 3)');
      repo.onOne = (_) async => asm('a1', status: 'result_published', published: true);
      await c.save();
      expect(c.access.value, MarksAccess.locked);
      expect(c.editable, isFalse);
      expect(c.lockMessage, contains('Results are published'));
      expect(row(c, 1).text, '10');
    });

    test('if the re-read fails the old header stays and nothing extra is shown', () async {
      final c = await make(asm('a1'));
      c.setMarks(student(1).id, '35');
      repo.onSave = (_) async => throw serverError(400, 'Marks must be between 0 and 20 for Mathematics. Invalid for 1 student(s): Student 1 (roll 1): 35');
      repo.onOne = (_) async => throw ApiException('boom', statusCode: 500);
      expect(await c.save(), isA<MarksSaveFailed>());
      expect(c.total, 50);
      expect(c.errorOf(row(c, 1)), isNull);
      expect(c.editable, isTrue);
      expect(c.saveFailure.value!.message, startsWith('Marks must be between 0 and 20'));
    });

    test('a 500 does not trigger the extra re-read', () async {
      final c = await make(asm('a1'));
      c.setMarks(student(1).id, '10');
      repo.onSave = (_) async => throw serverError(500, 'Internal server error');
      final before = repo.calls.where((x) => x.startsWith('one:')).length;
      await c.save();
      expect(repo.calls.where((x) => x.startsWith('one:')).length, before);
    });
  });

  group('upload unavailable (503)', () {
    test('ActionFailure maps 503 to uploadUnavailable ONLY for uploads, shows the server text, no retry', () {
      const text = 'File uploads are not available on this server (storage is not configured).';
      final f = ActionFailure.from(serverError(503, text), what: 'upload a.pdf', upload: true);
      expect(f.kind, ActionFailureKind.uploadUnavailable);
      expect(f.message, text);
      expect(f.canRetry, isFalse);
      expect(ActionFailure.uploadUnavailableTitle, 'Upload unavailable');
      expect(ActionFailure.from(serverError(503, text), what: 'save').kind, ActionFailureKind.server); // not an upload: as before
      expect(ActionFailure.from(serverError(500, 'x'), what: 'upload a.pdf', upload: true).kind, ActionFailureKind.server);
    });

    test('homework: 503 -> unavailable flag, retry does nothing, "Continue without attachment" (remove) lets the homework be created', () async {
      final hr = FakeHomeworkRepository();
      final h = await signedIn();
      h.api.assignments = const [maths5a];
      await h.auth.refreshProfile(force: true);
      students.roster = (_) async => [student(1)];
      const text = 'File uploads are not available on this server (storage is not configured).';
      hr.onUpload = (p, n, pr) async => throw serverError(503, text);
      final c = HomeworkFormController(repository: hr, students: students, auth: h.auth, picker: FakePicker(), list: HomeworkController(repository: hr, auth: h.auth, permissions: h.perms), clock: () => DateTime(2026, 10, 8, 9));
      c.onInit();
      addTearDown(c.onClose);
      await Future<void>.delayed(Duration.zero);
      await c.addPicked([const PickedAttachment(name: 'a.pdf', path: '/tmp/a.pdf', size: 1000)]);
      final it = c.attachments.single;
      expect(it.status.value, UploadStatus.failed);
      expect(it.unavailable.value, isTrue);
      expect(it.error.value, text);
      await c.retryUpload(it.id); // must not hammer the server
      expect(hr.calls.where((x) => x.startsWith('upload:')), hasLength(1));
      c.titleC.text = 't';
      c.setDueDay(DateTime(2026, 10, 9));
      expect(await c.submit(assign: false), isA<FormInvalid>()); // still blocked by the failed file
      c.removeAttachment(it.id);
      expect(c.errors['attachments'], isNull);
      expect(await c.submit(assign: false), isA<FormSaved>());
      expect(hr.created.single.input.attachmentKeys, isEmpty);
    });

    test('homework: a plain 500 stays a retryable failure (not unavailable)', () async {
      final hr = FakeHomeworkRepository();
      final h = await signedIn();
      h.api.assignments = const [maths5a];
      await h.auth.refreshProfile(force: true);
      students.roster = (_) async => [student(1)];
      hr.onUpload = (p, n, pr) async => throw serverError(500, 'Internal server error');
      final c = HomeworkFormController(repository: hr, students: students, auth: h.auth, picker: FakePicker(), list: HomeworkController(repository: hr, auth: h.auth, permissions: h.perms), clock: () => DateTime(2026, 10, 8, 9));
      c.onInit();
      addTearDown(c.onClose);
      await Future<void>.delayed(Duration.zero);
      await c.addPicked([const PickedAttachment(name: 'a.pdf', path: '/tmp/a.pdf', size: 1000)]);
      expect(c.attachments.single.unavailable.value, isFalse);
      await c.retryUpload(c.attachments.single.id);
      expect(hr.calls.where((x) => x.startsWith('upload:')), hasLength(2));
    });
  });
}
