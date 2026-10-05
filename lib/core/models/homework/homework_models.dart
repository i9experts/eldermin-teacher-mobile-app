import '../json_helpers.dart';

/// Homework models, whitelisted from the real payloads (paths relative to eldermin-backend/src/, branch feat/staff-portal):
///  * Assignment  : modules/teaching/schemas/assignment.schema.ts:7-33
///  * Submission  : modules/teaching/schemas/assignment-submission.schema.ts:14-39
///  * Upload      : upload/upload.service.ts:34-69, upload/upload.controller.ts:20-31
/// Fields not listed here (tenantId, institutionId, campusId, teacherName, autoSpawnKey, gradedBy ...) are never parsed.

/// `type` enum of CreateAssignmentDto (assignment.dto.ts:5). The schema also allows `assessment` (assignment.schema.ts:20):
/// kept as a raw label when read, never offered for creation.
enum AssignmentType {
  homework('homework', 'Homework'),
  classwork('classwork', 'Classwork'),
  project('project', 'Project'),
  quiz('quiz', 'Quiz'),
  test('test', 'Test'),
  labWork('lab_work', 'Lab work'),
  presentation('presentation', 'Presentation'),
  other('other', 'Other');

  final String wire;
  final String label;
  const AssignmentType(this.wire, this.label);

  static AssignmentType? fromWire(String? v) {
    for (final t in values) {
      if (t.wire == v) return t;
    }
    return null;
  }
}

/// Where an assignment is for the teacher, derived from the stored status AND the due day (the server's daily cron only
/// flips `assigned -> overdue` at 01:00, TS:1056-1070, so a past-due `assigned` row is already overdue for the teacher).
enum HomeworkPhase { draft, active, dueToday, overdue, other }

class Assignment {
  final String id;
  final String teacherId;
  final String title;
  final String description;
  final String subject;
  final String gradeLevel;
  final String sectionName;
  final String typeWire;
  final DateTime? assignedDate;
  final DateTime? dueDate;
  final double totalMarks;
  final double passingMarks;

  /// draft | assigned | submitted | graded | overdue (assignment.schema.ts:23). Only draft/assigned are settable by a client.
  final String status;
  final int submissionsCount;
  final double avgScore;
  final List<String> attachmentKeys;
  final String instructions;

  const Assignment({
    required this.id,
    this.teacherId = '',
    this.title = '',
    this.description = '',
    this.subject = '',
    this.gradeLevel = '',
    this.sectionName = '',
    this.typeWire = 'homework',
    this.assignedDate,
    this.dueDate,
    this.totalMarks = 100,
    this.passingMarks = 50,
    this.status = 'draft',
    this.submissionsCount = 0,
    this.avgScore = 0,
    this.attachmentKeys = const [],
    this.instructions = '',
  });

  factory Assignment.fromJson(Map<String, dynamic> j) => Assignment(
        id: readId(j['_id'] ?? j['id']) ?? '',
        teacherId: readId(j['teacherId']) ?? '',
        title: readText(j['title']),
        description: readText(j['description']),
        subject: readText(j['subject']),
        gradeLevel: readText(j['gradeLevel']),
        sectionName: readText(j['sectionName']),
        typeWire: readString(j['type']) ?? 'homework',
        assignedDate: readDate(j['assignedDate']),
        dueDate: readDate(j['dueDate']),
        totalMarks: readNum(j['totalMarks']) ?? 100,
        passingMarks: readNum(j['passingMarks']) ?? 50,
        status: readString(j['status']) ?? 'draft',
        submissionsCount: readInt(j['submissionsCount']) ?? 0,
        avgScore: readNum(j['avgScore']) ?? 0,
        attachmentKeys: readStringList(j['attachmentS3Keys']),
        instructions: readText(j['instructions']),
      );

  Assignment copyWith({String? status, int? submissionsCount}) => Assignment(
        id: id,
        teacherId: teacherId,
        title: title,
        description: description,
        subject: subject,
        gradeLevel: gradeLevel,
        sectionName: sectionName,
        typeWire: typeWire,
        assignedDate: assignedDate,
        dueDate: dueDate,
        totalMarks: totalMarks,
        passingMarks: passingMarks,
        status: status ?? this.status,
        submissionsCount: submissionsCount ?? this.submissionsCount,
        avgScore: avgScore,
        attachmentKeys: attachmentKeys,
        instructions: instructions,
      );

  String get classLabel => [gradeLevel, sectionName].where((e) => e.isNotEmpty).join(' - ');
  AssignmentType? get type => AssignmentType.fromWire(typeWire);
  String get typeLabel => type?.label ?? (typeWire.isEmpty ? 'Homework' : typeWire[0].toUpperCase() + typeWire.substring(1));
  bool get isDraft => status == 'draft';

