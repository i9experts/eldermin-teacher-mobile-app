import 'package:get/get.dart';
import '../../../../core/models/homework/homework_models.dart';
import '../../../../core/services/homework_repository.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/utils/home_time.dart';
import '../../../../core/utils/timetable_week.dart' show dateOnly;
import '../../auth/controllers/auth_controller.dart';
import '../../home/models/section_state.dart';

enum HomeworkFilter { all, drafts, active, overdue }

extension HomeworkFilterLabel on HomeworkFilter {
  String get label => switch (this) {
        HomeworkFilter.all => 'All',
        HomeworkFilter.drafts => 'Drafts',
        HomeworkFilter.active => 'Active',
        HomeworkFilter.overdue => 'Overdue',
      };
}

/// "My homework" (`/homework`): MY assignments (`GET /teaching/assignments?teacherId=<my staffId>`), filtered / sorted / paged
/// on the client because the endpoint returns the whole unbounded list (teaching.service.ts:861-871). Other controllers
/// (form, detail) push their results into [items] through [upsert] / [remove] so the list never needs a re-fetch after a write.
class HomeworkController extends GetxController {
  final HomeworkRepository? _repo;
  final AuthController? _auth;
  final PermissionService? _perms;
  final Clock clock;

  HomeworkController({HomeworkRepository? repository, AuthController? auth, PermissionService? permissions, Clock? clock})
      : _repo = repository,
        _auth = auth,
        _perms = permissions,
        clock = clock ?? DateTime.now;

  HomeworkRepository get repo => _repo ?? Get.find<HomeworkRepository>();
  AuthController get auth => _auth ?? Get.find<AuthController>();
  PermissionService get perms => _perms ?? Get.find<PermissionService>();

  /// Items per "page" shown (client-side paging of the unbounded server list).
  static const int pageSize = 20;

  final state = Rx<SectionState<List<Assignment>>>(const SectionState.loading());
  final filter = HomeworkFilter.all.obs;

  /// true = latest due date first (the server's own order); false = earliest first.
  final newestFirst = true.obs;
  final shown = pageSize.obs;
  int _token = 0;

  DateTime get today => dateOnly(clock());

  /// Gate: the module is visible with `teaching:view` (Classes grid). Creating is also allowed by the backend for the teacher
  /// role (`STAFF_WRITE_ROLES` includes TEACHER, teaching.controller.ts:197) even though the web matrix has no `teaching:manage`
  /// for teachers: UI-gating only, the server is the security layer.
  bool get canView {
    auth.staffMe.value;
    return perms.canAccess('teaching:view');
  }

  List<Assignment> get items => state.value.data ?? const [];

  /// After filter and sort, before paging.
  List<Assignment> get filtered {
    final t = today;
    final out = [
      for (final a in items)
        if (switch (filter.value) {
          HomeworkFilter.all => true,
          HomeworkFilter.drafts => a.isDraft,
          HomeworkFilter.active => const {HomeworkPhase.active, HomeworkPhase.dueToday}.contains(a.phaseOn(t)),
          HomeworkFilter.overdue => a.phaseOn(t) == HomeworkPhase.overdue,
        })
          a
    ];
    out.sort((a, b) {
      final x = a.dueDay, y = b.dueDay;
      if (x == null && y == null) return a.title.compareTo(b.title);
      if (x == null) return 1; // no due date: always last
      if (y == null) return -1;
      return newestFirst.value ? y.compareTo(x) : x.compareTo(y);
    });
    return out;
  }

  List<Assignment> get visible => filtered.take(shown.value).toList();
  bool get hasMore => filtered.length > shown.value;

  int countFor(HomeworkFilter f) {
    final t = today;
    return switch (f) {
      HomeworkFilter.all => items.length,
      HomeworkFilter.drafts => items.where((a) => a.isDraft).length,
      HomeworkFilter.active => items.where((a) => const {HomeworkPhase.active, HomeworkPhase.dueToday}.contains(a.phaseOn(t))).length,
      HomeworkFilter.overdue => items.where((a) => a.phaseOn(t) == HomeworkPhase.overdue).length,
    };
  }

  @override
  void onReady() {
    super.onReady();
    load();
  }

  void setFilter(HomeworkFilter f) {
    filter.value = f;
    shown.value = pageSize;
  }

  void toggleSort() {
    newestFirst.value = !newestFirst.value;
    shown.value = pageSize;
  }

  void showMore() => shown.value += pageSize;

  Future<void> load({bool force = false}) async {
    if (!canView) {
      state.value = const SectionState.forbidden();
      return;
    }
    final id = auth.staffId;
    if (id == null || id.isEmpty) {
      state.value = const SectionState.error("Your teacher profile isn't loaded yet. Pull down to refresh.");
      return;
    }
    if (!force && state.value.hasData) return;
    final token = ++_token;
    if (!state.value.hasData) state.value = const SectionState.loading();
    try {
      final list = await repo.fetchMine(id);
      if (token != _token) return;
      state.value = list.isEmpty ? const SectionState.empty() : SectionState.data(list);
    } catch (e) {
      if (token != _token) return;
      state.value = SectionState<List<Assignment>>.fromError(e);
    }
  }

  Future<void> reload() async {
    await auth.refreshProfile(force: true);
    await load(force: true);
  }

  Assignment? byId(String id) {
    for (final a in items) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Inserts or replaces [a] (after create / edit / assign / grading counters).
  void upsert(Assignment a) {
    final list = [...items];
    final i = list.indexWhere((x) => x.id == a.id);
    if (i >= 0) {
      list[i] = a;
    } else {
      list.add(a);
    }
    state.value = SectionState.data(list);
  }

  void remove(String id) {
    final list = items.where((a) => a.id != id).toList();
    state.value = list.isEmpty ? const SectionState.empty() : SectionState.data(list);
  }
}
