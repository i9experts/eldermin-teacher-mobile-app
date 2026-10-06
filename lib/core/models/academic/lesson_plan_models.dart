import '../json_helpers.dart';

/// Lesson plan models, whitelisted from the real payloads (paths relative to eldermin-backend/src/, branch feat/staff-portal, HEAD 62db9f8):
///  * LessonPlan document : modules/teaching/schemas/lesson-plan.schema.ts:7-42
///  * create / patch      : modules/teaching/teaching.service.ts:164-207 (no DTO: body `any`)
///  * parse-upload result : modules/teaching/teaching.service.ts:294-379
/// Never parsed: tenantId, institutionId, campusId, academicYearId, approvedBy (a User id), sloTags, weekNumber, syllabusPageFrom/To, reflection.

/// `status` enum (lesson-plan.schema.ts:38).
enum LessonPlanStatus {
  draft('draft', 'Draft'),
  submitted('submitted', 'Awaiting approval'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Rejected'),
  overdue('overdue', 'Overdue'),
  unknown('', 'Unknown');

  final String wire;
  final String label;
  const LessonPlanStatus(this.wire, this.label);

  static LessonPlanStatus fromWire(String? v) {
    for (final s in values) {
      if (s.wire == v && v != null && v.isNotEmpty) return s;
    }
    return unknown;
  }
}

/// The six resources the web form (and the parse-upload prompt) know (teaching.service.ts:223).
const List<String> kLessonResources = ['Textbook', 'Whiteboard', 'Projector', 'Lab Equipment', 'Handouts', 'Video'];

/// Teaching methodologies of the web form (LessonPlansTab.tsx:13-20) and of parse-upload (teaching.service.ts:222).
const Map<String, String> kLessonMethodologies = {
  'lecture': 'Lecture',
  'discussion': 'Discussion',
  'activity': 'Activity / lab',
  'demo': 'Demo',
  'project': 'Project',
  'flipped': 'Flipped',
};

class LessonPlanRecord {
  final String id;

  /// Staff._id (lesson-plan.schema.ts:9). Legacy rows written by the web may hold a TeacherProfile._id (UNVERIFIED in real data).
  final String teacherId;
  final String teacherName;
  final String subject;
  final String gradeLevel;
  final String sectionName;

  /// The plan's name. There is NO `title` field (lesson-plan.schema.ts:19).
  final String topic;
  final String description;
  final DateTime? planDate;
  final int? durationMins;
  final List<String> learningObjectives;
  final List<String> resources;
  final String teachingMethodology;
  final String priorKnowledge;
  final String activities;
  final String assessment;
  final String homework;
  final LessonPlanStatus status;

  /// Only kept when [status] is `rejected`: the server never clears it on edit / resubmit (teaching.service.ts:191-207 raw `$set`).
  final String? rejectionReason;

  /// Only kept when [status] is `approved` (same reason).
  final String? approverNotes;
  final DateTime? updatedAt;

  const LessonPlanRecord({
    required this.id,
    this.teacherId = '',
    this.teacherName = '',
    this.subject = '',
    this.gradeLevel = '',
    this.sectionName = '',
    this.topic = '',
    this.description = '',
    this.planDate,
    this.durationMins,
    this.learningObjectives = const [],
    this.resources = const [],
    this.teachingMethodology = '',
    this.priorKnowledge = '',
    this.activities = '',
    this.assessment = '',
    this.homework = '',
    this.status = LessonPlanStatus.draft,
    this.rejectionReason,
    this.approverNotes,
    this.updatedAt,
  });

  factory LessonPlanRecord.fromJson(Map<String, dynamic> j) {
    final status = LessonPlanStatus.fromWire(readString(j['status']));
    return LessonPlanRecord(
      id: readId(j['_id'] ?? j['id']) ?? '',
      teacherId: readId(j['teacherId']) ?? '',
      teacherName: readText(j['teacherName']),
      subject: readText(j['subject']),
      gradeLevel: readText(j['gradeLevel']),
      sectionName: readText(j['sectionName']),
      topic: readText(j['topic']),
      description: readText(j['description']),
      planDate: readDate(j['planDate']),
      durationMins: readInt(j['durationMins']),
      learningObjectives: readStringList(j['learningObjectives']),
      resources: readStringList(j['resources']),
      teachingMethodology: readText(j['teachingMethodology']),
      priorKnowledge: readText(j['priorKnowledge']),
      activities: readText(j['activities']),
      assessment: readText(j['assessment']),
      homework: readText(j['homework']),
      status: status,
      rejectionReason: status == LessonPlanStatus.rejected ? readString(j['rejectionReason']) : null,
      approverNotes: status == LessonPlanStatus.approved ? readString(j['approverNotes']) : null,
      updatedAt: readDate(j['updatedAt']),
    );
  }