  /// The calendar day the assignment is due (see [storedCalendarDay]).
  DateTime? get dueDay => storedCalendarDay(dueDate);

  HomeworkPhase phaseOn(DateTime today) {
    if (isDraft) return HomeworkPhase.draft;
    if (status != 'assigned' && status != 'overdue') return HomeworkPhase.other;
    final due = dueDay;
    final t = DateTime(today.year, today.month, today.day);
    if (status == 'overdue') return HomeworkPhase.overdue;
    if (due == null) return HomeworkPhase.active;
    if (due.isBefore(t)) return HomeworkPhase.overdue;
    if (due == t) return HomeworkPhase.dueToday;
    return HomeworkPhase.active;
  }
}

/// `status` of a submission row (assignment-submission.schema.ts:21-25).
enum SubmissionState { pending, submitted, late, graded, missed, unknown }

class Submission {
  final String id;
  final String assignmentId;
  final String studentId;
  final String studentName;
  final String statusWire;
  final bool isLate;
  final String textResponse;
  final List<String> attachmentKeys;
  final DateTime? submittedAt;
  final double maxGrade;
  final double? grade;
  final String feedback;
  final DateTime? gradedAt;

  const Submission({
    required this.id,
    this.assignmentId = '',
    this.studentId = '',
    this.studentName = '',
    this.statusWire = 'pending',
    this.isLate = false,
    this.textResponse = '',
    this.attachmentKeys = const [],
    this.submittedAt,
    this.maxGrade = 100,
    this.grade,
    this.feedback = '',
    this.gradedAt,
  });

  factory Submission.fromJson(Map<String, dynamic> j) => Submission(
        id: readId(j['_id'] ?? j['id']) ?? '',
        assignmentId: readId(j['assignmentId']) ?? '',
        studentId: readId(j['studentId']) ?? '',
        studentName: readText(j['studentName']),
        statusWire: readString(j['status']) ?? 'pending',
        isLate: readBool(j['isLate']),
        textResponse: readText(j['textResponse']),
        attachmentKeys: readStringList(j['attachmentS3Keys']),
        submittedAt: readDate(j['submittedAt']),
        maxGrade: readNum(j['maxGrade']) ?? 100,
        grade: readNum(j['grade']),
        feedback: readText(j['feedback']),
        gradedAt: readDate(j['gradedAt']),
      );

  SubmissionState get state {
    switch (statusWire) {
      case 'pending':
        return SubmissionState.pending;
      case 'submitted':
        return SubmissionState.submitted;
      case 'late':
        return SubmissionState.late;
      case 'graded':
        return SubmissionState.graded;
      case 'missed':
        return SubmissionState.missed;
    }
    return SubmissionState.unknown;
  }

  /// Turned in (on time or late) and waiting for a mark (TS:1037).
  bool get needsGrading => state == SubmissionState.submitted || state == SubmissionState.late;
  bool get isGraded => state == SubmissionState.graded;

  /// Nothing handed in: still pending, or missed after the due date (TS:1062-1070).
  bool get notSubmitted => state == SubmissionState.pending || state == SubmissionState.missed;

  /// A late hand-in stays flagged after grading (assignment-submission.schema.ts:26-28).
  bool get wasLate => isLate || state == SubmissionState.late;
}

/// `GET /teaching/assignments/:id/submissions` -> `{ assignment, submissions[] }` (teaching.service.ts:990-1002).
class SubmissionsResult {
  final Assignment assignment;
  final List<Submission> submissions;
  const SubmissionsResult(this.assignment, this.submissions);

  factory SubmissionsResult.fromJson(Map<String, dynamic> j) => SubmissionsResult(
        Assignment.fromJson(asJsonMap(j['assignment'])),
        asJsonMapList(j['submissions']).map(Submission.fromJson).where((s) => s.id.isNotEmpty).toList(),
      );
}

/// `POST /upload/single/:folder` -> `{ success, data: { url, key, fileName, fileSize, fileType } }` (UC:30, US:34-69).
/// Only [key] is stored on the assignment (`attachmentS3Keys`); [url] is NOT used (public readability of the bucket is UNVERIFIED).
class UploadedFile {
  final String key;
  final String fileName;
  final int fileSize;
  final String fileType;
  const UploadedFile({required this.key, this.fileName = '', this.fileSize = 0, this.fileType = ''});

  /// Accepts the real `{success, data:{...}}` envelope and, defensively, a bare `{key,...}`. Null when there is no key.
  static UploadedFile? fromBody(Object? body) {
    final m = asJsonMap(body);
    final d = m['data'] is Map ? asJsonMap(m['data']) : m;
    final key = readString(d['key']);
    if (key == null) return null;
    return UploadedFile(
      key: key,
      fileName: readText(d['fileName']),
      fileSize: readInt(d['fileSize']) ?? 0,
      fileType: readText(d['fileType']),
    );
  }
}

