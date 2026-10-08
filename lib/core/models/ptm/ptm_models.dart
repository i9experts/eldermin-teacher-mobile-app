import '../home/teaching.dart' show PtmMeeting;
import '../json_helpers.dart';

/// Backend source cited as PTM = eldermin-backend `src/modules/teaching/` (branch feat/staff-portal, 265fcfa):
/// `ptm.controller.ts` (PC), `ptm.service.ts` (PS), `schemas/ptm-meeting.schema.ts` (PSC).

/// `PTMMeeting.status` (PSC:51: requested|confirmed|completed|cancelled|no_show). An unknown value is kept as [unknown] and no action is
/// offered for it.
enum PtmStatus {
  requested('requested', 'Requested'),
  confirmed('confirmed', 'Confirmed'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled'),
  noShow('no_show', 'No-show'),
  unknown('', 'Unknown');

  final String wire;
  final String label;
  const PtmStatus(this.wire, this.label);

  static PtmStatus parse(String? s) => values.firstWhere((e) => e.wire == s && e != unknown, orElse: () => unknown);

  /// requested | confirmed: the meeting has not happened and is not cancelled.
  bool get isOpen => this == requested || this == confirmed;
}

/// One entry of `PTMMeeting.actionItems` (`PTMActionItem`, PSC:16-23): `_id, description, assignedTo?, dueDate?, status (pending|done)`.
class PtmActionItem {
  final String id;
  final String description;
  final String assignedTo;
  final DateTime? dueDate;
  final bool done;
  const PtmActionItem({required this.id, this.description = '', this.assignedTo = '', this.dueDate, this.done = false});

  factory PtmActionItem.fromJson(Map<String, dynamic> j) => PtmActionItem(
        id: readId(j['_id'] ?? j['id']) ?? '',
        description: readText(j['description']),
        assignedTo: readText(j['assignedTo']),
        dueDate: readDate(j['dueDate']),
        done: readString(j['status']) == 'done',
      );

  PtmActionItem copyWith({bool? done}) => PtmActionItem(id: id, description: description, assignedTo: assignedTo, dueDate: dueDate, done: done ?? this.done);

  /// The calendar day the item is due (the writer sends a date; UTC components are the day).
  DateTime? get dueDay => storedCalendarDay(dueDate);
}

/// A parent-teacher meeting (`PTMMeeting`, PSC:26-70). Consumed: `_id, studentId, studentName, gradeLevel, sectionName, teacherId,
/// teacherName, scheduledDate, startTime, endTime, guardianName, status, academicYear, discussionPoints[], meetingNotes, actionItems[],
/// parentAttended, cancelledReason, cancelledBy, requestedBy`.
///
/// NEVER parsed (owner rule, B5): `guardianPhone`, `guardianEmail` (the server strips both for teachers, teacher-student-projection.util.ts
/// deny-list, but the app would not read them even if they arrived), `notifiedAt`, `notificationStatus`, `tenantId`, `institutionId`, `campusId`.
class ParentMeeting {
  final String id;
  final String studentId;
  final String studentName;
  final String gradeLevel;
  final String sectionName;
  final String teacherId;
  final String teacherName;
  final DateTime? scheduledDate;
  final String startTime;
  final String endTime;
  final String guardianName;
  final PtmStatus status;
  final String academicYear;
  final List<String> discussionPoints;
  final String meetingNotes;
  final List<PtmActionItem> actionItems;
  final bool parentAttended;
  final String cancelledReason;
  final String cancelledBy;
  final String requestedBy;

  const ParentMeeting({
    required this.id,
    this.studentId = '',
    this.studentName = '',
    this.gradeLevel = '',
    this.sectionName = '',
    this.teacherId = '',
    this.teacherName = '',
    this.scheduledDate,
    this.startTime = '',
    this.endTime = '',
    this.guardianName = '',
    this.status = PtmStatus.unknown,
    this.academicYear = '',
    this.discussionPoints = const [],
    this.meetingNotes = '',
    this.actionItems = const [],
    this.parentAttended = false,
    this.cancelledReason = '',
    this.cancelledBy = '',
    this.requestedBy = '',
  });

  factory ParentMeeting.fromJson(Map<String, dynamic> j) => ParentMeeting(
        id: readId(j['_id'] ?? j['id']) ?? '',
        studentId: readId(j['studentId']) ?? '',
        studentName: readText(j['studentName']),
        gradeLevel: readText(j['gradeLevel']),
        sectionName: readText(j['sectionName']),
        teacherId: readId(j['teacherId']) ?? '',
        teacherName: readText(j['teacherName']),
        scheduledDate: readDate(j['scheduledDate']),
        startTime: readText(j['startTime']),
        endTime: readText(j['endTime']),
        guardianName: readText(j['guardianName']),
        status: PtmStatus.parse(readString(j['status'])),
        academicYear: readText(j['academicYear']),
        discussionPoints: readStringList(j['discussionPoints']).where((e) => e.trim().isNotEmpty).toList(),
        meetingNotes: readText(j['meetingNotes']),
        actionItems: asJsonMapList(j['actionItems']).map(PtmActionItem.fromJson).where((a) => a.id.isNotEmpty).toList(),
        parentAttended: readBool(j['parentAttended']),
        cancelledReason: readText(j['cancelledReason']),
        cancelledBy: readText(j['cancelledBy']),
        requestedBy: readText(j['requestedBy']),
      );

