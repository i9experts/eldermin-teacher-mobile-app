// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';
import 'package:eldermin_teacher_app/app/modules/assessments/controllers/assessments_controller.dart';
import 'package:eldermin_teacher_app/app/modules/assessments/controllers/marks_entry_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/models/section_state.dart';
import 'package:eldermin_teacher_app/core/models/assessments/assessment_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/services/assessment_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_assessment_repositories.dart';
import '../support/fake_classroom_repositories.dart';

const maths5a = {'gradeLevel': 'Grade 5', 'sectionName': 'A', 'subjectName': 'Mathematics'};
const maths5b = {'gradeLevel': 'Grade 5', 'sectionName': 'B', 'subjectName': 'Mathematics'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeAssessmentRepository repo;
  late FakeStudentsRepository students;
  late Assessment a1;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakeAssessmentRepository();
    students = FakeStudentsRepository();
    a1 = asm('a1'); // Grade 5 A, Mathematics out of 50, pass 20, ongoing
    repo.onOne = (id) async => a1;
    students.roster = (cls) async => [for (var i = 1; i <= 5; i++) student(i)];
  });
  tearDown(Get.reset);

  Future<MarksEntryController> make({List<Map<String, Object?>> assignments = const [maths5a], bool classTeacher = false, List<String>? permissions, String subject = 'Mathematics', String? section, bool load = true}) async {
    final h = await signedIn(classTeacher: classTeacher, permissions: permissions);
    h.api.assignments = assignments;
    await h.auth.refreshProfile(force: true);
    final c = MarksEntryController(assessmentId: 'a1', subject: subject, initialSection: section, repository: repo, students: students, auth: h.auth, permissions: h.perms);
    if (load) await c.load();
    return c;
  }

  MarkEntryRow row(MarksEntryController c, int i) => c.rows.firstWhere((r) => r.student.id == student(i).id);

  group('loading', () {
    test('roster x existing marks: numbers, absent, exempt and remarks are prefilled; unmarked students are blank', () async {
      repo.onMarks = (_, __) async => AllPages([mark(student(1), 42.5, remarks: 'good'), mark(student(2), null, absent: true), mark(student(3), null, exempt: true)]);
      final c = await make();
      expect(c.state.value.status, SectionStatus.data);
      expect(c.rows, hasLength(5));
      expect(row(c, 1).text, '42.5');
      expect(row(c, 1).remarks, 'good');
      expect(row(c, 2).absent, isTrue);
      expect(row(c, 3).exempt, isTrue);
      expect(row(c, 4).text, '');
      expect(c.hasUnsavedChanges, isFalse);
      expect(c.editable, isTrue);
      expect(c.total, 50);
      expect(c.passing, 20);
      expect(repo.calls, contains('marks:a1:Mathematics'));
    });

    test('marks of students who are not on the roster (other sections of an all-sections assessment) are ignored', () async {
      repo.onMarks = (_, __) async => AllPages([mark(student(99), 40)]);
      final c = await make();
      expect(c.rows.every((r) => r.saved == null), isTrue);
    });

    test('a roster of 230 students is shown in full (the web truncates at 100)', () async {
      students.roster = (cls) async => [for (var i = 1; i <= 230; i++) student(i)];
      final c = await make();
      expect(c.rows, hasLength(230));
    });

    test('empty roster: empty state; error: error state; retry works', () async {
      students.roster = (_) async => [];
      var c = await make();
      expect(c.state.value.status, SectionStatus.empty);
      Get.reset();
      Get.testMode = true;
      var fail = true;
      students.roster = (_) async => fail ? throw ApiException('boom', statusCode: 500) : [student(1)];
      c = await make();
      expect(c.state.value.status, SectionStatus.error);
      fail = false;
      await c.load(force: true);
      expect(c.state.value.status, SectionStatus.data);
    });

    test('403 on the roster or the marks = forbidden; no assessments:view permission = forbidden without any request', () async {
      repo.onMarks = (_, __) async => throw ApiException('Forbidden resource', statusCode: 403);
      var c = await make();
      expect(c.state.value.status, SectionStatus.forbidden);
      Get.reset();
      Get.testMode = true;
      repo = FakeAssessmentRepository()..onOne = (_) async => a1;
      c = await make(permissions: ['teaching:view']);
      expect(c.state.value.status, SectionStatus.forbidden);
      expect(repo.calls, isEmpty);
    });

    test('a subject that is not part of the assessment, or a colleague\'s assessment, is refused', () async {
      var c = await make(subject: 'Art');
      expect(c.state.value.status, SectionStatus.error);
      Get.reset();
      Get.testMode = true;
      a1 = asm('a1', grade: 'Grade 9', section: 'Z');
      c = await make();
      expect(c.state.value.status, SectionStatus.error);
      expect(c.state.value.message, contains("isn't one of yours"));
    });

    test('an all-sections assessment taught in two sections offers both classes; initialSection preselects', () async {
      a1 = asm('a1', section: null);
      final seen = <String>[];
      students.roster = (cls) async {
        seen.add(cls.label);
        return [student(1, section: cls.section)];
      };
      final c = await make(assignments: const [maths5a, maths5b], section: 'B');
      expect(c.classes.map((x) => x.label), ['Grade 5 - A', 'Grade 5 - B']);
      expect(c.currentClass!.label, 'Grade 5 - B');
      expect(seen, ['Grade 5 - B']);
      await c.selectClass(0);
      expect(seen, ['Grade 5 - B', 'Grade 5 - A']);
    });

    test('class teacher who does not teach the subject gets a read-only view of her class', () async {
      final c = await make(assignments: const [], classTeacher: true);
      expect(c.access.value, MarksAccess.notMySubject);
      expect(c.editable, isFalse);
      expect(c.state.value.status, SectionStatus.data);
      c.setMarks(student(1).id, '10');
      expect(row(c, 1).text, '');
      expect(c.hasUnsavedChanges, isFalse);
    });
  });

  group('access matrix (NO assessment-status gate)', () {
    final s = asm('x').subjects.first;
    test('editable for every status when it is my subject; only not-mine and online-quiz subjects are blocked', () {
      for (final st in ['draft', 'scheduled', 'ongoing', 'completed', 'cancelled', 'result_published']) {
        expect(marksAccessFor(asm('x', status: st), s, iTeachIt: true), MarksAccess.editable, reason: st);
      }
      expect(marksAccessFor(asm('x', status: 'completed', published: true), s, iTeachIt: true), MarksAccess.editable);
      expect(marksAccessFor(asm('x'), s, iTeachIt: false), MarksAccess.notMySubject);
      final q = asm('x', online: true, paperOn: 'Mathematics');
      expect(marksAccessFor(q, q.subjects.first, iTeachIt: true), MarksAccess.onlineQuiz);
      final q2 = asm('x', online: true); // online delivery but this subject has no paper: teacher-marked
      expect(marksAccessFor(q2, q2.subjects.first, iTeachIt: true), MarksAccess.editable);
    });

    test('warning only for results published / cancelled, never blocking', () {
      expect(marksStatusWarning(asm('x', status: 'ongoing')), isNull);
      expect(marksStatusWarning(asm('x', status: 'scheduled')), isNull);
      expect(marksStatusWarning(asm('x', status: 'draft')), isNull);
      expect(marksStatusWarning(asm('x', status: 'result_published', published: true)), 'Results are published; changes may affect published results.');
      expect(marksStatusWarning(asm('x', status: 'completed', published: true)), contains('Results are published'));
      expect(marksStatusWarning(asm('x', status: 'cancelled')), contains('cancelled'));
    });

    for (final (status, warns) in [('scheduled', false), ('draft', false), ('ongoing', false), ('result_published', true), ('cancelled', true)]) {
      test('$status: the grid is editable, saves, and ${warns ? 'warns' : 'shows no warning'}', () async {
        a1 = asm('a1', status: status, published: status == 'result_published');
        repo.onMarks = (_, __) async => AllPages([mark(student(1), 30)]);
        final c = await make();
        expect(c.access.value, MarksAccess.editable);
        expect(c.editable, isTrue);
        expect(c.canEnter, isTrue);
        expect(c.statusWarning != null, warns);
        c.setMarks(student(2).id, '12');
        expect(c.hasUnsavedChanges, isTrue);
        expect(await c.save(), isA<MarksSaved>());
        expect(repo.saves, hasLength(1));
        expect(repo.saves.single.marks.single['obtainedMarks'], 12);
      });
    }

    test('0..total still enforced when published', () async {
      a1 = asm('a1', status: 'result_published', published: true);
      final c = await make();
      c.setMarks(student(2).id, '51');
      expect(await c.save(), isA<MarksInvalid>());
      expect(repo.saves, isEmpty);
    });

    test('online-quiz subject: read-only with an explanation', () async {
      a1 = asm('a1', online: true, paperOn: 'Mathematics');
      final c = await make();
      expect(c.access.value, MarksAccess.onlineQuiz);
      expect(c.access.value.explanation, contains('online quiz'));
    });
  });

  group('verified / locked rows (the server would overwrite them and keep them verified)', () {
    test('a verified row is read-only, not sent, and counted; the other rows stay editable', () async {
      repo.onMarks = (_, __) async => AllPages([mark(student(1), 40, verified: true), mark(student(2), 30), mark(student(3), 20, quiz: true)]);
      final c = await make();
      expect(row(c, 1).locked, isTrue);
      expect(row(c, 1).lockReason, contains('Verified'));
      expect(row(c, 3).locked, isTrue);
      expect(row(c, 3).lockReason, contains('online quiz'));
      expect(c.lockedCount, 2);
      expect(c.allLocked, isFalse);
      c.setMarks(student(1).id, '10');
      c.setAbsent(student(1).id, true);
      c.setRemarks(student(1).id, 'x');
      expect(row(c, 1).text, '40');
      expect(row(c, 1).absent, isFalse);
      c.setMarks(student(2).id, '33');
      expect(c.dirtyCount, 1);
      await c.save();
      final sent = repo.saves.single.marks.map((m) => m['studentId']).toList();
      expect(sent, [student(2).id]);
    });

    test('every row verified: whole sheet locked, nothing can be entered', () async {
      repo.onMarks = (_, __) async => AllPages([for (var i = 1; i <= 5; i++) mark(student(i), 25, verified: true)]);
      final c = await make();
      expect(c.allLocked, isTrue);
      expect(c.canEnter, isFalse);
      expect(c.hasUnsavedChanges, isFalse);
    });
  });

  group('validation (0..total; the server only checks >= 0)', () {
    String? err(MarksEntryController c, int i) => c.errorOf(row(c, i));

    test('bounds: 0 and exactly the total are valid; above the total, negative, letters and 3 decimals are not', () async {
      final c = await make();
      for (final (text, ok) in [('0', true), ('50', true), ('49.5', true), ('7,5', true), ('7.25', true), ('50.01', false), ('51', false), ('-1', false), ('abc', false), ('1.234', false), ('1.2.3', false), ('', true)]) {
        c.setMarks(student(1).id, text);
        expect(err(c, 1) == null, ok, reason: 'input "$text"');
      }
      c.setMarks(student(1).id, '60');
      expect(err(c, 1), "Can't be more than 50.");
      c.setMarks(student(1).id, '1.234');
      expect(err(c, 1), 'Use at most 2 decimals.');
    });

    test('a blank row that was never entered is simply "not entered", not an error', () async {
      final c = await make();
      expect(c.invalidRows, isEmpty);
      expect(c.hasUnsavedChanges, isFalse);
    });

    test('remarks without marks or a flag is an error; a saved mark cannot be cleared (the server has no delete)', () async {
      repo.onMarks = (_, __) async => AllPages([mark(student(2), 30)]);
      final c = await make();
      c.setRemarks(student(1).id, 'note only');
      expect(err(c, 1), contains('Enter marks or mark absent'));
      c.setMarks(student(2).id, '');
      expect(err(c, 2), contains("can't be cleared"));
      c.setAbsent(student(2).id, true); // the allowed alternative
      expect(err(c, 2), isNull);
    });

    test('a saved mark that is already above the total (server gap) shows a warning and is not silently changed', () async {
      repo.onMarks = (_, __) async => AllPages([mark(student(1), 80)]);
      final c = await make();
      expect(row(c, 1).warning(c.total), contains('above the total'));
      expect(row(c, 1).text, '80');
      expect(c.hasUnsavedChanges, isFalse);
      expect(c.summary().entered, 0); // excluded from the statistics
    });

    test('absent and exempt are exclusive; typing a number clears them; absent clears the number', () async {
      final c = await make();
      final id = student(1).id;
      c.setMarks(id, '20');
      c.setAbsent(id, true);
      expect((row(c, 1).absent, row(c, 1).text), (true, ''));
      c.setExempt(id, true);
      expect((row(c, 1).absent, row(c, 1).exempt), (false, true));
      c.setMarks(id, '15');
      expect((row(c, 1).absent, row(c, 1).exempt, row(c, 1).text), (false, false, '15'));
      c.setAbsent(id, true);
      c.setAbsent(id, false);
      expect(row(c, 1).hasInput, isFalse);
    });
  });

  group('unsaved changes', () {
    test('edits make it dirty; reverting to the saved value makes it clean again; discard reloads from the server', () async {
      repo.onMarks = (_, __) async => AllPages([mark(student(1), 30, remarks: 'r')]);
      final c = await make();
      expect(c.hasUnsavedChanges, isFalse);
      c.setMarks(student(1).id, '31');
      expect(c.hasUnsavedChanges, isTrue);
      expect(c.dirtyCount, 1);
      c.setMarks(student(1).id, '30');
      expect(c.hasUnsavedChanges, isFalse);
      c.setMarks(student(2).id, '5');
      c.setRemarks(student(1).id, 'changed');
      expect(c.dirtyCount, 2);
      await c.discardChanges();
      expect(c.hasUnsavedChanges, isFalse);
      expect(row(c, 2).text, '');
      expect(row(c, 1).remarks, 'r');
    });

    test('an invalid-but-dirty row still counts as unsaved (the leave guard must fire)', () async {
      final c = await make();
      c.setMarks(student(1).id, '999');
      expect(c.hasUnsavedChanges, isTrue);
    });
  });

  group('summary (before saving)', () {
    test('entered / absent / exempt / not entered, average, lowest, highest, below pass - over the whole sheet', () async {
      repo.onMarks = (_, __) async => AllPages([mark(student(1), 40), mark(student(2), null, absent: true)]);
      final c = await make();
      c.setMarks(student(3).id, '10'); // below pass (20)
      c.setMarks(student(4).id, '25');
      c.setExempt(student(5).id, true);
      final s = c.summary();
      expect((s.students, s.entered, s.absent, s.exempt, s.notEntered), (5, 3, 1, 1, 0));
      expect(s.lowest, 10);
      expect(s.highest, 40);
      expect(s.average, 25);
      expect(s.averagePercent, 50);
      expect(s.belowPass, 1);
      expect(s.total, 50);
    });

    test('no marks: no average / min / max', () async {
      final c = await make();
      final s = c.summary();
      expect((s.entered, s.notEntered), (0, 5));
      expect((s.average, s.lowest, s.highest, s.averagePercent), (null, null, null, null));
    });

    test('invalid numbers are left out of the statistics', () async {
      final c = await make();
      c.setMarks(student(1).id, '70');
      c.setMarks(student(2).id, '20');
      expect(c.summary().entered, 1);
      expect(c.summary().highest, 20);
    });
  });

  group('saving', () {
    test('review: invalid rows block (count, errors visible); nothing changed = nothing to save; no request either way', () async {
      final c = await make();
      expect(c.review(), isA<MarksNothingToSave>());
      c.setMarks(student(1).id, '99');
      c.setMarks(student(2).id, 'x');
      final r = c.review();
      expect(r, isA<MarksInvalid>());
      expect((r as MarksInvalid).count, 2);
      expect(c.showErrors.value, isTrue);
      expect(await c.save(), isA<MarksInvalid>());
      expect(repo.saves, isEmpty);
      c.setMarks(student(1).id, '49');
      c.setMarks(student(2).id, '1');
      expect(c.review(), isNull);
    });

    test('POST body: assessment grade, subject, academic-year header, ONLY changed rows, absent/exempt as null, student fields from the roster', () async {
      repo.onMarks = (_, __) async => AllPages([mark(student(1), 40), mark(student(2), 30)]);
      final c = await make();
      c.setMarks(student(1).id, '41'); // changed
      c.setAbsent(student(3).id, true); // new
      c.setExempt(student(4).id, true); // new
      c.setMarks(student(5).id, ' 7,5 '); // new, comma + spaces
      c.setRemarks(student(5).id, ' fine ');
      final r = await c.save();
      expect(r, isA<MarksSaved>());
      expect((r as MarksSaved).count, 4);
      final call = repo.saves.single;
      expect((call.assessmentId, call.subject, call.grade, call.year), ('a1', 'Mathematics', 'Grade 5', '2026-27'));
      expect(call.marks.map((m) => m['studentId']), [student(1).id, student(3).id, student(4).id, student(5).id]); // student 2 untouched: not sent
      expect(call.marks[0], {'studentId': student(1).id, 'studentName': 'First1 Last1', 'rollNumber': '1', 'section': 'A', 'obtainedMarks': 41.0, 'isAbsent': false, 'isExempt': false, 'remarks': ''});
      expect(call.marks[1]['obtainedMarks'], isNull);
      expect(call.marks[1]['isAbsent'], isTrue);
      expect(call.marks[2]['isExempt'], isTrue);
      expect(call.marks[3]['obtainedMarks'], 7.5);
      expect(call.marks[3]['remarks'], 'fine');
    });

    test('success: dirty cleared, rows now "saved", the server copy is re-read, saved count is exposed', () async {
      final c = await make();
      c.setMarks(student(1).id, '30');
      var served = <MarkRecord>[];
      repo.onMarks = (_, __) async => AllPages(served);
      served = [mark(student(1), 30)];
      await c.save();
      expect(c.hasUnsavedChanges, isFalse);
      expect(row(c, 1).saved?.obtainedMarks, 30);
      expect(c.lastSavedCount.value, 1);
      expect(c.saveFailure.value, isNull);
      expect(c.saving.value, isFalse);
      expect(repo.calls.where((x) => x.startsWith('marks:')), hasLength(2)); // load + re-read
    });

    test('success even if the re-read fails: local rows are marked saved', () async {
      final c = await make();
      c.setMarks(student(1).id, '30');
      repo.onMarks = (_, __) async => throw ApiException('down', statusCode: 500);
      expect(await c.save(), isA<MarksSaved>());
      expect(c.hasUnsavedChanges, isFalse);
      expect(row(c, 1).saved?.obtainedMarks, 30);
    });

    test('double submit: a second save while one is in flight is ignored; only ONE request goes out', () async {
      final gate = Completer<void>();
      repo.onSave = (_) => gate.future;
      final c = await make();
      c.setMarks(student(1).id, '30');
      final first = c.save();
      expect(c.saving.value, isTrue);
      expect(await c.save(), isA<MarksSaveIgnored>());
      expect(c.review(), isA<MarksSaveIgnored>());
      c.setMarks(student(2).id, '5'); // editing while saving is ignored too
      expect(row(c, 2).text, '');
      gate.complete();
      expect(await first, isA<MarksSaved>());
      expect(repo.saves, hasLength(1));
    });

    test('offline: state is kept, the failure is shown with the "kept" wording, retry resends the SAME body and then succeeds', () async {
      final c = await make();
      c.setMarks(student(1).id, '30');
      c.setAbsent(student(2).id, true);
      var fail = true;
      repo.onSave = (_) async {
        if (fail) throw ApiException('No internet connection.');
      };
      final r = await c.save();
      expect(r, isA<MarksSaveFailed>());
      expect(c.saveFailure.value!.message, contains('Your marks are kept'));
      expect(c.hasUnsavedChanges, isTrue);
      expect(row(c, 1).text, '30');
      expect(row(c, 2).absent, isTrue);
      expect(c.saving.value, isFalse);
      fail = false;
      expect(await c.save(), isA<MarksSaved>());
      expect(repo.saves, hasLength(2));
      expect(repo.saves[1].marks, repo.saves[0].marks);
      expect(c.saveFailure.value, isNull);
    });

    test('partial failure (500 after the first half was written): everything stays dirty, retry resends all of it', () async {
      final c = await make();
      for (var i = 1; i <= 4; i++) {
        c.setMarks(student(i).id, '${10 + i}');
      }
      repo.onSave = (_) async => throw ApiException('Internal server error', statusCode: 500);
      expect(await c.save(), isA<MarksSaveFailed>());
      expect(c.saveFailure.value!.message, contains("couldn't save these marks"));
      expect(c.dirtyCount, 4);
      repo.onSave = null;
      expect(await c.save(), isA<MarksSaved>());
      expect(repo.saves[1].marks, hasLength(4));
    });

    test('400 with the real error shape marks the offending row; editing that row clears the server message', () async {
      final c = await make();
      c.setMarks(student(1).id, '10');
      c.setMarks(student(2).id, '20');
      c.setMarks(student(3).id, '30');
      repo.onSave = (_) async => throw ApiException('marks.1.obtainedMarks must not be less than 0', statusCode: 400);
      final r = await c.save();
      expect(r, isA<MarksSaveFailed>());
      expect(c.saveFailure.value!.kind.name, 'validation');
      expect(c.saveFailure.value!.message, 'marks.1.obtainedMarks must not be less than 0');
      expect(row(c, 2).serverError, contains('marks.1'));
      expect(row(c, 1).serverError, isNull);
      expect(c.errorOf(row(c, 2)), isNotNull);
      c.setMarks(student(2).id, '21');
      expect(row(c, 2).serverError, isNull);
    });

    test('403 on save: a calm "can\'t save" message with the server text; state kept', () async {
      final c = await make();
      c.setMarks(student(1).id, '10');
      repo.onSave = (_) async => throw ApiException('Forbidden resource', statusCode: 403);
      await c.save();
      expect(c.saveFailure.value!.isForbidden, isTrue);
      expect(c.saveFailure.value!.message, contains("You can't save these marks"));
      expect(c.hasUnsavedChanges, isTrue);
    });

    test('class switch loads the other roster; marks of one class never leak into the other', () async {
      a1 = asm('a1', section: null);
      students.roster = (cls) async => [student(cls.section == 'A' ? 1 : 2, section: cls.section)];
      final c = await make(assignments: const [maths5a, maths5b]);
      c.setMarks(student(1).id, '10');
      await c.selectClass(1);
      expect(c.rows.map((r) => r.student.id), [student(2).id]);
      expect(c.rows.single.text, '');
      expect(c.hasUnsavedChanges, isFalse);
    });
  });
}
