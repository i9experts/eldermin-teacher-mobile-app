import 'package:get/get.dart';
import '../../../../core/models/calendar/calendar_models.dart';
import '../../../../core/services/circular_local_state.dart';
import '../../../../core/services/school_calendar_repository.dart';
import '../../../common/action_failure.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/models/section_state.dart';

/// Circulars tab of `/calendar` (read + acknowledge). The list endpoint returns every status and audience (SCS:190-195), so [rows] keeps only published
/// circulars addressed to staff / me ([Circular.isForStaff]). Acknowledge is offered ONLY on a circular with `requiresAcknowledgment`, because the
/// route has no role restriction (SCC:105-109) and the web has the API but no UI (WEB_FOLLOWUPS): a teacher acknowledging is not prevented by code.
class CircularsController extends GetxController {
  final SchoolCalendarRepository? _repo;
  final AuthController? _auth;
  final CircularLocalState _local;
  CircularsController({SchoolCalendarRepository? repository, AuthController? auth, CircularLocalState? local})
      : _repo = repository,
        _auth = auth,
        _local = local ?? CircularLocalState();

  SchoolCalendarRepository get repo => _repo ?? Get.find<SchoolCalendarRepository>();
  AuthController? get auth => _auth ?? (Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null);

  final state = Rx<SectionState<List<Circular>>>(const SectionState.loading());
  final acked = <String>{}.obs;
  final opened = <String>{}.obs;
  final acking = <String>{}.obs;
  final ackFailure = <String, ActionFailure>{}.obs;
  int _token = 0;

  String get _uid => auth?.user.value?.id ?? '';

  @override
  void onReady() {
    super.onReady();
    load();
  }

  List<Circular> get rows => state.value.data ?? const [];

  Future<void> load({bool userInitiated = false}) async {
    final token = ++_token;
    final previous = state.value;
    if (!previous.hasData) state.value = const SectionState.loading();
    try {
      final loadedAcked = await _local.load('acked', _uid);
      final loadedOpened = await _local.load('opened', _uid);
      final list = await repo.fetchCirculars();
      if (token != _token) return;
      acked.addAll(loadedAcked);
      opened.addAll(loadedOpened);
      final me = auth?.staffMe.value;
      final mine = [
        for (final c in list)
          if (c.isForStaff(myCampusId: me?.campus?.id, myStaffId: me?.staffId, myUserId: auth?.user.value?.id)) c
      ]..sort((a, b) => (b.when ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(a.when ?? DateTime.fromMillisecondsSinceEpoch(0)));
      state.value = mine.isEmpty ? const SectionState.empty() : SectionState.data(mine);
    } catch (e) {
      if (token != _token) return;
      final failed = SectionState<List<Circular>>.fromError(e);
      state.value = previous.hasData && failed.status == SectionStatus.error && !userInitiated ? previous : failed;
    }
  }

  bool isNew(Circular c) => !opened.contains(c.id);
  bool needsAck(Circular c) => c.requiresAcknowledgment && !acked.contains(c.id);

  /// Number of circulars still waiting for my acknowledgment on this device (badge on the tab).
  int get pendingAcks => rows.where(needsAck).length;

  Future<void> markOpened(Circular c) async {
    if (opened.add(c.id)) await _local.save('opened', _uid, opened.toSet());
  }

  /// Acknowledge once. A second tap while the call is in flight, or on an already acknowledged circular, does nothing. A failure keeps the
  /// button (403 / 404 show their own text; offline / 5xx may be retried).
  Future<bool> acknowledge(Circular c) async {
    if (!c.requiresAcknowledgment || acked.contains(c.id) || acking.contains(c.id)) return false;
    acking.add(c.id);
    ackFailure.remove(c.id);
    try {
      await repo.acknowledge(c.id);
      acked.add(c.id);
      await _local.save('acked', _uid, acked.toSet());
      return true;
    } catch (e) {
      ackFailure[c.id] = ActionFailure.from(e, what: 'acknowledge this circular', keep: '');
      return false;
    } finally {
      acking.remove(c.id);
    }
  }
}