  String get classLabel => [gradeLevel, sectionName].where((e) => e.isNotEmpty).join(' - ');

  /// The calendar day the plan is for (the web sends `YYYY-MM-DD` = stored as UTC midnight; see [storedCalendarDay]).
  DateTime? get planDay => storedCalendarDay(planDate);

  /// A teacher may edit a plan that is not under review and not approved. A rejected plan is edited and resubmitted (the web does
  /// exactly that: "Edit & Resubmit", LessonPlansTab.tsx); nothing server-side forbids any of it (no status check in the raw `$set`).
  bool get canEdit => status == LessonPlanStatus.draft || status == LessonPlanStatus.rejected || status == LessonPlanStatus.overdue;

  /// `PATCH {status:'submitted'}` is the ONLY way to submit (there is no dedicated route; teaching.controller.ts:80-82).
  bool get canSubmit => status == LessonPlanStatus.draft || status == LessonPlanStatus.overdue;

  LessonPlanRecord copyWith({LessonPlanStatus? status}) => LessonPlanRecord(
        id: id,
        teacherId: teacherId,
        teacherName: teacherName,
        subject: subject,
        gradeLevel: gradeLevel,
        sectionName: sectionName,
        topic: topic,
        description: description,
        planDate: planDate,
        durationMins: durationMins,
        learningObjectives: learningObjectives,
        resources: resources,
        teachingMethodology: teachingMethodology,
        priorKnowledge: priorKnowledge,
        activities: activities,
        assessment: assessment,
        homework: homework,
        status: status ?? this.status,
        rejectionReason: rejectionReason,
        approverNotes: approverNotes,
        updatedAt: updatedAt,
      );
}

/// What the form edits. Used for create (whole body) and edit (only the CHANGED fields: the update is a raw `$set`, so anything
/// else would overwrite server state).
class LessonPlanInput {
  final String subject;
  final String gradeLevel;
  final String sectionName;
  final String topic;
  final String description;
  final DateTime planDay;
  final int? durationMins;
  final String methodology;
  final List<String> objectives;
  final List<String> resources;
  final String priorKnowledge;
  final String activities;
  final String assessment;
  final String homework;

  const LessonPlanInput({
    required this.subject,
    required this.gradeLevel,
    this.sectionName = '',
    required this.topic,
    this.description = '',
    required this.planDay,
    this.durationMins,
    this.methodology = '',
    this.objectives = const [],
    this.resources = const [],
    this.priorKnowledge = '',
    this.activities = '',
    this.assessment = '',
    this.homework = '',
  });

  static String _t(String s) => s.trim();

  /// `POST /teaching/lesson-plans` body (teaching.service.ts:164-189). `objectives` is renamed to `learningObjectives` by the
  /// SERVER on create only (:175). `teacherId` = my Staff id (derived server-side for a teacher anyway, :176-179). Empty optional
  /// fields are omitted. `campusId` is stamped from the token (:173), never sent. [status] is `draft` or `submitted`.
  Map<String, Object?> toCreateJson({required String teacherId, required String teacherName, required LessonPlanStatus status}) => {
        'teacherId': teacherId,
        if (teacherName.isNotEmpty) 'teacherName': teacherName,
        'subject': _t(subject),
        'gradeLevel': _t(gradeLevel),
        if (_t(sectionName).isNotEmpty) 'sectionName': _t(sectionName),
        'topic': _t(topic),
        if (_t(description).isNotEmpty) 'description': _t(description),
        'planDate': wireDay(planDay),
        if (durationMins != null) 'durationMins': durationMins,
        if (_t(methodology).isNotEmpty) 'teachingMethodology': _t(methodology),
        if (objectives.isNotEmpty) 'objectives': objectives.map(_t).where((e) => e.isNotEmpty).toList(),
        if (resources.isNotEmpty) 'resources': resources.map(_t).where((e) => e.isNotEmpty).toList(),
        if (_t(priorKnowledge).isNotEmpty) 'priorKnowledge': _t(priorKnowledge),
        if (_t(activities).isNotEmpty) 'activities': _t(activities),
        if (_t(assessment).isNotEmpty) 'assessment': _t(assessment),
        if (_t(homework).isNotEmpty) 'homework': _t(homework),
        'status': status.wire,
      };

