import 'dart:convert';
import 'dart:io';
import 'package:eldermin_teacher_app/core/models/homework/homework_models.dart';
import 'package:eldermin_teacher_app/core/models/json_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

dynamic fx(String n) => jsonDecode(File('test/fixtures/phase5b/$n.json').readAsStringSync());

void main() {
  group('Assignment parsing (stub-derived, mirrors assignment.schema.ts)', () {
    final list = (fx('assignments') as List).cast<Map<String, dynamic>>().map(Assignment.fromJson).toList();

    test('all four of mine parse with typed fields', () {
      expect(list, hasLength(4));
      final a = list.firstWhere((x) => x.title.startsWith('Chapter 3'));
      expect(a.subject, 'Mathematics');
      expect(a.classLabel, 'Grade 5 - A');
      expect(a.totalMarks, 100);
      expect(a.attachmentKeys, hasLength(1));
      expect(a.status, 'assigned');
      expect(a.type, AssignmentType.homework);
      expect(a.submissionsCount, 3);
    });

    test('unknown / hostile fields are ignored', () {
      final a = Assignment.fromJson({'_id': 'x', 'title': 'T', 'tenantId': 'secret', 'campusId': 'c', 'zzz': 1, 'totalMarks': '12.5'});
      expect(a.id, 'x');
      expect(a.totalMarks, 12.5);
      expect(a.toString(), isNot(contains('secret')));
    });

    test('missing section and dates are tolerated', () {
      final a = Assignment.fromJson({'_id': 'x', 'title': 'T', 'dueDate': null, 'sectionName': null});
      expect(a.sectionName, '');
      expect(a.dueDay, isNull);
      expect(a.phaseOn(DateTime(2026, 10, 5)), HomeworkPhase.draft);
    });

    test('type outside the create enum (assessment) stays readable', () {
      final a = Assignment.fromJson({'_id': 'x', 'type': 'assessment'});
      expect(a.type, isNull);
      expect(a.typeLabel, 'Assessment');
    });
  });

  group('phases are decided on calendar days, not instants', () {
    Assignment due(String iso, String status) => Assignment.fromJson({'_id': 'a', 'dueDate': iso, 'status': status});

    test('assigned: before, on and after the due day', () {
      final a = due('2026-10-05T00:00:00.000Z', 'assigned');
      expect(a.phaseOn(DateTime(2026, 10, 4, 23, 59)), HomeworkPhase.active);
      expect(a.phaseOn(DateTime(2026, 10, 5, 0, 0)), HomeworkPhase.dueToday);
      expect(a.phaseOn(DateTime(2026, 10, 5, 23, 59)), HomeworkPhase.dueToday);
      expect(a.phaseOn(DateTime(2026, 10, 6, 0, 1)), HomeworkPhase.overdue);
    });

    test('server status overdue wins; drafts stay drafts even when past due', () {
      expect(due('2030-01-01T00:00:00.000Z', 'overdue').phaseOn(DateTime(2026, 1, 1)), HomeworkPhase.overdue);
      expect(due('2020-01-01T00:00:00.000Z', 'draft').phaseOn(DateTime(2026, 1, 1)), HomeworkPhase.draft);
      expect(due('2020-01-01T00:00:00.000Z', 'graded').phaseOn(DateTime(2026, 1, 1)), HomeworkPhase.other);
    });

    test('the due day is the UTC date of the stored instant whatever the device timezone', () {
      // Written as '2026-10-05' -> stored 2026-10-05T00:00:00Z. In Los Angeles the local instant is Oct 4, 17:00:
      // must still be Oct 5. (flutter test runs this under the TZ in the environment: the result may not depend on it.)
      final a = due('2026-10-05T00:00:00.000Z', 'assigned');
      expect(a.dueDay, DateTime(2026, 10, 5));
      expect(wireDay(a.dueDay!), '2026-10-05');
    });
  });

  group('Submission parsing and states', () {
    final res = SubmissionsResult.fromJson(fx('submissions') as Map<String, dynamic>);

    test('roster snapshot includes not-submitted rows', () {
      expect(res.assignment.title, startsWith('Chapter 3'));
      expect(res.submissions.length, 28);
      expect(res.submissions.where((s) => s.notSubmitted).length, 25);
      expect(res.submissions.where((s) => s.needsGrading).length, 2);
      expect(res.submissions.where((s) => s.isGraded).length, 1);
    });

    test('text, attachment and grade fields', () {
      final withFile = res.submissions.firstWhere((s) => s.attachmentKeys.isNotEmpty);
      expect(withFile.textResponse, isNotEmpty);
      expect(withFile.submittedAt, isNotNull);
      final graded = res.submissions.firstWhere((s) => s.isGraded);
      expect(graded.grade, 18);
      expect(graded.maxGrade, 100);
      expect(graded.feedback, 'Good work (DUMMY).');
    });

    test('late stays flagged after grading; unknown status is not graded', () {
      expect(Submission.fromJson({'_id': 's', 'status': 'graded', 'isLate': true}).wasLate, isTrue);
      expect(Submission.fromJson({'_id': 's', 'status': 'late'}).wasLate, isTrue);
      final u = Submission.fromJson({'_id': 's', 'status': 'weird'});
      expect(u.state, SubmissionState.unknown);
      expect(u.needsGrading || u.isGraded || u.notSubmitted, isFalse);
    });

    test('rows without an id are dropped', () {
      final r = SubmissionsResult.fromJson({'assignment': {'_id': 'a'}, 'submissions': [{'status': 'pending'}, {'_id': 's1'}]});
      expect(r.submissions.map((s) => s.id), ['s1']);
    });
  });

  group('upload response', () {
    test('real envelope { success, data }', () {
      final u = UploadedFile.fromBody(fx('upload_single'))!;
      expect(u.key, matches(RegExp(r'^demo-school/homework-attachments/[0-9a-f-]{36}\.pdf$')));
      expect(u.fileName, 'w.pdf');
      expect(u.fileType, 'application/pdf');
    });
    test('bare object and garbage', () {
      expect(UploadedFile.fromBody({'key': 'a/b/c.png'})!.key, 'a/b/c.png');
      expect(UploadedFile.fromBody({'success': true, 'data': {}}), isNull);
      expect(UploadedFile.fromBody('nope'), isNull);
    });
    test('mime table is the backend ALLOWED_TYPES.any', () {
      expect(attachmentMimeFor('Scan.JPG'), 'image/jpeg');
      expect(attachmentMimeFor('a.docx'), contains('wordprocessingml'));
      expect(attachmentMimeFor('a.exe'), isNull);
      expect(attachmentMimeFor('noext'), isNull);
      expect(attachmentLabel('demo-school/homework-attachments/abc.pdf', 0), 'Attachment 1 (PDF)');
    });
  });

  group('create / patch payloads', () {
    final input = AssignmentInput(
      title: '  Worksheet ',
      description: '',
      subject: 'Mathematics',
      gradeLevel: 'Grade 5',
      sectionName: 'A',
      type: AssignmentType.classwork,
      assignedDay: DateTime(2026, 10, 5),
      dueDay: DateTime(2026, 10, 9),
      totalMarks: 20,
      passingMarks: 10.5,
      instructions: 'Show working',
      attachmentKeys: const ['k/1.pdf'],
    );

    test('create body is exactly the whitelisted DTO with MY staff id', () {
      final j = input.toCreateJson(teacherId: 'STAFF1', assign: true);
      expect(j, {
        'teacherId': 'STAFF1',
        'title': 'Worksheet',
        'subject': 'Mathematics',
        'gradeLevel': 'Grade 5',
        'sectionName': 'A',
        'type': 'classwork',
        'assignedDate': '2026-10-05',
        'dueDate': '2026-10-09',
        'totalMarks': 20,
        'passingMarks': 10.5,
        'status': 'assigned',
        'attachmentS3Keys': ['k/1.pdf'],
        'instructions': 'Show working',
      });
      expect(input.toCreateJson(teacherId: 'S', assign: false)['status'], 'draft');
    });

    test('whole-grade assignment omits sectionName; empty optionals are omitted', () {
      final j = AssignmentInput(title: 't', subject: 's', gradeLevel: 'Grade 5', assignedDay: DateTime(2026, 1, 1), dueDay: DateTime(2026, 1, 2))
          .toCreateJson(teacherId: 'S', assign: false);
      expect(j.containsKey('sectionName'), isFalse);
      expect(j.containsKey('description'), isFalse);
      expect(j.containsKey('attachmentS3Keys'), isFalse);
    });

    Assignment before({String status = 'draft'}) => Assignment.fromJson({
          '_id': 'a', 'teacherId': 'S', 'title': 'Worksheet', 'subject': 'Mathematics', 'gradeLevel': 'Grade 5', 'sectionName': 'A',
          'type': 'classwork', 'assignedDate': '2026-10-05T00:00:00.000Z', 'dueDate': '2026-10-09T00:00:00.000Z', 'totalMarks': 20,
          'passingMarks': 10.5, 'status': status, 'attachmentS3Keys': ['k/1.pdf'], 'instructions': 'Show working', 'description': '',
        });

    test('patch sends only what changed; never teacherId / campus', () {
      expect(input.toPatchJson(before()), isEmpty);
      final changed = AssignmentInput(
        title: 'New title', subject: 'Mathematics', gradeLevel: 'Grade 5', sectionName: 'A', type: AssignmentType.classwork,
        assignedDay: DateTime(2026, 10, 5), dueDay: DateTime(2026, 10, 12), totalMarks: 20, passingMarks: 10.5,
        instructions: 'Show working', attachmentKeys: const ['k/1.pdf', 'k/2.png'],
      );
      final p = changed.toPatchJson(before());
      expect(p, {'title': 'New title', 'dueDate': '2026-10-12', 'attachmentS3Keys': ['k/1.pdf', 'k/2.png']});
      expect(p.containsKey('teacherId'), isFalse);
    });

    test('assigned assignments cannot change class / subject / total marks through the app', () {
      final changed = AssignmentInput(
        title: 'Worksheet', subject: 'Science', gradeLevel: 'Grade 6', sectionName: 'B', type: AssignmentType.classwork,
        assignedDay: DateTime(2026, 10, 5), dueDay: DateTime(2026, 10, 9), totalMarks: 99, passingMarks: 10.5,
        instructions: 'Show working', attachmentKeys: const ['k/1.pdf'],
      );
      expect(changed.toPatchJson(before(status: 'assigned')), isEmpty);
      expect(changed.toPatchJson(before()).keys, containsAll(['subject', 'gradeLevel', 'sectionName', 'totalMarks']));
    });

    test('draft -> assigned is a status patch', () {
      expect(input.toPatchJson(before(), assign: true), {'status': 'assigned'});
      expect(input.toPatchJson(before(status: 'assigned'), assign: true), isEmpty);
    });
  });
}
