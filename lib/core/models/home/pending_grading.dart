import '../json_helpers.dart';

/// One assignment with ungraded work. Backend:
/// eldermin-backend/src/staff-portal/staff-teaching.service.ts pendingGrading()
/// :58-117, items built at :104-114 (route staff-portal.controller.ts:87-88).
class PendingGradingItem {
  final String assignmentId;
  final String title;
  final String subject;
  final String gradeLevel;
  /// Null on the wire when the assignment has no section (:109).
  final String sectionName;
  final DateTime? dueDate;
  /// NOTE: the number of UNGRADED submissions (submitted|late), despite the
  /// name (:87, kept per the agreed contract).
  final int submittedCount;
  /// All roster rows incl. pending/missed/graded (:86).
  final int totalSubmissions;
  final DateTime? oldestSubmittedAt;

  const PendingGradingItem({
    required this.assignmentId,
    this.title = '',
    this.subject = '',
    this.gradeLevel = '',
    this.sectionName = '',
    this.dueDate,
    this.submittedCount = 0,
    this.totalSubmissions = 0,
    this.oldestSubmittedAt,
  });

  factory PendingGradingItem.fromJson(Map<String, dynamic> j) => PendingGradingItem(
        assignmentId: readId(j['assignmentId']) ?? '',
        title: readText(j['title']),
        subject: readText(j['subject']),
        gradeLevel: readText(j['gradeLevel']),
        sectionName: readText(j['sectionName']),
        dueDate: readDate(j['dueDate']),
        submittedCount: readInt(j['submittedCount']) ?? 0,
        totalSubmissions: readInt(j['totalSubmissions']) ?? 0,
        oldestSubmittedAt: readDate(j['oldestSubmittedAt']),
      );

  String get classLabel => [gradeLevel, sectionName].where((e) => e.isNotEmpty).join(' - ');
}

/// `{ total, items[], generatedAt }` (staff-teaching.service.ts:102-116).
/// `total` spans ALL my non-draft assignments (:94), independent of `limit`,
/// so it can exceed the sum of [items].
class PendingGrading {
  final int total;
  final List<PendingGradingItem> items;
  final DateTime? generatedAt;
  const PendingGrading({this.total = 0, this.items = const [], this.generatedAt});

  factory PendingGrading.fromJson(Map<String, dynamic> j) => PendingGrading(
        total: readInt(j['total']) ?? 0,
        items: asJsonMapList(j['items']).map(PendingGradingItem.fromJson).where((i) => i.assignmentId.isNotEmpty).toList(),
        generatedAt: readDate(j['generatedAt']),
      );
}
