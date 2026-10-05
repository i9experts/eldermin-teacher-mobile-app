import '../../utils/class_match.dart';
import '../../utils/roster_scope.dart';
import '../classroom/student_models.dart';
import '../json_helpers.dart';

/// Behaviour & Tarbiyah models (store B: `BehaviourRecord`, the collection the parent app reads;
/// owner decision). Paths relative to eldermin-backend/src/behaviour/ (branch feat/staff-portal):
///  * BehaviourRecord: schemas/behaviour.schema.ts:14-106   * TarbiyahAssessment: schemas/behaviour.schema.ts:147-190
///  * enums: BSC:30-33 (type), :36-50 (category), :60-63 (severity)
/// Never parsed (present in the payload, not needed by a teacher screen): witnesses, location, actionTaken, consequence,
/// follow-up details, parent communication fields (parentNotifiedBy, parentResponse), verifiedBy, attachments, campusId.

/// "Merit / demerit / note" = `type` positive / negative / neutral.
enum BehaviourKind {
  merit('positive', 'Merit', 'Positive behaviour'),
  demerit('negative', 'Demerit', 'Concern'),
  note('neutral', 'Note', 'Neutral note');

  final String wire;
  final String label;
  final String caption;
  const BehaviourKind(this.wire, this.label, this.caption);

  static BehaviourKind? fromWire(String? v) {
    for (final k in values) {
      if (k.wire == v) return k;
    }
    return null;
  }
}

/// Category enum of the schema (behaviour.schema.ts:36-50), grouped by type like the web form (types.ts:163-179),
/// labels from the web (types.ts:181-).
const Map<BehaviourKind, List<String>> kBehaviourCategories = {
  BehaviourKind.merit: [
    'academic_excellence', 'helping_others', 'leadership', 'good_conduct', 'community_service', 'innovation',
    'sportsmanship', 'attendance_excellence', 'moral_courage',
  ],
  BehaviourKind.demerit: [
    'misconduct', 'bullying', 'cheating', 'dishonesty', 'disrespect', 'property_damage', 'late_coming',
    'uniform_violation', 'phone_misuse', 'absenteeism', 'fighting', 'harassment', 'vandalism',
  ],
  BehaviourKind.note: [
    'counselling_referral', 'parent_meeting', 'warning_issued', 'behaviour_contract', 'restorative_practice',
  ],
};

const Map<String, String> kCategoryLabels = {
  'academic_excellence': 'Academic Excellence',
  'helping_others': 'Helping Others',
  'leadership': 'Leadership',
  'good_conduct': 'Good Conduct',
  'community_service': 'Community Service',
  'innovation': 'Innovation',
  'sportsmanship': 'Sportsmanship',
  'attendance_excellence': 'Perfect Attendance',
  'moral_courage': 'Moral Courage',
  'misconduct': 'Misconduct',
  'bullying': 'Bullying',
  'cheating': 'Cheating',
  'dishonesty': 'Dishonesty',
  'disrespect': 'Disrespect',
  'property_damage': 'Property Damage',
  'late_coming': 'Late Coming',
  'uniform_violation': 'Uniform Violation',
  'phone_misuse': 'Phone Misuse',
  'absenteeism': 'Absenteeism',
  'fighting': 'Fighting',
  'harassment': 'Harassment',
  'vandalism': 'Vandalism',
  'counselling_referral': 'Counselling Referral',
  'parent_meeting': 'Parent Meeting',
  'warning_issued': 'Warning Issued',
  'behaviour_contract': 'Behaviour Contract',
  'restorative_practice': 'Restorative Practice',
};

String categoryLabel(String wire) =>
    kCategoryLabels[wire] ?? (wire.isEmpty ? '' : wire[0].toUpperCase() + wire.substring(1).replaceAll('_', ' '));

/// severity enum (behaviour.schema.ts:60-63).
const List<String> kSeverities = ['low', 'medium', 'high', 'critical'];

class BehaviourRecord {
  final String id;
  final String studentId;
  final String studentName;
  final String grade;
  final String section;
  final DateTime? date;
  final String typeWire;
  final String category;
  final String title;
  final String description;
  final String severity;
  final int points;
  final bool resolved;
  final String resolvedNote;
  final String reportedBy;
  final String reportedById;