  String get classLabel => [gradeLevel, sectionName].where((e) => e.isNotEmpty).join(' - ');
  String get timeRange => [startTime, endTime].where((e) => e.isNotEmpty).join(' - ');

  /// The picked day (UTC components of the stored instant: the web and this app both write `YYYY-MM-DD`, stored as UTC midnight).
  DateTime? get day => storedCalendarDay(scheduledDate);

  /// The slim row the Home agenda logic ([buildPtmAgenda]) works on.
  PtmMeeting toAgendaRow() => PtmMeeting(
        id: id,
        studentName: studentName,
        gradeLevel: gradeLevel,
        sectionName: sectionName,
        teacherId: teacherId,
        scheduledDate: scheduledDate,
        startTime: startTime,
        endTime: endTime,
        guardianName: guardianName,
        status: status.wire,
      );

  ParentMeeting copyWith({List<PtmActionItem>? actionItems}) => ParentMeeting(
        id: id,
        studentId: studentId,
        studentName: studentName,
        gradeLevel: gradeLevel,
        sectionName: sectionName,
        teacherId: teacherId,
        teacherName: teacherName,
        scheduledDate: scheduledDate,
        startTime: startTime,
        endTime: endTime,
        guardianName: guardianName,
        status: status,
        academicYear: academicYear,
        discussionPoints: discussionPoints,
        meetingNotes: meetingNotes,
        actionItems: actionItems ?? this.actionItems,
        parentAttended: parentAttended,
        cancelledReason: cancelledReason,
        cancelledBy: cancelledBy,
        requestedBy: requestedBy,
      );
}

/// Body of `POST /teaching/ptm` (PC:43-47 -> PS:69-122, no DTO: the raw body is read as `data`): `studentId, teacherId, scheduledDate,
/// startTime, endTime, academicYear (REQUIRED by the schema, PSC:52, a missing one makes the save fail), discussionPoints[]`. The web sends
/// exactly these (Eldermin-Frontend PTMTab.tsx:30-33) with `scheduledDate` as `YYYY-MM-DD`.
class PtmCreateRequest {
  final String studentId;
  final String teacherId;
  final DateTime day;
  final String startTime;
  final String endTime;
  final String academicYear;
  final List<String> discussionPoints;
  const PtmCreateRequest({required this.studentId, required this.teacherId, required this.day, required this.startTime, required this.endTime, required this.academicYear, this.discussionPoints = const []});

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'teacherId': teacherId,
        'scheduledDate': wireDay(day),
        'startTime': startTime,
        'endTime': endTime,
        'academicYear': academicYear,
        'discussionPoints': [for (final p in discussionPoints) if (p.trim().isNotEmpty) p.trim()],
      };
}

/// One action item typed in the outcome form (`PS:191-195`: `description, assignedTo, dueDate, status`).
class ActionItemDraft {
  final String description;
  final String assignedTo;
  final DateTime? dueDay;
  const ActionItemDraft({this.description = '', this.assignedTo = '', this.dueDay});

  bool get isBlank => description.trim().isEmpty && assignedTo.trim().isEmpty && dueDay == null;

  Map<String, dynamic> toJson() => {
        'description': description.trim(),
        if (assignedTo.trim().isNotEmpty) 'assignedTo': assignedTo.trim(),
        if (dueDay != null) 'dueDate': wireDay(dueDay!),
        'status': 'pending',
      };
}

/// Body of `PATCH /teaching/ptm/:id/outcome` (PC:61-65 -> PS:181-198): `parentAttended` decides the status (true -> completed, false ->
/// no_show, PS:188), `meetingNotes` (stored `|| ''`), `actionItems[]` (REPLACES the stored list, PS:191-196).
class PtmOutcomeRequest {
  final bool parentAttended;
  final String meetingNotes;
  final List<ActionItemDraft> actionItems;
  const PtmOutcomeRequest({required this.parentAttended, this.meetingNotes = '', this.actionItems = const []});

  Map<String, dynamic> toJson() => {
        'parentAttended': parentAttended,
        'meetingNotes': meetingNotes.trim(),
        'actionItems': [for (final a in actionItems) if (!a.isBlank) a.toJson()],
      };
}
