import 'dart:convert';
import 'dart:io';
import 'package:eldermin_teacher_app/core/models/assessments/assessment_models.dart';
import 'package:eldermin_teacher_app/core/models/assessments/reference_models.dart';
import 'package:eldermin_teacher_app/core/models/classroom/student_models.dart';
import 'package:eldermin_teacher_app/core/models/paginated.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/services/assessment_repository.dart';
import 'package:eldermin_teacher_app/core/services/reference_repository.dart';

dynamic fx6b(String n) => jsonDecode(File('test/fixtures/phase6b/$n.json').readAsStringSync());

/// Assessment JSON as the server sends it (ASC:33-96), only what the app reads.
Assessment asm(
  String id, {
  String title = 'Unit Test',
  String type = 'unit_test',
  String grade = 'Grade 5',
  String? section = 'A',
  String status = 'ongoing',
  List<(String, num, num)> subjects = const [('Mathematics', 50, 20)],
  bool online = false,
  bool published = false,
  bool cards = false,
  String start = '2026-10-05',
  String year = '2026-27',
  String? paperOn,
}) =>
    Assessment.fromJson({
      '_id': id,
      'title': title,
      'type': type,
      'grade': grade,
      if (section != null) 'section': section,
      'academicYear': year,
      'term': 'Term 1',
      'status': status,
      'resultPublished': published,
      'gradeCardsGenerated': cards,
      'deliveryMode': online ? 'self_paced_online' : 'teacher_marked',
      'startDate': '${start}T00:00:00.000Z',
      'endDate': '${start}T00:00:00.000Z',
      'subjects': [
        for (final s in subjects) {'subject': s.$1, 'totalMarks': s.$2, 'passingMarks': s.$3, if (paperOn == s.$1) 'examPaperId': 'paper1'},
      ],
    });

/// Mark entry JSON (ASC:165-200).
MarkRecord mark(StudentSummary s, num? obtained, {bool absent = false, bool exempt = false, bool verified = false, bool quiz = false, String remarks = ''}) => MarkRecord.fromJson({
      '_id': 'm${s.id}',
      'assessmentId': 'a1',
      'studentId': s.id,
      'studentName': s.fullName,
      'rollNumber': s.rollNumber,
      'subject': 'Mathematics',
      'totalMarks': 50,
      'obtainedMarks': obtained,
      'isAbsent': absent,
      'isExempt': exempt,
      'remarks': remarks,
      'verified': verified,
      'enteredBy': quiz ? 'Online Quiz (auto)' : 'Tess Teacher',
    });

typedef SaveCall = ({String assessmentId, String subject, String grade, List<Map<String, Object?>> marks, String? year});

class FakeAssessmentRepository extends AssessmentRepository {
  Future<AllPages<Assessment>> Function() onList = () async => const AllPages([]);
  Future<Assessment> Function(String id)? onOne;
  Future<AllPages<MarkRecord>> Function(String assessmentId, String subject) onMarks = (_, __) async => const AllPages([]);
  Future<void> Function(SaveCall call)? onSave;
  Future<AllPages<ReportCard>> Function(String assessmentId) onCards = (_) async => const AllPages([]);
  Future<ReportCard> Function(String id, String text)? onRemarks;
  Future<List<QuizAttempt>> Function() onPending = () async => [];
  Future<QuizAttempt> Function(String id)? onAttempt;
  Future<QuizAttempt> Function(String id, List<({String questionId, double marks})> grades)? onGrade;

  final calls = <String>[];
  final saves = <SaveCall>[];
  final remarks = <({String id, String text})>[];
  final grades = <({String id, List<({String questionId, double marks})> grades})>[];

  @override
  Future<AllPages<Assessment>> listAssessments() {
    calls.add('list');
    return onList();
  }

  @override
  Future<Assessment> assessment(String id) {
    calls.add('one:$id');
    return onOne != null ? onOne!(id) : Future.error(ApiException('Assessment not found', statusCode: 404));
  }

  @override
  Future<AllPages<MarkRecord>> marks(String assessmentId, String subject) {
    calls.add('marks:$assessmentId:$subject');
    return onMarks(assessmentId, subject);
  }

  @override
  Future<void> saveMarks({required String assessmentId, required String subject, required String grade, required List<MarkWrite> marks, String? academicYear}) {
    final call = (assessmentId: assessmentId, subject: subject, grade: grade, marks: [for (final m in marks) m.toJson()], year: academicYear);
    saves.add(call);
    calls.add('save');
    return onSave != null ? onSave!(call) : Future.value();
  }

  @override
  Future<AllPages<ReportCard>> reportCards(String assessmentId) {
    calls.add('cards:$assessmentId');
    return onCards(assessmentId);
  }

  @override
  Future<ReportCard> saveRemarks(String id, String classTeacherRemarks) {
    remarks.add((id: id, text: classTeacherRemarks));
    calls.add('remarks:$id');
    return onRemarks != null ? onRemarks!(id, classTeacherRemarks) : Future.value(ReportCard.fromJson({'_id': id, 'classTeacherRemarks': classTeacherRemarks}));
  }

  @override
  Future<List<QuizAttempt>> pendingAttempts() {
    calls.add('pending');
    return onPending();
  }

  @override
  Future<QuizAttempt> attempt(String id) {
    calls.add('attempt:$id');
    return onAttempt != null ? onAttempt!(id) : Future.error(ApiException('Quiz attempt not found', statusCode: 404));
  }

  @override
  Future<QuizAttempt> gradeAttempt(String id, List<({String questionId, double marks})> g) {
    grades.add((id: id, grades: g));
    calls.add('grade:$id');
    return onGrade != null ? onGrade!(id, g) : Future.error(ApiException('no grade handler', statusCode: 500));
  }
}

class FakeReferenceRepository extends ReferenceRepository {
  Future<List<Curriculum>> Function() onCurricula = () async => [];
  Future<Curriculum> Function(String id)? onCurriculum;
  Future<Paginated<Book>> Function(String search, String category, bool availableOnly, int page)? onBooks;

  final calls = <String>[];
  final bookQueries = <({String search, String category, bool available, int page})>[];

  @override
  Future<List<Curriculum>> curricula() {
    calls.add('curricula');
    return onCurricula();
  }

  @override
  Future<Curriculum> curriculum(String id) {
    calls.add('curriculum:$id');
    return onCurriculum != null ? onCurriculum!(id) : Future.error(ApiException('Curriculum not found', statusCode: 404));
  }

  @override
  Future<Paginated<Book>> books({String search = '', String category = '', bool availableOnly = false, int page = 1}) {
    bookQueries.add((search: search, category: category, available: availableOnly, page: page));
    calls.add('books:$page');
    return onBooks != null ? onBooks!(search, category, availableOnly, page) : Future.value(const Paginated<Book>());
  }
}

List<Assessment> fixtureAssessments() => Paginated<Assessment>.fromJson(fx6b('assessments'), Assessment.fromJson).items;
