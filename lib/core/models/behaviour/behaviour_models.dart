import '../../utils/class_match.dart';
import '../../utils/roster_scope.dart';
import '../classroom/student_models.dart';
import '../json_helpers.dart';

/// Behaviour & Tarbiyah models (store B: `BehaviourRecord`, the collection the parent app reads;
/// owner decision). Paths relative to eldermin-backend/src/behaviour/ (branch feat/staff-portal):
///  * BehaviourRecord: schemas/behaviour.schema.ts:14-106   * TarbiyahAssessment: schemas/behaviour.schema.ts:147-190
///  * enums: BSC:30-33 (type), :36-50 (category), :60-63 (severity)
/// Parsed since T1 (everything a teacher may see in the detail sheet): location, consequence, actionTaken, witnesses, follow-up
/// (required / date / note), resolved date + note, parentNotified (+ date / by), parentResponse, verification, attachments.
/// Never parsed: campusId, schoolSlug.

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

/// The consequences the WEB teacher form offers (Eldermin-Frontend pages/behaviour/index.tsx:623-626), a subset of the schema enum
/// (behaviour.schema.ts:71-78). A stored value outside this list is still shown (see [consequenceLabel]).
const List<String> kConsequences = [
  'no_action', 'verbal_warning', 'written_warning', 'parent_notification', 'counselling', 'detention', 'suspension', 'commendation',
];

const Map<String, String> kConsequenceLabels = {
  'no_action': 'No action',
  'verbal_warning': 'Verbal warning',
  'written_warning': 'Written warning',
  'parent_notification': 'Parent notification',
  'counselling': 'Counselling',
  'detention': 'Detention',
  'suspension': 'Suspension',
  'commendation': 'Commendation',
  'community_service': 'Community service',
  'behaviour_contract': 'Behaviour contract',
  'merit_award': 'Merit award',
};

String consequenceLabel(String wire) => kConsequenceLabels[wire] ?? (wire.isEmpty ? '' : wire[0].toUpperCase() + wire.substring(1).replaceAll('_', ' '));

String severityLabel(String s) => s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1);

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
  final DateTime? resolvedDate;
  final String reportedBy;
  final String reportedById;
  final String location;
  final String consequence;
  final String actionTaken;
  final List<String> witnesses;
  final bool followUpRequired;
  final DateTime? followUpDate;
  final String followUpNote;
  final bool parentNotified;
  final DateTime? parentNotifiedDate;
  final String parentNotifiedBy;
  final String parentResponse;
  final bool verified;
  final String verifiedBy;
  final List<String> attachments;

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
    this.resolvedDate,
    this.reportedBy = '',
    this.reportedById = '',
    this.location = '',
    this.consequence = '',
    this.actionTaken = '',
    this.witnesses = const [],
    this.followUpRequired = false,
    this.followUpDate,
    this.followUpNote = '',
    this.parentNotified = false,
    this.parentNotifiedDate,
    this.parentNotifiedBy = '',
    this.parentResponse = '',
    this.verified = false,
    this.verifiedBy = '',
    this.attachments = const [],
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
        resolvedDate: readDate(j['resolvedDate']),
        reportedBy: readText(j['reportedBy']),
        reportedById: readId(j['reportedById']) ?? '',
        location: readText(j['location']),
        consequence: readText(j['consequence']),
        actionTaken: readText(j['actionTaken']),
        witnesses: readStringList(j['witnesses']),
        followUpRequired: readBool(j['followUpRequired']),
        followUpDate: readDate(j['followUpDate']),
        followUpNote: readText(j['followUpNote']),
        parentNotified: readBool(j['parentNotified']),
        parentNotifiedDate: readDate(j['parentNotifiedDate']),
        parentNotifiedBy: readText(j['parentNotifiedBy']),
        parentResponse: readText(j['parentResponse']),
        verified: readBool(j['verified']),
        verifiedBy: readText(j['verifiedBy']),
        attachments: readStringList(j['attachments']),
      );

  /// A copy with the fields an edit / resolve changes (the server answers `PUT` / `PATCH resolve` with the whole document, which
  /// is normally parsed instead; this is for optimistic UI and tests).
  BehaviourRecord copyWith({bool? resolved, String? resolvedNote}) => BehaviourRecord(
        id: id, studentId: studentId, studentName: studentName, grade: grade, section: section, date: date, typeWire: typeWire,
        category: category, title: title, description: description, severity: severity, points: points,
        resolved: resolved ?? this.resolved, resolvedNote: resolvedNote ?? this.resolvedNote, resolvedDate: resolvedDate,
        reportedBy: reportedBy, reportedById: reportedById, location: location, consequence: consequence, actionTaken: actionTaken,
        witnesses: witnesses, followUpRequired: followUpRequired, followUpDate: followUpDate, followUpNote: followUpNote,
        parentNotified: parentNotified, parentNotifiedDate: parentNotifiedDate, parentNotifiedBy: parentNotifiedBy,
        parentResponse: parentResponse, verified: verified, verifiedBy: verifiedBy, attachments: attachments,
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
  /// Tolerant class match of a record's own grade/section strings via the ONE shared rule ([ClassRef.coversGradeSection] ->
  /// [sectionCovered]): a record without a section matches by class only, exactly like the backend (behaviour-teacher-scope.ts).
  bool containsRecord(BehaviourRecord r) => coversGradeSection(r.grade, r.section);
}

