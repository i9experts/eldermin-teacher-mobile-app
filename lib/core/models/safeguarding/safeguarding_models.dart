import '../classroom/student_models.dart';
import '../json_helpers.dart';

/// Phase 7c: raising a safeguarding concern (WRITE ONLY: the app never lists, reads or shows cases).
///
/// Backend (eldermin-backend/src, branch feat/staff-portal 265fcfa): `compliance/compliance.controller.ts:112-118` `POST /compliance/safeguarding`,
/// `@RequirePermission('safeguarding:report')` (every staff role has it, `auth/permissions.matrix.ts:111,120,...`), body typed `any` (NO DTO, no
/// whitelist), handler `createSafeguardingCase({ ...dto, schoolSlug, reportedBy: dto.reportedBy || userName }, requestingUser)`; service
/// `compliance.service.ts:251-258` does `new safeguardingModel({ ...data, reportedDate: new Date(data.reportedDate || Date.now()), campusId: <from the
/// JWT user> })`. SO THE WHOLE BODY BECOMES THE CASE (mass assignment, hardening-backlog #9). Schema `compliance/schemas/compliance.schema.ts:63-119`.
///
/// Fields a REPORTER may set (the only keys the app ever sends): see [kSafeguardingRequestKeys].
/// NEVER sent (server-owned or lead-owned): status, assignedTo(Id), reportedBy (server fills it from the JWT name: `dto.reportedBy || userName`),
/// reportedById, schoolSlug, campusId (the server derives it from the user), caseNumber (generated, schema :113-119), confidential, parentNotified*,
/// policeInvolved, socialServicesInvolved, externalReferral/Agency, resolution*, progressNotes, attachments, _id, createdAt, updatedAt.

/// The EXACT set of request keys. One constant, asserted by tests: adding a key here is a deliberate, reviewed act.
const Set<String> kSafeguardingRequestKeys = {
  'title', // required (schema :9)
  'description', // required (schema :10)
  'type', // required enum (schema :11-16)
  'severity', // enum low|medium|high|critical, default medium (schema :77)
  'reportedDate', // the date the concern arose (YYYY-MM-DD -> UTC midnight); schema `reportedDate` is "required" and the service defaults it to now
  'actionsTaken', // free text: immediate action taken (schema :92)
  // optional, only when the concern is about one of MY students:
  'studentId', // ObjectId (schema :79)
  'studentName', // denormalised text (schema :78): the server does NOT derive it from studentId
  'studentGrade', // denormalised text (schema :80)
};

/// `type` enum (schema :11-16).
enum ConcernType {
  physical('physical', 'Physical harm'),
  emotional('emotional', 'Emotional harm'),
  sexual('sexual', 'Sexual harm'),
  neglect('neglect', 'Neglect'),
  bullying('bullying', 'Bullying'),
  cyberbullying('cyberbullying', 'Online bullying'),
  radicalisation('radicalisation', 'Radicalisation'),
  other('other', 'Something else');

  final String wire;
  final String label;
  const ConcernType(this.wire, this.label);
}

/// `severity` enum (schema :77). The reporter's first impression; the safeguarding lead decides.
enum ConcernSeverity {
  low('low', 'Low'),
  medium('medium', 'Medium'),
  high('high', 'High'),
  critical('critical', 'Urgent');

  final String wire;
  final String label;
  const ConcernSeverity(this.wire, this.label);
}

const int kConcernTitleMax = 120; // client limit (no server limit exists: UNVERIFIED)
const int kConcernTextMax = 5000;

/// A draft concern. Lives only in memory (the controller clears it when the screen closes).
class SafeguardingReport {
  final String title;
  final String description;
  final ConcernType type;
  final ConcernSeverity severity;
  final DateTime day; // local calendar day
  final String actionsTaken;
  final StudentSummary? student;

  const SafeguardingReport({required this.title, required this.description, required this.type, this.severity = ConcernSeverity.medium, required this.day, this.actionsTaken = '', this.student});

  /// The request body. Exactly [kSafeguardingRequestKeys] (a subset: student keys only with a student, `actionsTaken` only when typed).
  Map<String, dynamic> toRequestBody() {
    final s = student;
    return {
      'title': title.trim(),
      'description': description.trim(),
      'type': type.wire,
      'severity': severity.wire,
      'reportedDate': wireDay(day),
      if (actionsTaken.trim().isNotEmpty) 'actionsTaken': actionsTaken.trim(),
      if (s != null) ...{
        'studentId': s.id,
        'studentName': s.fullName,
        'studentGrade': s.grade.isEmpty ? '' : (s.section.isEmpty ? s.grade : '${s.grade} - ${s.section}'),
      },
    };
  }
}

/// What the app keeps of the server's answer (the created case document, 201): ONLY the reference number, if there is one. Nothing else is read.
class SafeguardingReceipt {
  final String? reference;
  const SafeguardingReceipt(this.reference);

  /// Tolerant on purpose: the case is already stored when this runs, so an odd body must never turn a successful report into a "failed" one (that
  /// would invite a duplicate report).
  factory SafeguardingReceipt.fromResponse(Object? body) => SafeguardingReceipt(body is Map ? readString(body['caseNumber']) : null);
}
