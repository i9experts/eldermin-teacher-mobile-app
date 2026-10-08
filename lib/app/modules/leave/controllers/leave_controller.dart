import 'package:get/get.dart';
import '../../../../core/models/leave/leave_models.dart';
import '../../../../core/services/leave_repository.dart';
import '../../home/models/section_state.dart';

/// My leave (`/leave`): balance cards + request history, two independent reads (`GET /hr/leave/self/balance`, `GET /hr/leave/self/history`,
/// hr.controller.ts:241-247). The server decides "me" from the login. A failure of one never hides the other.
class LeaveController extends GetxController {
  final LeaveRepository? _repo;
  LeaveController({LeaveRepository? repository}) : _repo = repository;

  LeaveRepository get repo => _repo ?? Get.find<LeaveRepository>();

  final balance = Rx<SectionState<LeaveBalanceSummary>>(const SectionState.loading());
  final history = Rx<SectionState<List<StaffLeaveRequest>>>(const SectionState.loading());
  int _bToken = 0, _hToken = 0;

  /// Both sections say the same thing (403 / not deployed): the screen shows one message instead of two.
  SectionStatus? get wholeScreenStatus {
    final a = balance.value.status, b = history.value.status;
    if (a == b && (a == SectionStatus.forbidden || a == SectionStatus.unavailable)) return a;
    return null;
  }

  @override
  void onReady() {
    super.onReady();
    reload();
  }

  Future<void> reload({bool userInitiated = false}) => Future.wait([loadBalance(userInitiated: userInitiated), loadHistory(userInitiated: userInitiated)]);

  Future<void> loadBalance({bool userInitiated = false}) async {
    final token = ++_bToken;
    final previous = balance.value;
    if (!previous.hasData) balance.value = const SectionState.loading();
    try {
      final b = await repo.fetchBalance();
      if (token != _bToken) return;
      balance.value = SectionState.data(b);
    } catch (e) {
      if (token != _bToken) return;
      final failed = SectionState<LeaveBalanceSummary>.fromError(e);
      balance.value = previous.hasData && failed.status == SectionStatus.error && !userInitiated ? previous : failed;
    }
  }

  Future<void> loadHistory({bool userInitiated = false}) async {
    final token = ++_hToken;
    final previous = history.value;
    if (!previous.hasData) history.value = const SectionState.loading();
    try {
      final rows = await repo.fetchHistory();
      if (token != _hToken) return;
      history.value = rows.isEmpty ? const SectionState.empty() : SectionState.data(rows);
    } catch (e) {
      if (token != _hToken) return;
      final failed = SectionState<List<StaffLeaveRequest>>.fromError(e);
      history.value = previous.hasData && failed.status == SectionStatus.error && !userInitiated ? previous : failed;
    }
  }

  /// A request was just created: show it at the top at once, then re-read both sections (the server owns the numbers).
  void added(StaffLeaveRequest r) {
    final rows = history.value.data ?? const <StaffLeaveRequest>[];
    history.value = SectionState.data([r, ...rows.where((x) => x.id != r.id)]);
    reload(userInitiated: false);
  }

  List<StaffLeaveRequest> get rows => history.value.data ?? const [];
}