  const BehaviourRecord({
    required this.id,
    this.studentId = '',
    this.studentName = '',
    this.grade = '',
    this.section = '',
    this.date,
    this.typeWire = 'neutral',
    this.category = '',
    this.title = '',
    this.description = '',
    this.severity = 'medium',
    this.points = 0,
    this.resolved = false,
    this.resolvedNote = '',
    this.reportedBy = '',
    this.reportedById = '',
  });

  factory BehaviourRecord.fromJson(Map<String, dynamic> j) => BehaviourRecord(
        id: readId(j['_id'] ?? j['id']) ?? '',
        studentId: readId(j['studentId']) ?? '',
        studentName: readText(j['studentName']),
        grade: readText(j['grade']),
        section: readText(j['section']),
        date: readDate(j['date']),
        typeWire: readString(j['type']) ?? 'neutral',
        category: readText(j['category']),
        title: readText(j['title']),
        description: readText(j['description']),
        severity: readString(j['severity']) ?? 'medium',
        points: readNum(j['points'])?.round() ?? 0,
        resolved: readBool(j['resolved']),
        resolvedNote: readText(j['resolvedNote']),
        reportedBy: readText(j['reportedBy']),
        reportedById: readId(j['reportedById']) ?? '',
      );

  BehaviourKind? get kind => BehaviourKind.fromWire(typeWire);

  /// The calendar day of the incident (web and app write `YYYY-MM-DD` = UTC midnight).
  DateTime? get day => storedCalendarDay(date);

  String get classLabel => [grade, section].where((e) => e.isNotEmpty).join(' - ');

  /// Did I log it? `reportedById` is only present when the writer sent it (the SERVER never sets it: behaviour.controller.ts:58-65;
  /// this app does). Records from the web only carry the `reportedBy` NAME (the JWT name, or whatever was typed), so the name is
  /// the fallback; a matching name is a best guess, not an identity (UNVERIFIED).
  bool isMine({required String userId, required String userName}) {
    if (reportedById.isNotEmpty) return reportedById == userId;
    final n = userName.trim().toLowerCase();
    return n.isNotEmpty && reportedBy.trim().toLowerCase() == n;
  }
}

extension ClassRefBehaviour on ClassRef {
  /// Tolerant class match of a record's own grade/section strings (same rules as for students).
  bool containsRecord(BehaviourRecord r) => sameGrade(r.grade, grade) && (section.isEmpty || sameSection(r.section, section));
}

/// `{ data, meta:{ total, page, limit, pages } }` (behaviour.service.ts:154-193). `page`/`limit` are echoed as the raw query STRINGS
/// when sent (the controller has no DTO), hence the tolerant reads.
class BehaviourPage {
  final List<BehaviourRecord> records;
  final int total;
  final int pages;
  const BehaviourPage(this.records, this.total, this.pages);

  factory BehaviourPage.fromJson(Map<String, dynamic> j) {
    final meta = asJsonMap(j['meta']);
    return BehaviourPage(
      asJsonMapList(j['data']).map(BehaviourRecord.fromJson).where((r) => r.id.isNotEmpty).toList(),
      readInt(meta['total']) ?? 0,
      readInt(meta['pages']) ?? 1,
    );
  }
}

/// What the quick-log form produces; [toJson] is the exact `POST /behaviour/records` body.
class BehaviourDraft {
  final StudentSummary student;
  final BehaviourKind kind;
  final String category;
  final String title;
  final String description;
  final String severity;
  final int points;
  final DateTime day;
  final String reporterName;
  final String reporterId;

  const BehaviourDraft({
    required this.student,
    required this.kind,
    required this.category,
    required this.title,
    required this.description,
    this.severity = 'low',
    required this.points,
    required this.day,
    required this.reporterName,
    required this.reporterId,
  });

