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

// ── GET /staff-portal/timetable (NEW on feat/staff-portal) ─────────────
// Backend: eldermin-backend/src/staff-portal/staff-teaching.service.ts
// timetable() :153-225 (route staff-portal.controller.ts:91-92). Verified from code.

/// `slots[].splitGroup` (staff-teaching.service.ts:181): `{ name, subject, roomNo }`,
/// present only when the teacher teaches one group of a split period.
class SlotSplitGroup {
  final String name;
  final String subject;
  final String roomNo;
  const SlotSplitGroup({this.name = '', this.subject = '', this.roomNo = ''});

  factory SlotSplitGroup.fromJson(Map<String, dynamic> j) => SlotSplitGroup(
        name: readText(j['name']),
        subject: readText(j['subject']),
        roomNo: readText(j['roomNo']),
      );
}

/// One of MY slots on a day (staff-teaching.service.ts:188-200). `sectionName`
/// may be null/absent. `weekCycle` is the slot's own tag `both|A|B` (:184),
/// `startTime`/`endTime` are trimmed strings passed through as stored (U7).
class TimetableSlot {
  final String timetableId;
  final String gradeLevel;
  final String sectionName;
  final int? periodNo;
  final String startTime;
  final String endTime;
  final String subject;
  final String roomNo;
  final String type;
  final String weekCycle;
  final SlotSplitGroup? splitGroup;

  const TimetableSlot({
    this.timetableId = '',
    this.gradeLevel = '',
    this.sectionName = '',
    this.periodNo,
    this.startTime = '',
    this.endTime = '',
    this.subject = '',
    this.roomNo = '',
    this.type = 'regular',
    this.weekCycle = 'both',
    this.splitGroup,
  });

  factory TimetableSlot.fromJson(Map<String, dynamic> j) {
    final wc = readString(j['weekCycle']);
    return TimetableSlot(
      timetableId: readId(j['timetableId']) ?? '',
      gradeLevel: readText(j['gradeLevel']),
      sectionName: readText(j['sectionName']),
      periodNo: readInt(j['periodNo']),
      startTime: readText(j['startTime']),
      endTime: readText(j['endTime']),
      subject: readText(j['subject']),
      roomNo: readText(j['roomNo']),
      type: readString(j['type']) ?? 'regular',
      weekCycle: (wc == 'A' || wc == 'B') ? wc! : 'both',
      splitGroup: j['splitGroup'] is Map ? SlotSplitGroup.fromJson(asJsonMap(j['splitGroup'])) : null,
    );
  }

  String get classLabel => [gradeLevel, sectionName].where((e) => e.isNotEmpty).join(' - ');
}

/// `days[]` (staff-teaching.service.ts:217-222). The day `weekCycle` is ALWAYS
/// null today (U1: A/B parity is undeterminable); it is parsed but the app
/// never derives anything from it.
class TimetableDay {
  /// Calendar date `YYYY-MM-DD` as sent.
  final String date;
  /// 0 = Sunday, computed server-side in UTC from [date].
  final int? dayOfWeek;
  final String? weekCycle;
  final List<TimetableSlot> slots;
  const TimetableDay({this.date = '', this.dayOfWeek, this.weekCycle, this.slots = const []});

  factory TimetableDay.fromJson(Map<String, dynamic> j) => TimetableDay(
        date: readText(j['date']),
        dayOfWeek: readInt(j['dayOfWeek']),
        weekCycle: readString(j['weekCycle']),
        slots: asJsonMapList(j['slots']).map(TimetableSlot.fromJson).toList(),
      );
}

/// `{ from, to, days[] }` (staff-teaching.service.ts:224).
class MyTimetable {
  final String from;
  final String to;
  final List<TimetableDay> days;
  const MyTimetable({this.from = '', this.to = '', this.days = const []});

  factory MyTimetable.fromJson(Map<String, dynamic> j) => MyTimetable(
        from: readText(j['from']),
        to: readText(j['to']),
        days: asJsonMapList(j['days']).map(TimetableDay.fromJson).toList(),
      );
}