/// `{ data, meta:{ total, page, limit, pages } }` (behaviour.service.ts:170-207). `page`/`limit` are echoed as the raw query STRINGS
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

/// Server-side filters of `GET /behaviour/records` (behaviour.service.ts getRecords: type, severity, resolved, from, to, search, mine).
/// Empty = no filter. `from` / `to` are calendar days (sent as `YYYY-MM-DD`; `to` is inclusive of that whole day).
class RecordFilters {
  final String? type; // positive | negative | neutral
  final String? severity;
  final bool? resolved; // true = resolved only, false = open only
  final DateTime? from;
  final DateTime? to;
  final String search;
  const RecordFilters({this.type, this.severity, this.resolved, this.from, this.to, this.search = ''});

  static const none = RecordFilters();

  bool get isActive => type != null || severity != null || resolved != null || from != null || to != null;

  /// How many filter dimensions are set (the search box does not count: it has its own field).
  int get count => [type, severity, resolved, from, to].where((e) => e != null).length;

  RecordFilters copyWith({
    Object? type = _keep,
    Object? severity = _keep,
    Object? resolved = _keep,
    Object? from = _keep,
    Object? to = _keep,
    String? search,
  }) =>
      RecordFilters(
        type: identical(type, _keep) ? this.type : type as String?,
        severity: identical(severity, _keep) ? this.severity : severity as String?,
        resolved: identical(resolved, _keep) ? this.resolved : resolved as bool?,
        from: identical(from, _keep) ? this.from : from as DateTime?,
        to: identical(to, _keep) ? this.to : to as DateTime?,
        search: search ?? this.search,
      );

  /// Query parameters for the list route. `to` is sent as the END of that day so a record logged on it is included
  /// (the server compares `date <= to` on the stored instant).
  Map<String, Object> toQuery() => {
        if (type != null) 'type': type!,
        if (severity != null) 'severity': severity!,
        if (resolved != null) 'resolved': resolved! ? 'true' : 'false',
        if (from != null) 'from': wireDay(from!),
        if (to != null) 'to': '${wireDay(to!)}T23:59:59.999Z',
        if (search.trim().isNotEmpty) 'search': search.trim(),
      };

  /// Does [r] pass the same filters? (client-side re-check of what the server already filtered, and the only filter on a server
  /// that ignores a parameter.) Search matches student name, title and description like the server.
  bool accepts(BehaviourRecord r) {
    if (type != null && r.typeWire != type) return false;
    if (severity != null && r.severity != severity) return false;
    if (resolved != null && r.resolved != resolved) return false;
    final d = r.day;
    if (from != null && (d == null || d.isBefore(DateTime(from!.year, from!.month, from!.day)))) return false;
    if (to != null && (d == null || d.isAfter(DateTime(to!.year, to!.month, to!.day)))) return false;
    final q = search.trim().toLowerCase();
    if (q.isNotEmpty && !(r.studentName.toLowerCase().contains(q) || r.title.toLowerCase().contains(q) || r.description.toLowerCase().contains(q))) return false;
    return true;
  }
}