  /// `PATCH /teaching/lesson-plans/:id` body: ONLY what differs from [orig] (the update is a raw `$set`, teaching.service.ts:191-207).
  /// Never echoes status / approvedBy / rejectionReason / approverNotes / tenantId / campusId / teacherId. The objectives key is
  /// `learningObjectives` (the schema path): `objectives` would be dropped by mongoose strict mode on update (the rename exists only
  /// in createLessonPlan). Class and subject are not editable. [status] (`submitted`) is added when submitting.
  Map<String, Object?> toPatchJson(LessonPlanRecord orig, {LessonPlanStatus? status}) {
    final out = <String, Object?>{};
    void str(String key, String now, String before) {
      if (_t(now) != before.trim()) out[key] = _t(now);
    }

    str('topic', topic, orig.topic);
    str('description', description, orig.description);
    str('teachingMethodology', methodology, orig.teachingMethodology);
    str('priorKnowledge', priorKnowledge, orig.priorKnowledge);
    str('activities', activities, orig.activities);
    str('assessment', assessment, orig.assessment);
    str('homework', homework, orig.homework);
    final before = orig.planDay;
    if (before == null || before != DateTime(planDay.year, planDay.month, planDay.day)) out['planDate'] = wireDay(planDay);
    if (durationMins != null && durationMins != orig.durationMins) out['durationMins'] = durationMins;
    final obj = objectives.map(_t).where((e) => e.isNotEmpty).toList();
    if (!_same(obj, orig.learningObjectives)) out['learningObjectives'] = obj;
    final res = resources.map(_t).where((e) => e.isNotEmpty).toList();
    if (!_same(res, orig.resources)) out['resources'] = res;
    if (status != null) out['status'] = status.wire;
    return out;
  }

  static bool _same(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i].trim()) return false;
    }
    return true;
  }
}

/// `POST /teaching/lesson-plans/parse-upload` result (teaching.service.ts:294-379, the final `return {...}`): an AI-assisted DRAFT
/// that only prefills the form (never saved by the server, never submitted by the app).
class LessonPlanDraft {
  final String topic;
  final String description;
  final int? durationMins;

  /// One of [kLessonMethodologies] keys or null (the server nulls anything else, :341).
  final String? methodology;
  final List<String> objectives;

  /// Only values from [kLessonResources] (the server filters, :342).
  final List<String> resources;

  /// A single string, `'; '`-joined (the server's `otherResource`, singular).
  final String otherResource;
  final String homework;

  /// The subject / grade AS WRITTEN in the source ("the school will match it"): never trusted, only offered as a hint.
  final String? subjectGuess;
  final String? gradeLevelGuess;
  final List<String> warnings;
  final String? sourceFileName;

  const LessonPlanDraft({
    this.topic = '',
    this.description = '',
    this.durationMins,
    this.methodology,
    this.objectives = const [],
    this.resources = const [],
    this.otherResource = '',
    this.homework = '',
    this.subjectGuess,
    this.gradeLevelGuess,
    this.warnings = const [],
    this.sourceFileName,
  });

  factory LessonPlanDraft.fromJson(Map<String, dynamic> j) {
    final method = readString(j['teachingMethodology']);
    return LessonPlanDraft(
      topic: readText(j['topic']),
      description: readText(j['description']),
      durationMins: readInt(j['durationMins']),
      methodology: method != null && kLessonMethodologies.containsKey(method) ? method : null,
      objectives: readStringList(j['objectives']).where((e) => e.trim().isNotEmpty).toList(),
      resources: readStringList(j['resources']).where(kLessonResources.contains).toList(),
      otherResource: readText(j['otherResource']),
      homework: readText(j['homework']),
      subjectGuess: readString(j['subjectGuess']),
      gradeLevelGuess: readString(j['gradeLevelGuess']),
      warnings: readStringList(j['warnings']),
      sourceFileName: readString(j['sourceFileName']),
    );
  }

  /// Nothing usable came out of the document.
  bool get isEmpty => topic.trim().isEmpty && objectives.isEmpty && description.trim().isEmpty && homework.trim().isEmpty;
}
