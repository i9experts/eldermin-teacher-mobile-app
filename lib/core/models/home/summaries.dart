import '../../utils/home_time.dart';
import 'teaching.dart';

/// One assignment that still has work to grade.
class GradingItem {
  final HomeworkAssignment assignment;
  final int ungraded;
  const GradingItem(this.assignment, this.ungraded);
}

/// Result of the "homework to grade" aggregation (N+1: see
/// [selectGradingCandidates]).
class HomeworkToGrade {
  final List<GradingItem> items; // only assignments with ungraded > 0
  final int totalUngraded;
  final int assignmentsChecked;

  /// More candidate assignments existed than the cap, so older ones were not checked.
  final bool capped;

  /// Submission look-ups that failed (their counts are NOT in [totalUngraded]).
  final int failedLookups;

  const HomeworkToGrade({
    this.items = const [],
    this.totalUngraded = 0,
    this.assignmentsChecked = 0,
    this.capped = false,
    this.failedLookups = 0,
  });
}

/// Max assignments whose submissions are fetched per refresh (each costs one request).
const int kHomeworkLookupCap = 10;

/// Assignments worth a `/submissions` call: this teacher's own (client-side
/// check, the server does not enforce ownership), not draft/graded, with at
/// least one turned-in/graded submission (`submissionsCount > 0`), most
/// recent due date first, at most [cap]. Returns the full candidate count too.
({List<HomeworkAssignment> picked, int candidates}) selectGradingCandidates(
  List<HomeworkAssignment> all,
  String staffId, {
  int cap = kHomeworkLookupCap,
}) {
  final c = all
      .where((a) =>
          a.id.isNotEmpty &&
          a.teacherId == staffId &&
          a.status != 'draft' &&
          a.status != 'graded' &&
          a.submissionsCount > 0)
      .toList()
    ..sort((a, b) {
      final x = a.dueDate, y = b.dueDate;
      if (x == null && y == null) return 0;
      if (x == null) return 1;
      if (y == null) return -1;
      return y.compareTo(x);
    });
  return (picked: c.take(cap).toList(), candidates: c.length);
}

/// Lesson plans needing attention: awaiting approval and rejected.
class LessonPlanSummary {
  final List<LessonPlan> submitted;
  final List<LessonPlan> rejected;
  const LessonPlanSummary({this.submitted = const [], this.rejected = const []});
  bool get isEmpty => submitted.isEmpty && rejected.isEmpty;
}

/// Today's substitutions split from the teacher's point of view.
class SubstitutionsToday {
  /// I am the substitute (status assigned/completed).
  final List<Substitution> covering;

  /// My own period was given to someone else (or still needs cover).
  final List<Substitution> covered;
  const SubstitutionsToday({this.covering = const [], this.covered = const []});
  bool get isEmpty => covering.isEmpty && covered.isEmpty;
}

/// The fixtures endpoint matches `originalTeacherId` OR `substituteTeacherId`
/// and has no "for me" flag, so the app splits them (shapes doc section 6).
SubstitutionsToday splitSubstitutions(List<Substitution> all, String staffId) {
  int byStart(Substitution a, Substitution b) =>
      (parseHm(a.startTime) ?? 1 << 20).compareTo(parseHm(b.startTime) ?? 1 << 20);
  final covering = all
      .where((s) =>
          s.substituteTeacherId == staffId && (s.status == 'assigned' || s.status == 'completed'))
      .toList()
    ..sort(byStart);
  final covered = all
      .where((s) =>
          s.originalTeacherId == staffId && s.substituteTeacherId != staffId && s.status != 'cancelled')
      .toList()
    ..sort(byStart);
  return SubstitutionsToday(covering: covering, covered: covered);
}