const Object _keep = Object();

/// What the log / edit form produces. [toJson] is the exact `POST /behaviour/records` body, [toUpdateJson] the `PUT` body.
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
  // Same fields as the web teacher form (Eldermin-Frontend pages/behaviour/index.tsx:576-581,623-646).
  final String consequence; // '' = not set (the web sends undefined)
  final String location;
  final bool parentNotified;
  final bool followUpRequired;

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
    this.consequence = '',
    this.location = '',
    this.parentNotified = false,
    this.followUpRequired = false,
  });

  /// Required by the mongoose schema (any failure there is a bare 500, behaviour.service.ts:159-168): studentId, studentName, grade,
  /// date, type, category, title, description, reportedBy, academicYear (+ schoolSlug, added from the token). Notes:
  ///  * studentName/grade/section/rollNumber are the STUDENT'S OWN stored values (as the web does, index.tsx:568-573).
  ///  * `date` is `YYYY-MM-DD` (as the web); read back as the UTC components.
  ///  * `reportedBy` = my name and `reportedById` = my user id: the server only defaults the name (to the JWT name, else 'Admin'); the
  ///    id lets the app find "my entries" later (a teacher token's id is also forced server-side since B0).
  ///  * `academicYear` = the student's own `currentAcademicYear` when known, else omitted (server default: header / '2025-26').
  ///  * `parentNotified: true` makes the server write an in-app notification for the guardians when the record is CREATED
  ///    (behaviour.service.ts:170-176). The parent app shows EVERY record of the student regardless of this flag.
  ///  * `consequence` / `location` are sent only when set (the web does the same).
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
        if (consequence.isNotEmpty) 'consequence': consequence,
        if (location.trim().isNotEmpty) 'location': location.trim(),
        'parentNotified': parentNotified,
        'followUpRequired': followUpRequired,
        'reportedBy': reporterName,
        'reportedById': reporterId,
        if ((student.academicYear ?? '').isNotEmpty) 'academicYear': student.academicYear,
      };

  /// `PUT /behaviour/records/:id` body (behaviour.controller.ts:68-78): ONLY what the form edits. Never the student, the reporter,
  /// `parentNotified` (the server notifies parents on create only) or any tenancy field (the server strips those for a teacher anyway,
  /// B0). `consequence` / `location` are sent even when cleared ('') so an edit can remove them.
  Map<String, Object?> toUpdateJson() => {
        'date': wireDay(day),
        'type': kind.wire,
        'category': category,
        'title': title.trim(),
        'description': description.trim(),
        'severity': severity,
        'points': points,
        'consequence': consequence,
        'location': location.trim(),
        'followUpRequired': followUpRequired,
      };
}

/// `GET /behaviour/character-settings` (behaviour.service.ts getCharacterSettings): the school's programme name, characteristics and
/// rating scale. A school with no document gets the built-in Tarbiyah defaults server-side, so this is rarely empty.
class CharacterSettings {
  final String moduleDisplayName;
  final Map<String, String> traitLabels; // key -> English name
  final int scaleMin;
  final int scaleMax;
  const CharacterSettings({this.moduleDisplayName = '', this.traitLabels = const {}, this.scaleMin = 1, this.scaleMax = 5});

  static const fallback = CharacterSettings(moduleDisplayName: 'Tarbiyah', traitLabels: kTarbiyahTraits);

  factory CharacterSettings.fromJson(Map<String, dynamic> j) {
    final labels = <String, String>{};
    for (final c in asJsonMapList(j['characteristics'])) {
      final k = readText(c['key']);
      final n = readText(c['nameEn']);
      if (k.isNotEmpty && n.isNotEmpty) labels[k] = n;
    }
    final scale = asJsonMap(j['ratingScale']);
    return CharacterSettings(
      moduleDisplayName: readText(j['moduleDisplayName']),
      traitLabels: labels,
      scaleMin: readInt(scale['min']) ?? 1,
      scaleMax: readInt(scale['max']) ?? 5,
    );
  }

