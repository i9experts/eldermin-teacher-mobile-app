import 'package:get/get.dart';
import '../../../../core/models/home/teaching.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/services/fixtures_repository.dart';
import '../../../../core/utils/fixture_rules.dart';
import '../../../../core/utils/home_time.dart';
import '../../../common/action_failure.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/models/section_state.dart';

sealed class CompleteResult {
  const CompleteResult();
}

class CompleteDone extends CompleteResult {
  final Substitution fixture;
  const CompleteDone(this.fixture);
}

class CompleteFailed extends CompleteResult {
  final String text;
  const CompleteFailed(this.text);
}

class CompleteIgnored extends CompleteResult {
  const CompleteIgnored();
}

/// Substitutions where I am the substitute or the original teacher (`/fixtures`, `/fixtures/:id`). TEACHER view only: assign, cancel and
/// generate are admin actions and do not exist here.
///
/// One read: `GET /teaching/fixtures?teacherId=<my staffId>&from=<today-14d>` (substitution.controller.ts:42-45 -> substitution.service.ts:
/// 232-245: the server matches original OR substitute, `date` DESC / `periodNo` ASC, at most 200). The two tabs are cut locally by which side
/// I am on. 'Mark complete' (`PATCH .../:id/complete`, SS:223-230) is offered only for MY assigned fixtures as substitute; the server does not
/// check the caller, so that is UI gating. There is no get-one endpoint: the detail screen resolves from the loaded list.
class FixturesController extends GetxController {
  static const int serverLimit = 200;

  final FixturesRepository? _repo;
  final AuthController? _auth;
  final Clock clock;
  FixturesController({FixturesRepository? repository, AuthController? auth, Clock? clock})
      : _repo = repository,
        _auth = auth,
        clock = clock ?? DateTime.now;

  FixturesRepository get repo => _repo ?? Get.find<FixturesRepository>();
  AuthController get auth => _auth ?? Get.find<AuthController>();
  String? get myStaffId => auth.staffId;

  final tab = FixtureTab.covering.obs;
  final load = Rx<SectionState<List<Substitution>>>(const SectionState.loading());
  final completing = RxnString();
  final cut = false.obs;
  int _token = 0;
  bool _tabChosen = false;

  List<Substitution> get all => load.value.data ?? const [];
  List<Substitution> rows(FixtureTab t) => rowsFor(t, all, myStaffId);

  @override
  void onReady() {
    super.onReady();
    reload();
  }

  void selectTab(FixtureTab t) {
    _tabChosen = true;
    tab.value = t;
  }

  Future<void> reload({bool userInitiated = false}) async {
    final staffId = myStaffId;
    if (staffId == null || staffId.isEmpty) {
      load.value = const SectionState.error('Your profile is not loaded yet. Pull down to try again.');
      return;
    }
    final token = ++_token;
    final previous = load.value;
    if (!previous.hasData) load.value = const SectionState.loading();
    try {
      final list = await repo.fetchFixtures(staffId: staffId, from: fixturesFrom(clock()));
      if (token != _token) return;
      cut.value = list.length >= serverLimit;
      load.value = list.isEmpty ? const SectionState.empty() : SectionState.data(list);
      if (!_tabChosen && list.isNotEmpty && rows(FixtureTab.covering).isEmpty && rows(FixtureTab.covered).isNotEmpty) tab.value = FixtureTab.covered;
    } catch (e) {
      if (token != _token) return;
      final failed = SectionState<List<Substitution>>.fromError(e);
      load.value = previous.hasData && failed.status == SectionStatus.error && !userInitiated ? previous : failed;
    }
  }

  Substitution? find(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// The row for [id] (deep link / notification): loads the list when it is not loaded yet.
  Future<Substitution?> resolve(String id) async {
    if (find(id) != null) return find(id);
    if (!load.value.hasData) await reload(userInitiated: true);
    return find(id);
  }

  bool canComplete(Substitution s) => completing.value == null && canMarkComplete(s, myStaffId);

  /// Marks my assigned cover as done. The caller has confirmed. Refused (ignored) when it is not mine / not `assigned` / another request is
  /// running. A rejection (404 'Fixture not found or not in an assigned state') re-reads the list so the row shows the real status.
  Future<CompleteResult> complete(String id) async {
    final s = find(id);
    if (s == null || !canComplete(s)) return const CompleteIgnored();
    completing.value = id;
    try {
      final updated = await repo.complete(id);
      // Keep the row we hold (who/when/where) and take the status the server answered.
      _replace(s.copyWithStatus(updated.status.isEmpty ? 'completed' : updated.status));
      return CompleteDone(find(id) ?? s);
    } catch (e) {
      final f = ActionFailure.from(e, what: 'mark this as complete', keep: '');
      final text = f.serverMessage.isNotEmpty ? f.serverMessage : (f.kind == ActionFailureKind.notFound && e is ApiException && e.message.trim().isNotEmpty ? e.message.trim() : f.message);
      if (f.kind == ActionFailureKind.notFound || f.kind == ActionFailureKind.conflict) await reload(userInitiated: true);
      return CompleteFailed(text);
    } finally {
      completing.value = null;
    }
  }

  void _replace(Substitution u) {
    final list = [for (final s in all) s.id == u.id ? u : s];
    load.value = SectionState.data(list);
  }
}
