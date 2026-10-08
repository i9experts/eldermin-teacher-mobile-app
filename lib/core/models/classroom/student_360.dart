import '../json_helpers.dart';
import 'attendance_models.dart';
import 'student_models.dart';

/// Guardian as shown to a teacher: NAME + RELATION (+ primary flag) only.
/// The payload also holds cnic, phone, email, occupation, employer and
/// monthlyIncome (student.schema.ts:11-24): deliberately never parsed.
class GuardianInfo {
  final String name;
  final String relation;
  final bool isPrimary;
  const GuardianInfo({required this.name, this.relation = '', this.isPrimary = false});

  factory GuardianInfo.fromJson(Map<String, dynamic> j) => GuardianInfo(
        name: readText(j['name']),
        relation: readText(j['relation']),
        isPrimary: readBool(j['isPrimary']),
      );

  String get relationLabel => relation.isEmpty ? '' : relation[0].toUpperCase() + relation.substring(1);
}

/// A day in the 360's `attendance.recent[]` (<= 30 StudentAttendance rows, date desc; students.service.ts:1502-1503).
class AttendanceDay {
  final String dayKey;
  final AttendanceStatus? status;
  const AttendanceDay({required this.dayKey, this.status});
}

class Attendance360 {
  final StatusCounts counts;
  final int totalDays;
  final int presentDays;
  /// (present + late) / total * 100, one decimal, computed server-side (students.service.ts:1520-1527).
  final double percentage;
  final List<AttendanceDay> recent;
  const Attendance360({
    this.counts = const StatusCounts(),
    this.totalDays = 0,
    this.presentDays = 0,
    this.percentage = 0,
    this.recent = const [],
  });

  factory Attendance360.fromJson(Map<String, dynamic> j) {
    final recent = <AttendanceDay>[];
    for (final r in asJsonMapList(j['recent'])) {
      final d = readDate(r['date']);
      if (d == null) continue;
      recent.add(AttendanceDay(dayKey: attendanceDayKey(d), status: AttendanceStatus.fromWire(r['status'])));
    }
    return Attendance360(
      counts: StatusCounts.fromSummary(j['summary']),
      totalDays: readInt(j['totalDays']) ?? 0,
      presentDays: readInt(j['presentDays']) ?? 0,
      percentage: (j['percentage'] is num) ? (j['percentage'] as num).toDouble() : 0,
      recent: recent,
    );
  }
}

/// `behaviour.recent[]` (Behaviour schema student-supporting.schema.ts:100-146).
class BehaviourItem {
  final DateTime? date;
  /// positive | negative | neutral
  final String type;
  final String category;
  final String description;
  /// low | medium | high | critical
  final String severity;
  final bool resolved;
  final int points;
  const BehaviourItem({
    this.date,
    this.type = 'neutral',
    this.category = '',
    this.description = '',
    this.severity = '',
    this.resolved = false,
    this.points = 0,
  });

  factory BehaviourItem.fromJson(Map<String, dynamic> j) => BehaviourItem(
        date: readDate(j['date']),
        type: readString(j['type']) ?? 'neutral',
        category: readText(j['category']),
        description: readText(j['description']),
        severity: readText(j['severity']),
        resolved: readBool(j['resolved']),
        points: readInt(j['points']) ?? 0,
      );

  String get categoryLabel => category.replaceAll('_', ' ');
}

class Behaviour360 {
  /// positive points - negative points (students.service.ts:1556-1557).
  final int totalPoints;
  final List<BehaviourItem> recent;
  const Behaviour360({this.totalPoints = 0, this.recent = const []});

  factory Behaviour360.fromJson(Map<String, dynamic> j) => Behaviour360(
        totalPoints: readInt(j['totalPoints']) ?? 0,
        recent: asJsonMapList(j['recent']).map(BehaviourItem.fromJson).toList(),
      );
}

/// `assessments.recent[]` (AssessmentResult schema student-supporting.schema.ts:175-201).
class ResultItem {
  final String title;
  final String type;
  final DateTime? date;
  final double? percentage;
  final String? overallGrade;
  final num? obtained;
  final num? max;
  const ResultItem({this.title = '', this.type = '', this.date, this.percentage, this.overallGrade, this.obtained, this.max});