  /// The programme name, or "Tarbiyah" when the school set none.
  String get programName => moduleDisplayName.isEmpty ? 'Tarbiyah' : moduleDisplayName;

  /// Trait label: the school's name, else the built-in Tarbiyah name, else a readable form of the key.
  String labelFor(String key) {
    final own = traitLabels[key];
    if (own != null && own.isNotEmpty) return own;
    final builtIn = kTarbiyahTraits[key];
    if (builtIn != null) return builtIn;
    if (key.isEmpty) return '';
    return key[0].toUpperCase() + key.substring(1).replaceAll('_', ' ');
  }
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
  final String assessedById;
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
    this.assessedById = '',
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
        assessedById: readId(j['assessedById']) ?? '',
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

  /// Did I record this assessment? `assessedById` is the author the server stamps from the token (behaviour.service.ts createTarbiyahAssessment);
  /// a legacy assessment without one falls back to the `assessedBy` NAME, exactly like the server's author rule (isOwnByAuthor).
  /// The server decides on every edit (403 otherwise); this only decides whether the Edit button is offered.
  bool isMine({required String userId, required String userName}) {
    if (assessedById.isNotEmpty) return assessedById == userId;
    final n = userName.trim().toLowerCase();
    return n.isNotEmpty && assessedBy.trim().toLowerCase() == n;
  }

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


/// Tarbiyah period types the server accepts (`periodType` enum, behaviour.schema.ts: monthly | termly | annual).
const List<String> kTarbiyahPeriodTypes = ['monthly', 'termly', 'annual'];

String tarbiyahPeriodTypeLabel(String t) => switch (t) {
      'monthly' => 'Monthly',
      'termly' => 'Termly',
      'annual' => 'Annual',
      _ => t,
    };

/// What the teacher enters for a Tarbiyah assessment (create or edit). The overall score / percentage / rating are computed by the SERVER from
/// the traits and the school's scale; authorship (`assessedById`, `assessedBy`) and the campus come from the token. `parentShared` is never sent
/// (the share toggle waits for the backend `visibleToParent`).
class TarbiyahDraft {
  final String periodType;
  final String period;
  final DateTime day;

  /// trait key -> score, in the school's trait order.
  final Map<String, int> scores;
  final String observations;
  final List<String> strengths;
  final List<String> improvements;

  const TarbiyahDraft({
    required this.periodType,
    required this.period,
    required this.day,
    required this.scores,
    this.observations = '',
    this.strengths = const [],
    this.improvements = const [],
  });

  List<Map<String, Object?>> get _traits => [
        for (final e in scores.entries) {'traitKey': e.key, 'score': e.value},
      ];

  /// `POST /behaviour/tarbiyah`: the student fields are copied from the roster row (the server stores them denormalised).
  Map<String, Object?> toCreateJson({required String studentId, required String studentName, required String grade, required String section}) => {
        'studentId': studentId,
        'studentName': studentName,
        'grade': grade,
        if (section.isNotEmpty) 'section': section,
        'period': period.trim(),
        'periodType': periodType,
        'assessmentDate': wireDay(day),
        'traits': _traits,
        'teacherObservations': observations.trim(),
        'areasOfStrength': strengths,
        'areasForImprovement': improvements,
      };

  /// `PUT /behaviour/tarbiyah/:id`: only the editable fields (the server strips student / author / campus fields for a teacher anyway).
  Map<String, Object?> toUpdateJson() => {
        'period': period.trim(),
        'periodType': periodType,
        'assessmentDate': wireDay(day),
        'traits': _traits,
        'teacherObservations': observations.trim(),
        'areasOfStrength': strengths,
        'areasForImprovement': improvements,
      };
}

/// A multi-line text box -> one list entry per non-empty line.
List<String> linesOf(String text) => [for (final l in text.split('\n')) if (l.trim().isNotEmpty) l.trim()];
