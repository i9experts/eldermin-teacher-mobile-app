import '../json_helpers.dart';

/// Assessment, marks, report-card and quiz models, WHITELISTED from the real payloads (paths relative to eldermin-backend/src/assessments/,
/// branch feat/staff-portal): schemas/assessment.schema.ts (ASC), schemas/quiz-attempt.schema.ts (QA), assessment.controller.ts (AC),
/// assessment.service.ts (AS). Never parsed: gradingScale, createdBy, schoolSlug, campusId, resultPublishedBy, enteredBy of other
/// people's rows beyond the "Online Quiz" marker, academicYear on marks, percentage details beyond what is shown.

/// `10`, `7.5`, `7.25` (up to two decimals, trailing zeros trimmed).
String marksText(num v) {
  final r = (v * 100).round() / 100;
  if (r == r.roundToDouble()) return r.round().toString();
  final s = r.toStringAsFixed(2);
  return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
}

const assessmentTypeLabels = {
  'quiz': 'Quiz',
  'class_test': 'Class test',
  'unit_test': 'Unit test',
  'mid_term': 'Mid-term',
  'final_exam': 'Final exam',
  'assignment': 'Assignment',
  'project': 'Project',
  'practical': 'Practical',
  'oral': 'Oral',
};

String assessmentTypeLabel(String type) => assessmentTypeLabels[type] ?? (type.isEmpty ? 'Assessment' : type.replaceAll('_', ' '));

/// `SubjectConfig` (ASC:13-30).
class AssessmentSubject {
  final String subject;
  final double totalMarks;
  final double passingMarks;
  final String examiner;
  final DateTime? date;
  final String startTime;
  final int? duration;
  final String venue;

  /// A quiz paper is linked (`examPaperId` set): marks come from the online quiz (ASC:23-29). Only the presence is kept.
  final bool hasQuizPaper;

  const AssessmentSubject({
    required this.subject,
    this.totalMarks = 0,
    this.passingMarks = 0,
    this.examiner = '',
    this.date,
    this.startTime = '',
    this.duration,
    this.venue = '',
    this.hasQuizPaper = false,
  });

  factory AssessmentSubject.fromJson(Map<String, dynamic> j) => AssessmentSubject(
        subject: readText(j['subject']),
        totalMarks: readNum(j['totalMarks']) ?? 0,
        passingMarks: readNum(j['passingMarks']) ?? 0,
        examiner: readText(j['examiner']),
        date: storedCalendarDay(readDate(j['date'])),
        startTime: readText(j['startTime']),
        duration: readInt(j['duration']),
        venue: readText(j['venue']),
        hasQuizPaper: readString(readId(j['examPaperId'])) != null,
      );
}

/// Assessment status values (ASC:56-60).
class AssessmentStatus {
  static const draft = 'draft';
  static const scheduled = 'scheduled';
  static const ongoing = 'ongoing';
  static const completed = 'completed';
  static const published = 'result_published';
  static const cancelled = 'cancelled';
}

class Assessment {
  final String id;
  final String title;
  final String description;
  final String type;
  final String grade;

  /// '' = all sections (ASC:46 "null = all sections").
  final String section;
  final String academicYear;
  final String term;
  final List<AssessmentSubject> subjects;

  /// The calendar day the assessment starts (stored UTC midnight of the chosen day, see [storedCalendarDay]).
  final DateTime? startDate;
  final DateTime? endDate;
  final String status;
  final bool resultPublished;
  final bool gradeCardsGenerated;

  /// `deliveryMode == 'self_paced_online'` (ASC:74): students take the quiz themselves.
  final bool isOnline;

  const Assessment({
    required this.id,
    this.title = '',
    this.description = '',
    this.type = '',
    this.grade = '',
    this.section = '',
    this.academicYear = '',
    this.term = '',
    this.subjects = const [],
    this.startDate,
    this.endDate,
    this.status = '',
    this.resultPublished = false,
    this.gradeCardsGenerated = false,
    this.isOnline = false,
  });

  factory Assessment.fromJson(Map<String, dynamic> j) => Assessment(
        id: readId(j['_id'] ?? j['id']) ?? '',
        title: readText(j['title']),
        description: readText(j['description']),
        type: readText(j['type']),
        grade: readText(j['grade']),
        section: readText(j['section']),
        academicYear: readText(j['academicYear']),
        term: readText(j['term']),
        subjects: asJsonMapList(j['subjects']).map(AssessmentSubject.fromJson).where((s) => s.subject.isNotEmpty).toList(),
        startDate: storedCalendarDay(readDate(j['startDate'])),
        endDate: storedCalendarDay(readDate(j['endDate'])),
        status: readText(j['status']),
        resultPublished: readBool(j['resultPublished']),
        gradeCardsGenerated: readBool(j['gradeCardsGenerated']),
        isOnline: readText(j['deliveryMode']) == 'self_paced_online',
      );

  AssessmentSubject? subjectNamed(String name) {
    final n = name.trim().toLowerCase();
    for (final s in subjects) {
      if (s.subject.trim().toLowerCase() == n) return s;
    }
    return null;
  }

