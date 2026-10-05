import '../json_helpers.dart';

/// One group of a split lesson (`periods[].splitGroups[]`).
/// Backend: teaching/schemas/timetable.schema.ts:57-66 (verified).
class SplitGroup {
  final String label;
  final String teacherId;
  final String teacherName;
  final String roomNo;
  const SplitGroup({this.label = '', this.teacherId = '', this.teacherName = '', this.roomNo = ''});

  factory SplitGroup.fromJson(Map<String, dynamic> j) => SplitGroup(
        label: readText(j['label']),
        teacherId: readId(j['teacherId']) ?? '',
        teacherName: readText(j['teacherName']),
        roomNo: readText(j['roomNo']),
      );
}

/// `periods[]` of a timetable document (timetable.schema.ts:17-70, verified).
class TimetablePeriod {
  /// 0 = Sunday .. 6 = Saturday (JS `Date.getDay()`), schema :19.
  final int? day;
  final int? periodNo;
  /// "HH:mm" by convention only (schema :21-22 has no validation: U7).
  final String startTime;
  final String endTime;
  final String subject;
  /// Staff._id; blank for a split period (schema :24, :54-56).
  final String teacherId;
  final String teacherName;
  final String roomNo;
  final String type;
  /// 'both' | 'A' | 'B' (schema :43).
  final String weekCycle;
  final String? blockId;
  final List<SplitGroup> splitGroups;

  const TimetablePeriod({
    this.day,
    this.periodNo,
    this.startTime = '',
    this.endTime = '',
    this.subject = '',
    this.teacherId = '',
    this.teacherName = '',
    this.roomNo = '',
    this.type = 'regular',
    this.weekCycle = 'both',
    this.blockId,
    this.splitGroups = const [],
  });

  factory TimetablePeriod.fromJson(Map<String, dynamic> j) => TimetablePeriod(
        day: readInt(j['day']),
        periodNo: readInt(j['periodNo']),
        startTime: readText(j['startTime']),
        endTime: readText(j['endTime']),
        subject: readText(j['subject']),
        teacherId: readId(j['teacherId']) ?? '',
        teacherName: readText(j['teacherName']),
        roomNo: readText(j['roomNo']),
        type: readString(j['type']) ?? 'regular',
        weekCycle: readString(j['weekCycle']) ?? 'both',
        blockId: readString(j['blockId']),
        splitGroups: asJsonMapList(j['splitGroups']).map(SplitGroup.fromJson).toList(),
      );

  /// The split group this teacher teaches, if any.
  SplitGroup? splitGroupOf(String staffId) {
    for (final g in splitGroups) {
      if (g.teacherId == staffId) return g;
    }
    return null;
  }

  /// Web rule (Eldermin-Frontend TimetableTab.tsx:210-211): top-level
  /// teacherId OR any split group.
  bool isTeachingBy(String staffId) =>
      staffId.isNotEmpty && (teacherId == staffId || splitGroupOf(staffId) != null);
}

/// A whole class timetable document - the endpoint returns EVERY period of
/// the class (all teachers), so callers must filter (TS:486-492).
class TimetableDoc {
  final String id;
  final String gradeLevel;
  final String sectionName;
  final bool weekCycleEnabled;
  /// Comment-only semantics (S/TT:75-80): U1, never used to guess A/B.
  final DateTime? cycleAnchor;
  final List<TimetablePeriod> periods;

  const TimetableDoc({
    required this.id,
    this.gradeLevel = '',
    this.sectionName = '',
    this.weekCycleEnabled = false,
    this.cycleAnchor,
    this.periods = const [],
  });

  factory TimetableDoc.fromJson(Map<String, dynamic> j) => TimetableDoc(
        id: readId(j['_id'] ?? j['id']) ?? '',
        gradeLevel: readText(j['gradeLevel']),
        sectionName: readText(j['sectionName']),
        weekCycleEnabled: readBool(j['weekCycleEnabled']),
        cycleAnchor: readDate(j['cycleAnchor']),
        periods: asJsonMapList(j['periods']).map(TimetablePeriod.fromJson).toList(),
      );

  String get classLabel => [gradeLevel, sectionName].where((e) => e.isNotEmpty).join(' - ');
}