/// Short label for an attachment key (`<slug>/<folder>/<uuid>.<ext>`): the original file name is NOT stored with the key.
String attachmentLabel(String key, int index) {
  final name = key.split('/').last;
  final dot = name.lastIndexOf('.');
  final ext = dot > 0 && dot < name.length - 1 ? name.substring(dot + 1).toUpperCase() : '';
  return ext.isEmpty ? 'Attachment ${index + 1}' : 'Attachment ${index + 1} ($ext)';
}

/// File types the app lets a teacher attach: the backend's own `ALLOWED_TYPES.any` (upload.service.ts:18-22). The route itself
/// applies NO type filter (getMulterConfig, US:101-113, is never wired), so this restriction is the app's choice.
const Map<String, String> kAttachmentMimeByExt = {
  'pdf': 'application/pdf',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'doc': 'application/msword',
  'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
};

/// 10 MB (upload.service.ts:17, upload.module.ts:11).
const int kMaxUploadBytes = 10 * 1024 * 1024;

String? attachmentMimeFor(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0) return null;
  return kAttachmentMimeByExt[fileName.substring(dot + 1).toLowerCase()];
}

/// The editable fields of an assignment (create form).
class AssignmentInput {
  final String title;
  final String description;
  final String subject;
  final String gradeLevel;
  final String sectionName;
  final AssignmentType type;
  final DateTime assignedDay;
  final DateTime dueDay;
  final double totalMarks;
  final double passingMarks;
  final String instructions;
  final List<String> attachmentKeys;

  const AssignmentInput({
    required this.title,
    this.description = '',
    required this.subject,
    required this.gradeLevel,
    this.sectionName = '',
    this.type = AssignmentType.homework,
    required this.assignedDay,
    required this.dueDay,
    this.totalMarks = 100,
    this.passingMarks = 50,
    this.instructions = '',
    this.attachmentKeys = const [],
  });

  static num _n(double v) => v == v.roundToDouble() ? v.round() : v;

  /// CreateAssignmentDto body (assignment.dto.ts:8-22). `teacherId` is the caller's OWN staffId (`GET /staff-portal/me`): the
  /// server takes it from the body (teaching.service.ts:874,887), never from the token. `status` is draft | assigned.
  Map<String, Object?> toCreateJson({required String teacherId, required bool assign}) => {
        'teacherId': teacherId,
        'title': title.trim(),
        if (description.trim().isNotEmpty) 'description': description.trim(),
        'subject': subject,
        'gradeLevel': gradeLevel,
        if (sectionName.isNotEmpty) 'sectionName': sectionName,
        'type': type.wire,
        'assignedDate': wireDay(assignedDay),
        'dueDate': wireDay(dueDay),
        'totalMarks': _n(totalMarks),
        'passingMarks': _n(passingMarks),
        'status': assign ? 'assigned' : 'draft',
        if (attachmentKeys.isNotEmpty) 'attachmentS3Keys': attachmentKeys,
        if (instructions.trim().isNotEmpty) 'instructions': instructions.trim(),
      };

  /// UpdateAssignmentDto body (assignment.dto.ts:30-43): ONLY the fields that differ from [before]; never teacherId / campus.
  /// Class and subject are only sent while the assignment is still a draft (changing them after the roster snapshot exists
  /// would not re-materialise submissions: teaching.service.ts:915-918). Returns an empty map when nothing changed.
  Map<String, Object?> toPatchJson(Assignment before, {bool assign = false}) {
    final out = <String, Object?>{};
    void put(String k, Object? v, Object? old) {
      if (v != old) out[k] = v;
    }

    put('title', title.trim(), before.title);
    put('description', description.trim(), before.description);
    put('instructions', instructions.trim(), before.instructions);
    put('type', type.wire, before.typeWire);
    final dueWire = wireDay(dueDay);
    final beforeDue = before.dueDay == null ? null : wireDay(before.dueDay!);
    put('dueDate', dueWire, beforeDue);
    final beforeAssigned = before.assignedDate == null ? null : wireDay(storedCalendarDay(before.assignedDate)!);
    put('assignedDate', wireDay(assignedDay), beforeAssigned);
    put('passingMarks', _n(passingMarks), _n(before.passingMarks));
    if (before.isDraft) {
      put('subject', subject, before.subject);
      put('gradeLevel', gradeLevel, before.gradeLevel);
      put('sectionName', sectionName, before.sectionName);
      put('totalMarks', _n(totalMarks), _n(before.totalMarks));
    }
    if (!_sameList(attachmentKeys, before.attachmentKeys)) out['attachmentS3Keys'] = attachmentKeys;
    if (assign && before.isDraft) out['status'] = 'assigned';
    return out;
  }

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
