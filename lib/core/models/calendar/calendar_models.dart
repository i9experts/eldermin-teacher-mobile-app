import 'dart:ui' show Color;
import '../../utils/safe_text.dart';
import '../json_helpers.dart';

/// Phase 7c: school calendar entries, circulars and school events.
///
/// Citations (eldermin-backend/src, branch feat/staff-portal 265fcfa): SCC `school-calendar/school-calendar.controller.ts`, SCS
/// `school-calendar/school-calendar.service.ts`, CES `school-calendar/schemas/calendar-event.schema.ts`, CIS `.../circular.schema.ts`,
/// EV `events/schemas/event.schema.ts`, EC/ES `events/events.controller.ts` / `events.service.ts`.
///
/// OWNER RULE: these payloads leak FEE data to every role (`GET /school-calendar/events` merges "Fee Due (n invoices)" rows with
/// "Total outstanding: ..." descriptions, SCS:81-103; `GET /events/:id` appends ticketTypes + promoCodes, ES:157-161). The models below are
/// WHITELIST readers: they read only the named keys, DROP every fee row, and never read `description` of a fee row, `ticketTypes`,
/// `promoCodes`, `sponsors`, `recipientCount`, `createdBy`, `schoolSlug`, audience id lists of students, etc.

/// Wire value `type` of a calendar entry (CES:11-13 + the synthetic `exam` / `academic_term`, SCS:117-151). `fee_due` is deliberately NOT here.
enum CalendarEventType {
  holiday('holiday', 'Holiday', 0xFFE24B4A),
  publicHoliday('public_holiday', 'Public holiday', 0xFFD85A30),
  halfDay('half_day', 'Half day', 0xFF888888),
  exam('exam', 'Exam', 0xFF7F77DD),
  event('event', 'Event', 0xFF1D9E75),
  admissionDeadline('admission_deadline', 'Admission deadline', 0xFF378ADD),
  training('training', 'Training', 0xFFBA7517),
  academicTerm('academic_term', 'Term', 0xFF008300),
  other('other', 'Other', 0xFF0C447C);

  final String wire;
  final String label;
  final int _argb;
  const CalendarEventType(this.wire, this.label, this._argb);

  /// CALENDAR_EVENT_COLORS (CES:15-28).
  Color get color => Color(_argb);

  static CalendarEventType fromWire(String? w) {
    for (final t in values) {
      if (t.wire == w) return t;
    }
    return other;
  }
}