  String get classLabel => section.isEmpty ? grade : '$grade - $section';
  bool get isResultPublished => resultPublished || status == AssessmentStatus.published;
}

/// One row of `GET /assessments/marks/list` (MarkEntry, ASC:165-200).
class MarkRecord {
  final String id;
  final String assessmentId;
  final String studentId;
  final String studentName;
  final String rollNumber;
  final String section;
  final String subject;
  final double totalMarks;
  final double? obtainedMarks;
  final bool isAbsent;
  final bool isExempt;
  final double? percentage;
  final String result;
  final String remarks;

  /// Locked: a coordinator verified this row (ASC:196). The SERVER does not enforce it (AS:1239-1299); the app does.
  final bool verified;

  /// Written by the online quiz completion (`enteredBy: 'Online Quiz (auto)'`, AS:1523-1544): not a teacher's entry.
  final bool fromOnlineQuiz;

  const MarkRecord({
    required this.studentId,
    this.id = '',
    this.assessmentId = '',
    this.studentName = '',
    this.rollNumber = '',
    this.section = '',
    this.subject = '',
    this.totalMarks = 0,
    this.obtainedMarks,
    this.isAbsent = false,
    this.isExempt = false,
    this.percentage,
    this.result = '',
    this.remarks = '',
    this.verified = false,
    this.fromOnlineQuiz = false,
  });

  factory MarkRecord.fromJson(Map<String, dynamic> j) => MarkRecord(
        id: readId(j['_id'] ?? j['id']) ?? '',
        assessmentId: readId(j['assessmentId']) ?? '',
        studentId: readId(j['studentId']) ?? '',
        studentName: readText(j['studentName']),
        rollNumber: readText(j['rollNumber']),
        section: readText(j['section']),
        subject: readText(j['subject']),
        totalMarks: readNum(j['totalMarks']) ?? 0,
        obtainedMarks: readNum(j['obtainedMarks']),
        isAbsent: readBool(j['isAbsent']),
        isExempt: readBool(j['isExempt']),
        percentage: readNum(j['percentage']),
        result: readText(j['result']),
        remarks: readText(j['remarks']),
        verified: readBool(j['verified']),
        fromOnlineQuiz: readText(j['enteredBy']).toLowerCase().startsWith('online quiz'),
      );

  /// Has anything been entered at all (a number, absent or exempt)?
  bool get hasEntry => obtainedMarks != null || isAbsent || isExempt;
}

/// One subject line of a report card (ASC:212-222).
class ReportSubject {
  final String subject;
  final double totalMarks;
  final double obtainedMarks;
  final String grade;
  final String result;

  const ReportSubject({required this.subject, this.totalMarks = 0, this.obtainedMarks = 0, this.grade = '', this.result = ''});

  factory ReportSubject.fromJson(Map<String, dynamic> j) => ReportSubject(
        subject: readText(j['subject']),
        totalMarks: readNum(j['totalMarks']) ?? 0,
        obtainedMarks: readNum(j['obtainedMarks']) ?? 0,
        grade: readText(j['grade']),
        result: readText(j['result']),
      );
}

/// Report card (ASC:225-264). Remarks: `classTeacherRemarks` is the class teacher's; `principalRemarks` is shown read-only.
class ReportCard {
  final String id;
  final String assessmentId;
  final String assessmentTitle;
  final String studentId;
  final String studentName;
  final String rollNumber;
  final String grade;
  final String section;
  final List<ReportSubject> subjects;
  final double? overallPercentage;
  final String overallGrade;
  final String overallResult;
  final int? classPosition;
  final int? totalStudents;
  final String classTeacherRemarks;
  final String principalRemarks;
  final bool published;

  const ReportCard({
    required this.id,
    this.assessmentId = '',
    this.assessmentTitle = '',
    this.studentId = '',
    this.studentName = '',
    this.rollNumber = '',
    this.grade = '',
    this.section = '',
    this.subjects = const [],
    this.overallPercentage,
    this.overallGrade = '',
    this.overallResult = '',
    this.classPosition,
    this.totalStudents,
    this.classTeacherRemarks = '',
    this.principalRemarks = '',
    this.published = false,
  });

  factory ReportCard.fromJson(Map<String, dynamic> j) => ReportCard(
        id: readId(j['_id'] ?? j['id']) ?? '',
        assessmentId: readId(j['assessmentId']) ?? '',
        assessmentTitle: readText(j['assessmentTitle']),
        studentId: readId(j['studentId']) ?? '',
        studentName: readText(j['studentName']),
        rollNumber: readText(j['rollNumber']),
        grade: readText(j['grade']),
        section: readText(j['section']),
        subjects: asJsonMapList(j['subjects']).map(ReportSubject.fromJson).toList(),
        overallPercentage: readNum(j['overallPercentage']),
        overallGrade: readText(j['overallGrade']),
        overallResult: readText(j['overallResult']),
        classPosition: readInt(j['classPosition']),
        totalStudents: readInt(j['totalStudents']),
        classTeacherRemarks: readText(j['classTeacherRemarks']),
        principalRemarks: readText(j['principalRemarks']),
        published: readBool(j['published']),
      );