  factory ResultItem.fromJson(Map<String, dynamic> j) => ResultItem(
        title: readText(j['assessmentTitle']),
        type: readText(j['assessmentType']),
        date: readDate(j['date']),
        percentage: j['percentage'] is num ? (j['percentage'] as num).toDouble() : null,
        overallGrade: readString(j['overallGrade']),
        obtained: j['totalObtainedMarks'] is num ? j['totalObtainedMarks'] as num : null,
        max: j['totalMaxMarks'] is num ? j['totalMaxMarks'] as num : null,
      );
}

/// Teacher-facing Student 360 (read-only), built from `GET /students/:id/360`
/// (students.service.ts:1483-1575) through an explicit WHITELIST.
///
/// Parsed: profile basics ([StudentSummary] keys), guardian name/relation,
/// `student.medical.allergies` (safety flag), attendance (summary, totals, recent
/// days), behaviour (points, recent), assessments (recent).
///
/// NOT parsed, ever (payload keys the teacher app drops): the whole top-level
/// `fees` block (summary + recent fee records), `student.guardians[].cnic/phone/
/// email/occupation/employer/monthlyIncome`, `student.personalPhone/whatsApp/altPhone/
/// personalEmail/address/town/city/...`, `student.nationalId/bForm/passportNumber/visaNo`,
/// `student.emergencyContact*`, `student.tutor*`, `student.medical.*` except allergies
/// (doctor, insurance, medications, conditions), `student.specialNeeds/scholarship*`,
/// `student.transport*/hostel*`, `student.documents`, `student.academicHistory`, `customFields`.
///
/// REDUCED PAYLOADS (backend teacher projection, planned 2026-10-08: guardian email, address, documents, hostel, full medical, transport detail
/// removed; allergies and the date of birth stay): nothing here is required except the student `_id`, every block defaults to empty, and the
/// guardians section is hidden when the key is absent ([guardiansKnown]).
class Student360 {
  final StudentSummary student;
  final List<GuardianInfo> guardians;
  final List<String> allergies;
  final Attendance360 attendance;
  final Behaviour360 behaviour;
  final List<ResultItem> results;

  /// The payload carried a `guardians` key at all. The backend's teacher projection may drop it (2026-10-08 field hiding): then the screen
  /// shows no guardians section instead of a misleading "No guardians on record".
  final bool guardiansKnown;

  const Student360({
    required this.student,
    this.guardians = const [],
    this.allergies = const [],
    this.attendance = const Attendance360(),
    this.behaviour = const Behaviour360(),
    this.results = const [],
    this.guardiansKnown = true,
  });

  factory Student360.fromJson(Map<String, dynamic> j) {
    final raw = asJsonMap(j['student']);
    final seen = <String>{};
    final guardians = <GuardianInfo>[];
    // The same guardian is sometimes stored several times (known data issue, students.controller.ts:196-205 comment):
    // collapse identical name+relation rows.
    for (final g in asJsonMapList(raw['guardians']).map(GuardianInfo.fromJson)) {
      if (g.name.isEmpty) continue;
      if (seen.add('${g.name.toLowerCase()}|${g.relation.toLowerCase()}')) guardians.add(g);
    }
    final medical = asJsonMap(raw['medical']);
    return Student360(
      student: StudentSummary.fromJson(raw),
      guardians: guardians,
      guardiansKnown: raw.containsKey('guardians') && raw['guardians'] is List,
      allergies: readStringList(medical['allergies']).where((e) => e.trim().isNotEmpty).toList(),
      attendance: Attendance360.fromJson(asJsonMap(j['attendance'])),
      behaviour: Behaviour360.fromJson(asJsonMap(j['behaviour'])),
      results: asJsonMapList(asJsonMap(j['assessments'])['recent']).map(ResultItem.fromJson).toList(),
    );
  }

  /// Every value held by the model, flattened to text (tests assert no sensitive value is in it).
  String debugDump() => [
        student.toDebugMap(),
        [for (final g in guardians) '${g.name}|${g.relation}|${g.isPrimary}'],
        allergies,
        '${attendance.totalDays}|${attendance.presentDays}|${attendance.percentage}|${attendance.recent.length}',
        '${behaviour.totalPoints}|${[for (final b in behaviour.recent) '${b.type}|${b.category}|${b.description}|${b.severity}']}',
        [for (final r in results) '${r.title}|${r.type}|${r.percentage}|${r.overallGrade}'],
      ].join(' ~ ');
}
