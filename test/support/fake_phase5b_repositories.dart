import 'package:eldermin_teacher_app/core/models/behaviour/behaviour_models.dart';
import 'package:eldermin_teacher_app/core/models/homework/homework_models.dart';
import 'package:eldermin_teacher_app/core/models/json_helpers.dart';
import 'package:eldermin_teacher_app/core/services/attachment_picker.dart';
import 'package:eldermin_teacher_app/core/services/behaviour_repository.dart';
import 'package:eldermin_teacher_app/core/services/homework_repository.dart';

Assignment asg(String id, {String title = 'Worksheet', String status = 'assigned', String? due = '2026-10-10', String teacherId = '64a0000000000000000000a1',
        String subject = 'Mathematics', String grade = 'Grade 5', String section = 'A', int count = 0, List<String> keys = const [], double total = 100, double passing = 50}) =>
    Assignment.fromJson({
      '_id': id,
      'teacherId': teacherId,
      'title': title,
      'subject': subject,
      'gradeLevel': grade,
      'sectionName': section,
      'status': status,
      'dueDate': due == null ? null : '${due}T00:00:00.000Z',
      'assignedDate': '2026-10-01T00:00:00.000Z',
      'totalMarks': total,
      'passingMarks': passing,
      'submissionsCount': count,
      'attachmentS3Keys': keys,
      'type': 'homework',
    });

Submission sub(String id, String status, {String name = 'Student', double max = 100, double? grade, bool late = false, String text = '', List<String> keys = const []}) =>
    Submission.fromJson({
      '_id': id,
      'assignmentId': 'a1',
      'studentId': 's$id',
      'studentName': name,
      'status': status,
      'isLate': late,
      'maxGrade': max,
      'grade': grade,
      'textResponse': text,
      'attachmentS3Keys': keys,
      'submittedAt': status == 'pending' || status == 'missed' ? null : '2026-10-04T09:30:00.000Z',
    });

class FakeHomeworkRepository extends HomeworkRepository {
  Future<List<Assignment>> Function(String staffId) mine = (_) async => [];
  Future<Assignment> Function(AssignmentInput input, String teacherId, bool assign) onCreate =
      (i, t, a) async => Assignment.fromJson({'_id': 'new1', 'teacherId': t, 'title': i.title, 'status': a ? 'assigned' : 'draft', 'dueDate': '${wireDay(i.dueDay)}T00:00:00.000Z', 'subject': i.subject, 'gradeLevel': i.gradeLevel, 'sectionName': i.sectionName});
  Future<Assignment> Function(String id, Map<String, Object?> patch) onUpdate = (id, p) async => Assignment.fromJson({'_id': id, ...p});
  Future<void> Function(String id) onDelete = (_) async {};
  Future<SubmissionsResult> Function(String id) subs = (id) async => SubmissionsResult(asg(id), const []);
  Future<Submission> Function(String aid, String sid, double grade, String? feedback) onGrade =
      (a, s, g, f) async => Submission.fromJson({'_id': s, 'status': 'graded', 'grade': g, 'maxGrade': 100});
  Future<UploadedFile> Function(String path, String name, void Function(int, int)? progress) onUpload =
      (p, n, pr) async => UploadedFile(key: 'demo/homework-attachments/$n', fileName: n);
  Future<String> Function(String key) onSigned = (k) async => 'https://files.example.test/$k?sig=1';

  final calls = <String>[];
  final created = <({AssignmentInput input, String teacherId, bool assign})>[];
  final patches = <Map<String, Object?>>[];
  final graded = <({String aid, String sid, double grade, String? feedback})>[];

  @override
  Future<List<Assignment>> fetchMine(String staffId) {
    calls.add('mine:$staffId');
    return mine(staffId);
  }

  @override
  Future<Assignment> create(AssignmentInput input, {required String teacherId, required bool assign}) {
    calls.add('create');
    created.add((input: input, teacherId: teacherId, assign: assign));
    return onCreate(input, teacherId, assign);
  }

  @override
  Future<Assignment> update(String id, Map<String, Object?> patch) {
    calls.add('update:$id');
    patches.add(patch);
    return onUpdate(id, patch);
  }

  @override
  Future<void> delete(String id) {
    calls.add('delete:$id');
    return onDelete(id);
  }

  @override
  Future<SubmissionsResult> fetchSubmissions(String assignmentId) {
    calls.add('subs:$assignmentId');
    return subs(assignmentId);
  }

  @override
  Future<Submission> grade(String assignmentId, String submissionId, {required double grade, String? feedback}) {
    calls.add('grade:$submissionId');
    graded.add((aid: assignmentId, sid: submissionId, grade: grade, feedback: feedback));
    return onGrade(assignmentId, submissionId, grade, feedback);
  }

  @override
  Future<UploadedFile> upload({required String path, required String fileName, String folder = HomeworkRepository.uploadFolder, void Function(int sent, int total)? onProgress}) {
    calls.add('upload:$fileName');
    return onUpload(path, fileName, onProgress);
  }

  @override
  Future<String> signedUrl(String key) {
    calls.add('signed:$key');
    return onSigned(key);
  }
}

class FakePicker implements AttachmentPicker {
  List<PickedAttachment> docs = [];
  List<PickedAttachment> photos = [];
  @override
  Future<List<PickedAttachment>> pickDocuments() async => docs;
  @override
  Future<List<PickedAttachment>> pickPhotos() async => photos;
}

class FakeBehaviourRepository extends BehaviourRepository {
  Future<List<BehaviourRecord>> Function(String grade) gradeRecords = (_) async => [];
  Future<List<BehaviourRecord>> Function(String studentId) studentRecords = (_) async => [];
  Future<BehaviourRecord> Function(Map<String, Object?> body) onCreate =
      (b) async => BehaviourRecord.fromJson({'_id': 'new1', ...b});
  Future<List<TarbiyahAssessment>> Function(String studentId) tarbiyah = (_) async => [];
  final calls = <String>[];
  final bodies = <Map<String, Object?>>[];

  @override
  Future<List<BehaviourRecord>> fetchGradeRecords(String rawGrade) {
    calls.add('grade:$rawGrade');
    return gradeRecords(rawGrade);
  }

  @override
  Future<List<BehaviourRecord>> fetchStudentRecords(String studentId) {
    calls.add('student:$studentId');
    return studentRecords(studentId);
  }

  @override
  Future<BehaviourRecord> create(Map<String, Object?> body) {
    calls.add('create');
    bodies.add(body);
    return onCreate(body);
  }

  @override
  Future<List<TarbiyahAssessment>> fetchTarbiyah(String studentId) {
    calls.add('tarbiyah:$studentId');
    return tarbiyah(studentId);
  }
}