  ReportCard withClassTeacherRemarks(String v) => ReportCard(
        id: id,
        assessmentId: assessmentId,
        assessmentTitle: assessmentTitle,
        studentId: studentId,
        studentName: studentName,
        rollNumber: rollNumber,
        grade: grade,
        section: section,
        subjects: subjects,
        overallPercentage: overallPercentage,
        overallGrade: overallGrade,
        overallResult: overallResult,
        classPosition: classPosition,
        totalStudents: totalStudents,
        classTeacherRemarks: v,
        principalRemarks: principalRemarks,
        published: published,
      );
}

/// A question hydrated by `GET /quiz-attempts/:id` (AS:1475-1484: the WHOLE question, answer key included: a teacher route).
class QuizQuestion {
  final String id;
  final String type;
  final String text;
  final double marks;
  final List<({String text, bool isCorrect})> options;
  final String correctAnswer;
  final String explanation;

  const QuizQuestion({required this.id, this.type = '', this.text = '', this.marks = 0, this.options = const [], this.correctAnswer = '', this.explanation = ''});

  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
        id: readId(j['_id'] ?? j['id']) ?? '',
        type: readText(j['type']),
        text: readText(j['questionText']),
        marks: readNum(j['marks']) ?? 0,
        options: [for (final o in asJsonMapList(j['options'])) (text: readText(o['text']), isCorrect: readBool(o['isCorrect']))],
        correctAnswer: readText(j['correctAnswer']),
        explanation: readText(j['answerExplanation']),
      );
}

/// One answer of an attempt (QA:16-24).
class QuizAnswer {
  final String questionId;
  final int? selectedOptionIndex;
  final String textAnswer;
  final bool needsManualGrading;
  final bool? isCorrect;
  final double? marksAwarded;
  final QuizQuestion? question;

  const QuizAnswer({required this.questionId, this.selectedOptionIndex, this.textAnswer = '', this.needsManualGrading = false, this.isCorrect, this.marksAwarded, this.question});

  factory QuizAnswer.fromJson(Map<String, dynamic> j) {
    final q = j['question'];
    return QuizAnswer(
      questionId: readId(j['questionId']) ?? '',
      selectedOptionIndex: readInt(j['selectedOptionIndex']),
      textAnswer: readText(j['textAnswer']),
      needsManualGrading: readBool(j['needsManualGrading']),
      isCorrect: j['isCorrect'] is bool ? j['isCorrect'] as bool : null,
      marksAwarded: readNum(j['marksAwarded']),
      question: q is Map ? QuizQuestion.fromJson(asJsonMap(q)) : null,
    );
  }
}

/// A student's quiz attempt (QA:28-60). Statuses: in_progress | submitted (waiting for a teacher) | graded.
class QuizAttempt {
  final String id;
  final String studentId;
  final String studentName;
  final String rollNumber;
  final String assessmentId;
  final String assessmentTitle;
  final String subject;
  final String grade;
  final String section;
  final double totalMarks;
  final double passingMarks;
  final double autoGradedMarks;
  final double? obtainedMarks;
  final String status;
  final int attemptNumber;
  final DateTime? submittedAt;
  final List<QuizAnswer> answers;

  const QuizAttempt({
    required this.id,
    this.studentId = '',
    this.studentName = '',
    this.rollNumber = '',
    this.assessmentId = '',
    this.assessmentTitle = '',
    this.subject = '',
    this.grade = '',
    this.section = '',
    this.totalMarks = 0,
    this.passingMarks = 0,
    this.autoGradedMarks = 0,
    this.obtainedMarks,
    this.status = '',
    this.attemptNumber = 1,
    this.submittedAt,
    this.answers = const [],
  });

  factory QuizAttempt.fromJson(Map<String, dynamic> j) => QuizAttempt(
        id: readId(j['_id'] ?? j['id']) ?? '',
        studentId: readId(j['studentId']) ?? '',
        studentName: readText(j['studentName']),
        rollNumber: readText(j['rollNumber']),
        assessmentId: readId(j['assessmentId']) ?? '',
        assessmentTitle: readText(j['assessmentTitle']),
        subject: readText(j['subject']),
        grade: readText(j['grade']),
        section: readText(j['section']),
        totalMarks: readNum(j['totalMarks']) ?? 0,
        passingMarks: readNum(j['passingMarks']) ?? 0,
        autoGradedMarks: readNum(j['autoGradedMarks']) ?? 0,
        obtainedMarks: readNum(j['obtainedMarks']),
        status: readText(j['status']),
        attemptNumber: readInt(j['attemptNumber']) ?? 1,
        submittedAt: readDate(j['submittedAt']),
        answers: asJsonMapList(j['answers']).map(QuizAnswer.fromJson).toList(),
      );

  bool get isPending => status == 'submitted';
  bool get isGraded => status == 'graded';
  List<QuizAnswer> get manualAnswers => answers.where((a) => a.needsManualGrading).toList();
  int get pendingCount => manualAnswers.where((a) => a.marksAwarded == null).length;
  String get classLabel => section.isEmpty ? grade : '$grade - $section';
}
