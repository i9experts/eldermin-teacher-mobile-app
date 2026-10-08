import 'package:get/get.dart';
import '../../../../core/models/messaging/student_leave_models.dart';
import '../../../../core/services/messaging_repository.dart';
import '../../../common/action_failure.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/models/section_state.dart';

sealed class ReviewResult {
  const ReviewResult();
}

class ReviewDone extends ReviewResult {
  final StudentLeaveRequest leave;
  const ReviewDone(this.leave);
}

/// 409: somebody (or another device) decided it first. [decided] is the refreshed row (who / when / what), null when it could not be found.
class ReviewConflict extends ReviewResult {
  final String serverText;
  final StudentLeaveRequest? decided;
  const ReviewConflict(this.serverText, this.decided);
}

class ReviewFailed extends ReviewResult {
  final ActionFailure failure;
  const ReviewFailed(this.failure);
}

class ReviewIgnored extends ReviewResult {
  const ReviewIgnored();
}

/// Student leave requests of MY class (class teacher only; routes `/student-leaves`, `/student-leaves/:id`).
///
/// One list per tab, each fetched with its own `status` (`GET /staff-portal/student-leaves?status=&limit=100`, SPS:327-341), so the server's
/// limit applies per status. There is no "get one" endpoint: the detail screen finds the request in the loaded lists. Review = `PATCH
/// .../:id {status, remarks?}`; the guardian is notified by the server (SPS:360-365). Only class teachers are offered the module (UI gating;
/// the server answers 403 'Only class teachers can review student leave requests.' to anyone else, SPS:105).
class StudentLeavesController extends GetxController {
  static const int listLimit = 100;

  final MessagingRepository? _repo;
  final AuthController? _auth;
  StudentLeavesController({MessagingRepository? repository, AuthController? auth})
      : _repo = repository,
        _auth = auth;

  MessagingRepository get repo => _repo ?? Get.find<MessagingRepository>();
  AuthController get auth => _auth ?? Get.find<AuthController>();

  bool get allowed => auth.isClassTeacher;

  final tab = LeaveStatus.pending.obs;
  final lists = <LeaveStatus, SectionState<List<StudentLeaveRequest>>>{}.obs;
  final reviewing = RxnString();
  final _tokens = <LeaveStatus, int>{};
  final _stale = <LeaveStatus>{};

  SectionState<List<StudentLeaveRequest>> stateOf(LeaveStatus s) => lists[s] ?? const SectionState.loading();

  /// Count shown on a tab: the loaded rows (null while unknown). A list at the request limit may hide more.
  int? countOf(LeaveStatus s) {
    final st = lists[s];
    return st != null && (st.hasData || st.status == SectionStatus.empty) ? (st.data?.length ?? 0) : null;
  }

  bool get pendingMayBeCut => (lists[LeaveStatus.pending]?.data?.length ?? 0) >= listLimit;

  @override
  void onReady() {
    super.onReady();
    if (allowed) loadTab(LeaveStatus.pending);
  }

  void selectTab(LeaveStatus s) {
    tab.value = s;
    final st = lists[s];
    if (st == null || _stale.contains(s) || st.status == SectionStatus.error) loadTab(s);
  }

  Future<void> loadTab(LeaveStatus s, {bool userInitiated = false}) async {
    if (!allowed) return;
    final token = (_tokens[s] ?? 0) + 1;
    _tokens[s] = token;
    final previous = lists[s];
    if (previous == null || !previous.hasData) lists[s] = const SectionState.loading();
    try {
      final rows = await repo.fetchStudentLeaves(status: s, limit: listLimit);
      if (_tokens[s] != token) return;
      _stale.remove(s);
      lists[s] = rows.isEmpty ? const SectionState.empty() : SectionState.data(rows);
    } catch (e) {
      if (_tokens[s] != token) return;
      final failed = SectionState<List<StudentLeaveRequest>>.fromError(e);
      lists[s] = (previous?.hasData ?? false) && failed.status == SectionStatus.error && !userInitiated ? previous! : failed;
    }
  }

  Future<void> reload() => loadTab(tab.value, userInitiated: true);

  /// Finds a request in any loaded list.
  StudentLeaveRequest? find(String id) {
    for (final st in lists.values) {
      for (final l in st.data ?? const <StudentLeaveRequest>[]) {
        if (l.id == id) return l;
      }
    }
    return null;
  }

  /// Makes sure [id] can be found (deep link / notification): loads pending, then decided lists, stopping at the first hit.
  /// Returns the request or null when the server does not list it (not in my class, removed, beyond the list limit).
  Future<StudentLeaveRequest?> resolve(String id) async {
    if (!allowed) return null;
    var hit = find(id);
    if (hit != null) return hit;
    for (final s in LeaveStatus.values) {
      if (lists[s] == null) await loadTab(s);
      hit = find(id);
      if (hit != null) return hit;
    }
    return null;
  }

  /// Approve / reject. [remarks] is optional (max [kLeaveRemarksMax], SPS dto :16). One review at a time.
  Future<ReviewResult> review(String id, LeaveStatus decision, {String? remarks}) async {
    if (!allowed || reviewing.value != null || decision == LeaveStatus.pending) return const ReviewIgnored();
    final r = remarks?.trim() ?? '';
    if (r.length > kLeaveRemarksMax) {
      return ReviewFailed(ActionFailure(ActionFailureKind.validation, 'Remarks can be at most $kLeaveRemarksMax characters.', serverMessage: 'Remarks can be at most $kLeaveRemarksMax characters.'));
    }
    reviewing.value = id;
    try {
      final updated = await repo.reviewStudentLeave(id, status: decision, remarks: r);
      _applyDecision(updated);
      return ReviewDone(updated);
    } catch (e) {
      final f = ActionFailure.from(e, what: 'review this request', keep: '');
      if (f.kind == ActionFailureKind.conflict) {
        // Already decided elsewhere: re-read the lists so the screen shows who decided and when.
        await Future.wait([for (final s in LeaveStatus.values) loadTab(s, userInitiated: true)]);
        return ReviewConflict(f.serverMessage.isEmpty ? 'This request was already decided.' : f.serverMessage, find(id));
      }
      return ReviewFailed(f);
    } finally {
      reviewing.value = null;
    }
  }

  void _applyDecision(StudentLeaveRequest u) {
    // Out of its old list(s), into the list of its new status (when that list is loaded; otherwise it is re-read when opened).
    for (final s in LeaveStatus.values) {
      final st = lists[s];
      final rows = st?.data;
      if (rows == null) continue;
      final kept = rows.where((l) => l.id != u.id).toList();
      if (s == u.status) {
        kept.insert(0, u);
      }
      lists[s] = kept.isEmpty ? const SectionState.empty() : SectionState.data(kept);
    }
    if (lists[u.status] == null) _stale.add(u.status);
  }
}