  /// Required by the mongoose schema (any failure there is a bare 500, behaviour.service.ts:155-165): studentId, studentName, grade,
  /// date, type, category, title, description, reportedBy, academicYear (+ schoolSlug, added from the token). Notes:
  ///  * studentName/grade/section/rollNumber are the STUDENT'S OWN stored values (as the web does, index.tsx:568-573).
  ///  * `date` is `YYYY-MM-DD` (as the web); read back as the UTC components.
  ///  * `reportedBy` = my name and `reportedById` = my user id: the server only defaults the name (to the JWT name, else 'Admin') and
  ///    never sets the id; the id lets the app find "my entries" later.
  ///  * `academicYear` = the student's own `currentAcademicYear` when known, else omitted (server default: header / '2025-26').
  ///  * `parentNotified` / `followUpRequired` are sent false: the app does not notify anyone and has no follow-up flow. The parent app
  ///    shows EVERY record of the student regardless (parent-portal.service.ts:390-396), so the entry is visible to guardians at once.
  ///  * `points`: + for merit, - for demerit, 0 for a note (behaviour.schema.ts:67).
  Map<String, Object?> toJson() => {
        'studentId': student.id,
        'studentName': student.fullName,
        'grade': student.grade,
        if (student.section.isNotEmpty) 'section': student.section,
        if ((student.rollNumber ?? '').isNotEmpty) 'rollNumber': student.rollNumber,
        'date': wireDay(day),
        'type': kind.wire,
        'category': category,
        'title': title.trim(),
        'description': description.trim(),
        'severity': severity,
        'points': points,
        'parentNotified': false,
        'followUpRequired': false,
        'reportedBy': reporterName,
        'reportedById': reporterId,
        if ((student.academicYear ?? '').isNotEmpty) 'academicYear': student.academicYear,
      };
}

/// Tarbiyah trait names, from the backend's static list (behaviour.schema.ts:120-133). Unknown keys (a school can customise its
/// programme, behaviour.service.ts:265-277) fall back to the raw key.
const Map<String, String> kTarbiyahTraits = {
  'sidq': 'Truthfulness (Sidq)',
  'amanah': 'Trustworthiness (Amanah)',
  'adab': 'Manners & Respect (Adab)',
  'ihsan': 'Excellence (Ihsan)',
  'sabr': 'Patience (Sabr)',
  'tawadu': "Humility (Tawadu')",
  'shukr': 'Gratitude (Shukr)',
  'ukhuwwah': 'Brotherhood (Ukhuwwah)',
  'ijtihad': 'Diligence (Ijtihad)',
  'nazafah': 'Cleanliness (Nazafah)',
  'itqan': 'Precision (Itqan)',
  'tawakkul': 'Trust in Allah (Tawakkul)',
};

class TraitScore {
  final String key;
  final double score;
  final String observation;
  const TraitScore(this.key, this.score, this.observation);

  String get label => kTarbiyahTraits[key] ?? key;
}

class TarbiyahAssessment {
  final String id;
  final String studentId;
  final String period;
  final String periodType;
  final DateTime? assessmentDate;
  final List<TraitScore> traits;
  final double overallPercentage;
  final String overallRating;
  final String teacherObservations;
  final List<String> areasOfStrength;
  final List<String> areasForImprovement;
  final String assessedBy;

  const TarbiyahAssessment({
    required this.id,
    this.studentId = '',
    this.period = '',
    this.periodType = '',
    this.assessmentDate,
    this.traits = const [],
    this.overallPercentage = 0,
    this.overallRating = '',
    this.teacherObservations = '',
    this.areasOfStrength = const [],
    this.areasForImprovement = const [],
    this.assessedBy = '',
  });

  factory TarbiyahAssessment.fromJson(Map<String, dynamic> j) => TarbiyahAssessment(
        id: readId(j['_id'] ?? j['id']) ?? '',
        studentId: readId(j['studentId']) ?? '',
        period: readText(j['period']),
        periodType: readText(j['periodType']),
        assessmentDate: readDate(j['assessmentDate']),
        traits: asJsonMapList(j['traits'])
            .map((t) => TraitScore(readText(t['traitKey']), readNum(t['score']) ?? 0, readText(t['observation'])))
            .where((t) => t.key.isNotEmpty)
            .toList(),
        overallPercentage: readNum(j['overallPercentage']) ?? 0,
        overallRating: readText(j['overallRating']),
        teacherObservations: readText(j['teacherObservations']),
        areasOfStrength: readStringList(j['areasOfStrength']),
        areasForImprovement: readStringList(j['areasForImprovement']),
        assessedBy: readText(j['assessedBy']),
      );

  DateTime? get day => storedCalendarDay(assessmentDate);

  String get ratingLabel {
    switch (overallRating) {
      case 'excellent':
        return 'Excellent';
      case 'good':
        return 'Good';
      case 'satisfactory':
        return 'Satisfactory';
      case 'needs_improvement':
        return 'Needs improvement';
      case 'critical':
        return 'Critical';
    }
    return overallRating;
  }
}
