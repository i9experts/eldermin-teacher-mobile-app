import 'package:get/get.dart';
import '../../../../core/models/ptm/ptm_models.dart';
import '../../../../core/services/ptm_repository.dart';
import '../../../../core/utils/home_time.dart';
import '../../../../core/utils/ptm_rules.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/models/section_state.dart';

/// My parent meetings (`/ptm`): tabs Upcoming / Today / Past / Cancelled.
///
/// Two reads, both `GET /teaching/ptm?teacherId=<my staffId>` (ptm.controller.ts:19-22 -> ptm.service.ts:124-137, at most 200 rows each,
/// scheduledDate DESC): one for meetings from the start of today on (`from`), one for the ones before it (`to`), so neither the future nor the
/// recent past crowds the other out of the 200-row cap. The tabs are cut locally ([buildPtmTabs]: the Home agenda semantics, UTC-midnight
/// `scheduledDate`, "Earlier today"). `staffId` comes only from `/staff-portal/me`.
class PtmController extends GetxController {
  static const int serverLimit = 200;

  final PtmRepository? _repo;
  final AuthController? _auth;
  final Clock clock;
  PtmController({PtmRepository? repository, AuthController? auth, Clock? clock})
      : _repo = repository,
        _auth = auth,
        clock = clock ?? DateTime.now;

  PtmRepository get repo => _repo ?? Get.find<PtmRepository>();
  AuthController get auth => _auth ?? Get.find<AuthController>();

  final tab = PtmTab.today.obs;
  final load = Rx<SectionState<PtmTabs>>(const SectionState.loading());

  /// True when a window came back full (200): older / later meetings may exist that are not shown.
  final aheadCut = false.obs;
  final pastCut = false.obs;

  List<ParentMeeting> _all = [];
  int _token = 0;
  bool _tabChosen = false;

  PtmTabs get tabs => load.value.data ?? const PtmTabs();

  @override
  void onReady() {
    super.onReady();
    reload();
  }

  void selectTab(PtmTab t) {
    _tabChosen = true;
    tab.value = t;
  }

  Future<void> reload({bool userInitiated = false}) async {
    final staffId = auth.staffId;
    if (staffId == null || staffId.isEmpty) {
      load.value = const SectionState.error('Your profile is not loaded yet. Pull down to try again.');
      return;
    }
    final token = ++_token;
    final previous = load.value;
    if (!previous.hasData) load.value = const SectionState.loading();
    final now = clock();
    final w = ptmWindows(now);
    try {
      final results = await Future.wait([
        repo.fetchMeetings(staffId: staffId, from: w.aheadFrom),
        repo.fetchMeetings(staffId: staffId, to: w.pastTo),
      ]);
      if (token != _token) return;
      aheadCut.value = results[0].length >= serverLimit;
      pastCut.value = results[1].length >= serverLimit;
      _all = [...results[0], ...results[1]];
      _rebuild(now, firstLoad: !previous.hasData);
    } catch (e) {
      if (token != _token) return;
      final failed = SectionState<PtmTabs>.fromError(e);
      load.value = previous.hasData && failed.status == SectionStatus.error && !userInitiated ? previous : failed;
    }
  }

  void _rebuild(DateTime now, {bool firstLoad = false}) {
    final t = buildPtmTabs(_all, now);
    if (_all.isEmpty) {
      load.value = const SectionState.empty();
      return;
    }
    load.value = SectionState.data(t);
    if (firstLoad && !_tabChosen) {
      // Open on what matters: today's meetings, else the next ones, else the recent past.
      tab.value = t.todayCount > 0 ? PtmTab.today : (t.upcoming.isNotEmpty ? PtmTab.upcoming : (t.past.isNotEmpty ? PtmTab.past : PtmTab.cancelled));
    }
  }

  /// A meeting changed (confirmed, rescheduled, outcome, cancelled, created): replace / add it and re-cut the tabs without a request.
  void upsert(ParentMeeting m) {
    if (m.id.isEmpty) return;
    final i = _all.indexWhere((x) => x.id == m.id);
    if (i >= 0) {
      _all = [..._all]..[i] = m;
    } else {
      _all = [m, ..._all];
    }
    _rebuild(clock());
  }

  ParentMeeting? find(String id) {
    for (final m in _all) {
      if (m.id == id) return m;
    }
    return null;
  }
}
