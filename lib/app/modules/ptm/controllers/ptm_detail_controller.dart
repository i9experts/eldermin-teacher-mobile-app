import 'package:get/get.dart';
import '../../../../core/models/classroom/student_models.dart';
import '../../../../core/models/ptm/ptm_models.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/services/ptm_repository.dart';
import '../../../../core/utils/home_time.dart';
import '../../../../core/utils/ptm_rules.dart';
import '../../../common/action_failure.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/models/section_state.dart';
import 'ptm_controller.dart';

sealed class PtmResult {
  const PtmResult();
}

class PtmDone extends PtmResult {
  final ParentMeeting meeting;
  final String notice;
  const PtmDone(this.meeting, this.notice);
}

class PtmInvalid extends PtmResult {
  final Map<String, String> errors;
  const PtmInvalid(this.errors);
}

class PtmFailed extends PtmResult {
  final ActionFailure failure;

  /// The text to show: the server's own wording where it said something useful.
  final String text;
  const PtmFailed(this.failure, this.text);
}

/// Not allowed (wrong status / not mine) or another action is running.
class PtmIgnored extends PtmResult {
  const PtmIgnored();
}

/// One meeting (`/ptm/:id`): read by id, then confirm / reschedule / record outcome / cancel / action items, each offered only when
/// [allowedPtmActions] says so (my meeting AND a status the action is valid for). One action at a time. After a rejected action the meeting is
/// re-read, because a 404 / 400 / 409 means the server state is not what the screen showed.
class PtmDetailController extends GetxController {
  final String id;
  final PtmRepository? _repo;
  final AuthController? _auth;
  final Clock clock;
  PtmDetailController({required this.id, PtmRepository? repository, AuthController? auth, Clock? clock})
      : _repo = repository,
        _auth = auth,
        clock = clock ?? DateTime.now;

  PtmRepository get repo => _repo ?? Get.find<PtmRepository>();
  AuthController get auth => _auth ?? Get.find<AuthController>();

  final state = Rx<SectionState<ParentMeeting>>(const SectionState.loading());

  /// The meeting id does not exist (404 'Meeting not found', PS:142) as opposed to an undeployed route.
  final notFound = false.obs;
  final busy = Rxn<PtmAction>();
  final itemBusy = <String>{}.obs;
  final history = Rx<SectionState<List<ParentMeeting>>>(const SectionState.loading());
  bool _historyRequested = false;
  int _token = 0;

  ParentMeeting? get meeting => state.value.data;
  String? get myStaffId => auth.staffId;
  bool get isMine => meeting != null && isMyMeeting(meeting!, myStaffId);
  Set<PtmAction> get allowed => meeting == null ? const {} : allowedPtmActions(meeting!, myStaffId);
  bool can(PtmAction a) => busy.value == null && allowed.contains(a);

  @override
  void onReady() {
    super.onReady();
    // Show the row the list already holds while the fresh copy loads.
    if (Get.isRegistered<PtmController>()) {
      final seed = Get.find<PtmController>().find(id);
      if (seed != null) state.value = SectionState.data(seed);
    }
    reload();
  }

  Future<void> reload() async {
    final token = ++_token;
    final previous = state.value;
    if (!previous.hasData) state.value = const SectionState.loading();
    notFound.value = false;
    try {
      final m = await repo.fetchMeeting(id);
      if (token != _token) return;
      state.value = SectionState.data(m);
      _pushToList(m);
      loadHistory(force: true);
    } catch (e) {
      if (token != _token) return;
      if (e is ApiException && e.statusCode == 404 && !e.message.startsWith('Cannot ')) {
        notFound.value = true;
        state.value = const SectionState.empty();
      } else {
        final failed = SectionState<ParentMeeting>.fromError(e);
        state.value = previous.hasData && failed.status == SectionStatus.error ? previous : failed;
      }
    }
  }

  /// Earlier meetings of the same student (`GET /teaching/ptm/student/:studentId/history`, any teacher), loaded once the meeting is known.
  Future<void> loadHistory({bool force = false}) async {
    final m = meeting;
    if (m == null || m.studentId.isEmpty) return;
    if (_historyRequested && !force && history.value.status != SectionStatus.error) return;
    _historyRequested = true;
    if (!history.value.hasData) history.value = const SectionState.loading();
    try {
      final rows = (await repo.fetchStudentHistory(m.studentId)).where((x) => x.id != m.id).toList();
      history.value = rows.isEmpty ? const SectionState.empty() : SectionState.data(rows);
    } catch (e) {
      history.value = SectionState<List<ParentMeeting>>.fromError(e);
    }
  }

  void _pushToList(ParentMeeting m) {
    if (Get.isRegistered<PtmController>()) Get.find<PtmController>().upsert(m);
  }

