import '../json_helpers.dart';

/// `GET /teaching/assignments` item (assignment.schema.ts:7-33, verified).
class HomeworkAssignment {
  final String id;
  final String? teacherId;
  final String title;
  final String subject;
  final String gradeLevel;
  final String sectionName;
  final DateTime? dueDate;
  final String status; // draft|assigned|submitted|graded|overdue (S/AS:23)
  /// Counts submitted + late + graded (INCLUDES already graded: TS:1033-1044).
  final int submissionsCount;

  const HomeworkAssignment({
    required this.id,
    this.teacherId,
    this.title = '',
    this.subject = '',
    this.gradeLevel = '',
    this.sectionName = '',
    this.dueDate,
    this.status = '',
    this.submissionsCount = 0,
  });

  factory HomeworkAssignment.fromJson(Map<String, dynamic> j) => HomeworkAssignment(
        id: readId(j['_id'] ?? j['id']) ?? '',
        teacherId: readId(j['teacherId']),
        title: readText(j['title']),
        subject: readText(j['subject']),
        gradeLevel: readText(j['gradeLevel']),
        sectionName: readText(j['sectionName']),
        dueDate: readDate(j['dueDate']),
        status: readText(j['status']),
        submissionsCount: readInt(j['submissionsCount']) ?? 0,
      );

  String get classLabel => [gradeLevel, sectionName].where((e) => e.isNotEmpty).join(' - ');
}

/// `GET /teaching/assignments/:id/submissions` -> `submissions[]` (S/SUB, verified).
class HomeworkSubmission {
  final String id;
  final String status; // pending|submitted|late|graded|missed (S/SUB:21-25)
  const HomeworkSubmission({required this.id, this.status = ''});

  factory HomeworkSubmission.fromJson(Map<String, dynamic> j) =>
      HomeworkSubmission(id: readId(j['_id'] ?? j['id']) ?? '', status: readText(j['status']));

  /// Waiting for the teacher: turned in (on time or late) but not yet graded (TS:1037).
  bool get isUngraded => status == 'submitted' || status == 'late';
}

/// `GET /teaching/lesson-plans` item (lesson-plan.schema.ts, verified).
/// NOTE: the schema has NO `title`; the name of a plan is `topic` (S/LP:19).
class LessonPlan {
  final String id;
  final String? teacherId;
  final String topic;
  final String subject;
  final String gradeLevel;
  final String sectionName;
  final DateTime? planDate;
  final String status; // draft|submitted|approved|rejected|overdue
  final String? rejectionReason;

  const LessonPlan({
    required this.id,
    this.teacherId,
    this.topic = '',
    this.subject = '',
    this.gradeLevel = '',
    this.sectionName = '',
    this.planDate,
    this.status = '',
    this.rejectionReason,
  });

  factory LessonPlan.fromJson(Map<String, dynamic> j) {
    final status = readText(j['status']);
    return LessonPlan(
      id: readId(j['_id'] ?? j['id']) ?? '',
      teacherId: readId(j['teacherId']),
      topic: readText(j['topic']),
      subject: readText(j['subject']),
      gradeLevel: readText(j['gradeLevel']),
      sectionName: readText(j['sectionName']),
      planDate: readDate(j['planDate']),
      status: status,
      // A stale reason can survive on a re-submitted plan (TS:179-185): only
      // keep it for a rejected plan.
      rejectionReason: status == 'rejected' ? readString(j['rejectionReason']) : null,
    );
  }

  String get classLabel => [gradeLevel, sectionName].where((e) => e.isNotEmpty).join(' - ');
}

/// PTM meeting (ptm-meeting.schema.ts, verified).
class PtmMeeting {
  final String id;
  final String studentName;
  final String gradeLevel;
  final String sectionName;
  final String? teacherId;
  final DateTime? scheduledDate;
  /// Format not constrained by the schema beyond spec examples (U8).
  final String startTime;
  final String endTime;
  final String guardianName;
  final String status; // requested|confirmed|completed|cancelled|no_show

  const PtmMeeting({
    required this.id,
    this.studentName = '',
    this.gradeLevel = '',
    this.sectionName = '',
    this.teacherId,
    this.scheduledDate,
    this.startTime = '',
    this.endTime = '',
    this.guardianName = '',
    this.status = '',
  });

  factory PtmMeeting.fromJson(Map<String, dynamic> j) => PtmMeeting(
        id: readId(j['_id'] ?? j['id']) ?? '',
        studentName: readText(j['studentName']),
        gradeLevel: readText(j['gradeLevel']),
        sectionName: readText(j['sectionName']),
        teacherId: readId(j['teacherId']),
        scheduledDate: readDate(j['scheduledDate']),
        startTime: readText(j['startTime']),
        endTime: readText(j['endTime']),
        guardianName: readText(j['guardianName']),
        status: readText(j['status']),
      );

  String get classLabel => [gradeLevel, sectionName].where((e) => e.isNotEmpty).join(' - ');
  String get timeRange => [startTime, endTime].where((e) => e.isNotEmpty).join(' - ');
}

/// Substitution / "fixture" (substitution.schema.ts, verified).
class Substitution {
  final String id;
  final DateTime? date;
  final int? periodNo;
  final String startTime;
  final String endTime;
  final String gradeLevel;
  final String sectionName;
  final String subject;
  final String roomNo;
  final String? originalTeacherId;
  final String originalTeacherName;
  final String? substituteTeacherId;
  final String substituteTeacherName;
  final String status; // open|assigned|completed|cancelled

  const Substitution({
    required this.id,
    this.date,
    this.periodNo,
    this.startTime = '',
    this.endTime = '',
    this.gradeLevel = '',
    this.sectionName = '',
    this.subject = '',
    this.roomNo = '',
    this.originalTeacherId,
    this.originalTeacherName = '',
    this.substituteTeacherId,
    this.substituteTeacherName = '',
    this.status = '',
  });

  factory Substitution.fromJson(Map<String, dynamic> j) => Substitution(
        id: readId(j['_id'] ?? j['id']) ?? '',
        date: readDate(j['date']),
        periodNo: readInt(j['periodNo']),
        startTime: readText(j['startTime']),
        endTime: readText(j['endTime']),
        gradeLevel: readText(j['gradeLevel']),
        sectionName: readText(j['sectionName']),
        subject: readText(j['subject']),
        roomNo: readText(j['roomNo']),
        originalTeacherId: readId(j['originalTeacherId']),
        originalTeacherName: readText(j['originalTeacherName']),
        substituteTeacherId: readId(j['substituteTeacherId']),
        substituteTeacherName: readText(j['substituteTeacherName']),
        status: readText(j['status']),
      );

  String get classLabel => [gradeLevel, sectionName].where((e) => e.isNotEmpty).join(' - ');
}