/// Parses a date as the backend sends it. A plain `YYYY-MM-DD` string is UTC midnight (the same instant Mongo stores for it), NOT local
/// midnight, so [storedCalendarDay] gives the same calendar day on every device.
DateTime? parseWireInstant(Object? v) {
  if (v is String) {
    final s = v.trim();
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
    if (m != null) return DateTime.utc(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
    final d = DateTime.tryParse(s);
    return d?.toUtc();
  }
  return readDate(v)?.toUtc();
}

DateTime _localDay(DateTime i) {
  final l = i.toLocal();
  return DateTime(l.year, l.month, l.day);
}

final _hex6 = RegExp(r'^#[0-9a-fA-F]{6}$');

/// One calendar entry (whitelisted).
class CalendarEntry {
  final String id;
  final String title;
  final String description;
  final CalendarEventType type;
  final Color color;
  final DateTime start; // UTC instant as stored
  final DateTime end; // UTC instant as stored (>= start)
  final bool allDay;
  final List<String> gradeLevels;
  final String source; // manual | assessments | academics

  const CalendarEntry({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.color,
    required this.start,
    required this.end,
    required this.allDay,
    this.gradeLevels = const [],
    this.source = 'manual',
  });

  /// True for the finance rows that must never reach the UI (SCS:91-103: id `fee-due-<date>`, type `fee_due`, source `finance`).
  static bool isFeeRow(Map<String, dynamic> j) {
    final type = j['type'], source = j['source'], id = j['_id'] ?? j['id'];
    return type == 'fee_due' || source == 'finance' || (id is String && id.startsWith('fee-due-'));
  }

  /// null = skipped (fee row, or no usable id / title / start date). The `description` key is read only AFTER the fee check.
  static CalendarEntry? tryParse(Map<String, dynamic> j) {
    if (isFeeRow(j)) return null;
    final id = readId(j['_id'] ?? j['id']);
    final title = readString(j['title']);
    final start = parseWireInstant(j['startDate']);
    if (id == null || title == null || start == null) return null;
    var end = parseWireInstant(j['endDate']) ?? start;
    if (end.isBefore(start)) end = start;
    final type = CalendarEventType.fromWire(readString(j['type']));
    final c = readString(j['color']);
    return CalendarEntry(
      id: id,
      title: title,
      description: readText(j['description']),
      type: type,
      color: c != null && _hex6.hasMatch(c) ? Color(0xFF000000 | int.parse(c.substring(1), radix: 16)) : type.color,
      start: start,
      end: end,
      allDay: j['allDay'] is bool ? j['allDay'] as bool : true, // CES:39 default true
      gradeLevels: readStringList(j['gradeLevels']),
      source: readString(j['source']) ?? 'manual',
    );
  }

  /// First / last calendar day (local-midnight DateTime of the y/m/d). All-day entries: the stored UTC components ARE the day (any zone).
  /// Timed entries are real instants: the device-local day. A timed entry ending exactly at local midnight ends the day before.
  DateTime get firstDay => allDay ? storedCalendarDay(start)! : _localDay(start);
  DateTime get lastDay {
    if (allDay) return storedCalendarDay(end)!;
    final e = _localDay(end);
    final l = end.toLocal();
    final atMidnight = l.hour == 0 && l.minute == 0 && l.second == 0 && l.millisecond == 0;
    return atMidnight && end.isAfter(start) && e.isAfter(firstDay) ? DateTime(e.year, e.month, e.day - 1) : e;
  }

  bool get isMultiDay => lastDay.isAfter(firstDay);
  bool coversDay(DateTime d) {
    final x = DateTime(d.year, d.month, d.day);
    return !x.isBefore(firstDay) && !x.isAfter(lastDay);
  }

  /// "All day" / "09:00 - 10:30" (device time) for [day] (a multi-day timed entry shows its own first/last day times).
  String timeLabel() {
    if (allDay) return 'All day';
    String hm(DateTime i) {
      final l = i.toLocal();
      return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
    }

    return start == end ? hm(start) : '${hm(start)} - ${hm(end)}';
  }
}

/// Entries that are valid for the UI: fee rows dropped, row order kept.
List<CalendarEntry> parseCalendarEntries(List<Map<String, dynamic>> rows) => [
      for (final r in rows) ...[
        if (CalendarEntry.tryParse(r) case final e?) e,
      ],
    ];

// ───────────────────────────── Circulars ─────────────────────────────

enum CircularPriority { normal, urgent }

/// CIS:6-8.
const kCircularCategoryLabels = {
  'academic': 'Academic',
  'administrative': 'Administrative',
  'fee': 'Fees',
  'emergency': 'Emergency',
  'sports': 'Sports',
  'cultural': 'Cultural',
  'other': 'Other',
};

class Circular {
  final String id;
  final String title;
  final String bodyText; // HTML flattened by htmlToPlainText
  final List<String> bodyLinks; // anchors of the HTML body (https only)
  final String category;
  final bool urgent;
  final bool requiresAcknowledgment;
  final String status; // draft | scheduled | published
  final DateTime? publishedAt;
  final DateTime? createdAt;
  final List<String> attachmentUrls; // http(s) only
  // Audience (targeting) is read ONLY to decide whether this circular is for a teacher (see [isForStaff]).
  final List<String> audienceRoles;
  final String audienceScope; // school | campus | grade | individual
  final String? audienceCampusId;
  final List<String> audienceStaffIds;
  final List<String> audienceUserIds;

  const Circular({
    required this.id,
    required this.title,
    required this.bodyText,
    this.bodyLinks = const [],
    this.category = 'other',
    this.urgent = false,
    this.requiresAcknowledgment = false,
    this.status = '',
    this.publishedAt,
    this.createdAt,
    this.attachmentUrls = const [],
    this.audienceRoles = const [],
    this.audienceScope = 'school',
    this.audienceCampusId,
    this.audienceStaffIds = const [],
    this.audienceUserIds = const [],
  });

  static Circular? tryParse(Map<String, dynamic> j) {
    final id = readId(j['_id'] ?? j['id']);
    final title = readString(j['title']);
    if (id == null || title == null) return null;
    final body = readText(j['body']);
    final aud = asJsonMap(j['audience']);
    return Circular(
      id: id,
      title: title,
      bodyText: htmlToPlainText(body),
      bodyLinks: htmlLinks(body),
      category: readString(j['category']) ?? 'other',
      urgent: j['priority'] == 'urgent',
      requiresAcknowledgment: j['requiresAcknowledgment'] == true,
      status: readString(j['status']) ?? '',
      publishedAt: parseWireInstant(j['publishedAt']),
      createdAt: parseWireInstant(j['createdAt']),
      attachmentUrls: [for (final u in readStringList(j['attachmentUrls'])) if (safeExternalUri(u) != null) u],
      audienceRoles: readStringList(aud['roles']),
      audienceScope: readString(aud['scope']) ?? 'school',
      audienceCampusId: readId(aud['campusId']),
      audienceStaffIds: readStringList(aud['individualStaffIds']),
      audienceUserIds: readStringList(aud['userIds']),
    );
  }

  String get categoryLabel => kCircularCategoryLabels[category] ?? 'Other';

  /// The moment to show/sort by: published time, else created time.
  DateTime? get when => publishedAt ?? createdAt;

  /// The list endpoint returns EVERY status and EVERY audience to every role (SCS:190-195: filter = schoolSlug [+ status/category] only), so
  /// the app keeps only what a teacher should read: published, addressed to `staff`, and - for narrower scopes - addressed to me.
  /// `campus`: only when it names my campus (unknown campus on either side = shown, UNVERIFIED). `individual`: only when my staff id or
  /// user id is listed. `grade` reaches all staff (SCS:371-379 ignores grades for the staff role).
  bool isForStaff({String? myCampusId, String? myStaffId, String? myUserId}) {
    if (status != 'published') return false;
    if (!audienceRoles.contains('staff')) return false;
    switch (audienceScope) {
      case 'individual':
        return (myStaffId != null && audienceStaffIds.contains(myStaffId)) || (myUserId != null && audienceUserIds.contains(myUserId));
      case 'campus':
        final c = audienceCampusId;
        return c == null || myCampusId == null || c == myCampusId;
      default:
        return true;
    }
  }
}

List<Circular> parseCirculars(List<Map<String, dynamic>> rows) => [
      for (final r in rows) ...[
        if (Circular.tryParse(r) case final c?) c,
      ],
    ];

/// The answer of `POST /school-calendar/circulars/:id/acknowledge` (SCS:283-291): the acknowledgment document. Only the time is read.
class CircularAck {
  final DateTime? acknowledgedAt;
  const CircularAck(this.acknowledgedAt);
  factory CircularAck.fromJson(Map<String, dynamic> j) => CircularAck(parseWireInstant(j['acknowledgedAt']));
}

// ───────────────────────────── School events ─────────────────────────────

/// EV:6-9.
const kEventCategoryLabels = {
  'open_house': 'Open house',
  'annual_day': 'Annual day',
  'sports_day': 'Sports day',
  'fundraiser': 'Fundraiser',
  'alumni_meet': 'Alumni meet',
  'workshop': 'Workshop',
  'parent_teacher_conference': 'Parent-teacher conference',
  'graduation': 'Graduation',
  'other': 'Other',
};

class EventSession {
  final String label;
  final DateTime start;
  final DateTime end;
  const EventSession({required this.label, required this.start, required this.end});

  /// `capacity` is deliberately not read (EV:27).
  static EventSession? tryParse(Map<String, dynamic> j) {
    final s = parseWireInstant(j['startAt']);
    if (s == null) return null;
    final e = parseWireInstant(j['endAt']) ?? s;
    return EventSession(label: readText(j['label']), start: s, end: e.isBefore(s) ? s : e);
  }
}

class SchoolEvent {
  final String id;
  final String title;
  final String descriptionText; // HTML flattened (EV:46 "HTML")
  final List<String> descriptionLinks;
  final String category;
  final String venueName;
  final String venueAddress;
  final List<EventSession> sessions;
  final String status; // draft | published | cancelled | completed
  final String visibility; // public | unlisted | private | internal

  const SchoolEvent({
    required this.id,
    required this.title,
    this.descriptionText = '',
    this.descriptionLinks = const [],
    this.category = 'other',
    this.venueName = '',
    this.venueAddress = '',
    this.sessions = const [],
    this.status = '',
    this.visibility = '',
  });

  /// Whitelist: `ticketTypes`, `promoCodes`, `sponsors`, `theme`, `slug`, `createdBy`, `schoolSlug`, `campusId` are never read.
  static SchoolEvent? tryParse(Map<String, dynamic> j) {
    final id = readId(j['_id'] ?? j['id']);
    final title = readString(j['title']);
    if (id == null || title == null) return null;
    final desc = readText(j['description']);
    final sessions = [
      for (final s in asJsonMapList(j['sessions'])) ...[
        if (EventSession.tryParse(s) case final x?) x,
      ],
    ]..sort((a, b) => a.start.compareTo(b.start));
    return SchoolEvent(
      id: id,
      title: title,
      descriptionText: htmlToPlainText(desc),
      descriptionLinks: htmlLinks(desc),
      category: readString(j['category']) ?? 'other',
      venueName: readText(j['venueName']),
      venueAddress: readText(j['venueAddress']),
      sessions: sessions,
      status: readString(j['status']) ?? '',
      visibility: readString(j['visibility']) ?? '',
    );
  }

  String get categoryLabel => kEventCategoryLabels[category] ?? 'Other';
  bool get cancelled => status == 'cancelled';

  /// `GET /events` returns drafts and private/unlisted events to every role (ES:147-152: only `schoolSlug` [+ status/category] filters). A
  /// teacher sees published / cancelled / completed events whose visibility is public or internal; anything else (including an unknown value)
  /// stays hidden.
  bool get isListedForStaff => (status == 'published' || status == 'cancelled' || status == 'completed') && (visibility == 'public' || visibility == 'internal');

  DateTime? get firstStart => sessions.isEmpty ? null : sessions.first.start;
  DateTime? get lastEnd => sessions.isEmpty ? null : sessions.map((s) => s.end).reduce((a, b) => a.isAfter(b) ? a : b);
}

List<SchoolEvent> parseSchoolEvents(List<Map<String, dynamic>> rows) => [
      for (final r in rows) ...[
        if (SchoolEvent.tryParse(r) case final e?) e,
      ],
    ];