  // ── actions ──────────────────────────────────────────────

  Future<PtmResult> _run(PtmAction action, String what, Future<ParentMeeting> Function() call, String notice) async {
    if (!can(action)) return const PtmIgnored();
    busy.value = action;
    try {
      final m = await call();
      state.value = SectionState.data(m);
      _pushToList(m);
      return PtmDone(m, notice);
    } catch (e) {
      final f = ActionFailure.from(e, what: what, keep: '');
      final text = _textOf(e, f);
      if (f.kind == ActionFailureKind.notFound || f.kind == ActionFailureKind.conflict || f.kind == ActionFailureKind.validation) {
        // The server disagrees with what is on screen: show the truth.
        await reload();
      }
      return PtmFailed(f, text);
    } finally {
      busy.value = null;
    }
  }

  String _textOf(Object e, ActionFailure f) {
    if (f.serverMessage.isNotEmpty) return f.serverMessage;
    if (f.kind == ActionFailureKind.notFound && e is ApiException && e.message.trim().isNotEmpty) return e.message.trim();
    return f.message;
  }

  Future<PtmResult> confirm() => _run(PtmAction.confirm, 'confirm this meeting', () => repo.confirm(id), 'Meeting confirmed.');

  /// Reschedule to [day] and [start]/[end] ("HH:mm"). The server resets the status to `requested` (PS:166-174), the notice says so.
  Future<PtmResult> reschedule({required DateTime? day, required String? start, required String? end}) async {
    if (!can(PtmAction.reschedule)) return const PtmIgnored();
    final errors = <String, String>{};
    final d = validatePtmDay(day, clock());
    if (d != null) errors['day'] = d;
    errors.addAll(validatePtmTimes(start, end, allowBothEmpty: meeting!.timeRange.isEmpty));
    if (errors.isNotEmpty) return PtmInvalid(errors);
    return _run(PtmAction.reschedule, 'reschedule this meeting', () => repo.reschedule(id, day: day!, startTime: start, endTime: end),
        'Meeting rescheduled. It needs to be confirmed again.');
  }

  Future<PtmResult> recordOutcome(PtmOutcomeRequest r) async {
    if (!can(PtmAction.recordOutcome)) return const PtmIgnored();
    final errors = validateOutcome(r);
    if (errors.isNotEmpty) return PtmInvalid(errors);
    return _run(PtmAction.recordOutcome, 'record the outcome', () => repo.recordOutcome(id, r),
        r.parentAttended ? 'Outcome recorded: the parent attended.' : 'Outcome recorded: marked as a no-show.');
  }

  Future<PtmResult> cancel(String reason) async {
    if (!can(PtmAction.cancel)) return const PtmIgnored();
    final t = reason.trim();
    if (t.isEmpty) return const PtmInvalid({'reason': 'Tell the parent why the meeting is cancelled'});
    if (t.length > kPtmReasonMax) return const PtmInvalid({'reason': 'The reason can be at most $kPtmReasonMax characters'});
    return _run(PtmAction.cancel, 'cancel this meeting', () => repo.cancel(id, t), 'Meeting cancelled. The guardian is notified.');
  }

  /// Marks an action item done / pending. Optimistic with rollback; one request per item at a time.
  Future<PtmResult> setActionItem(String itemId, {required bool done}) async {
    final m = meeting;
    if (m == null || !allowed.contains(PtmAction.toggleActionItems) || itemBusy.contains(itemId)) return const PtmIgnored();
    final i = m.actionItems.indexWhere((a) => a.id == itemId);
    if (i < 0 || m.actionItems[i].done == done) return const PtmIgnored();
    itemBusy.add(itemId);
    final optimistic = [for (final a in m.actionItems) a.id == itemId ? a.copyWith(done: done) : a];
    state.value = SectionState.data(m.copyWith(actionItems: optimistic));
    try {
      final saved = await repo.setActionItem(id, itemId, done: done);
      state.value = SectionState.data(saved);
      _pushToList(saved);
      return PtmDone(saved, done ? 'Marked as done.' : 'Marked as pending.');
    } catch (e) {
      state.value = SectionState.data(m);
      final f = ActionFailure.from(e, what: 'update this action item', keep: '');
      return PtmFailed(f, _textOf(e, f));
    } finally {
      itemBusy.remove(itemId);
    }
  }

  /// The student to preselect in the new-message screen for 'Message guardian' (names only; the guardian is chosen there).
  StudentSummary? get messageStudent {
    final m = meeting;
    if (m == null || m.studentId.isEmpty || !allowed.contains(PtmAction.messageGuardian)) return null;
    return StudentSummary(id: m.studentId, firstName: m.studentName, grade: m.gradeLevel, section: m.sectionName, academicYear: m.academicYear.isEmpty ? null : m.academicYear);
  }
}
