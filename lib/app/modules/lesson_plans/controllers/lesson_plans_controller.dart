import 'package:get/get.dart';
import '../../../../core/models/academic/lesson_plan_models.dart';
import '../../../../core/services/lesson_plan_repository.dart';
import '../../../../core/services/permission_service.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/models/section_state.dart';

/// Status filter of the list. `all` shows everything.
enum LessonPlanFilter {
  all('All', null),
  draft('Drafts', LessonPlanStatus.draft),
  submitted('Awaiting', LessonPlanStatus.submitted),
  rejected('Rejected', LessonPlanStatus.rejected),
  approved('Approved', LessonPlanStatus.approved),
  overdue('Overdue', LessonPlanStatus.overdue);

  final String label;
  final LessonPlanStatus? status;
  const LessonPlanFilter(this.label, this.status);

  static LessonPlanFilter fromArgument(Object? v) {
    if (v is LessonPlanFilter) return v;
    for (final f in values) {
      if (f.status?.wire == v || f.name == v) return f;
    }
    return all;
  }
}

/// "My lesson plans" (`/lesson-plans`): MY plans (`GET /teaching/lesson-plans?teacherId=<my id>`), filtered on the client (the server
/// returns at most 100, newest plan date first, with no pagination: teaching.service.ts:151-162). Create / edit / submit controllers push
/// their results in through [upsert] so the list never needs a re-fetch after a write. `Get.arguments` may carry a status (`'rejected'`,
/// `'submitted'`: the Home card) to open pre-filtered.
class LessonPlansController extends GetxController {
  final LessonPlanRepository? _repo;
  final AuthController? _auth;
  final PermissionService? _perms;

  LessonPlansController({LessonPlanRepository? repository, AuthController? auth, PermissionService? permissions, LessonPlanFilter? initialFilter})
      : _repo = repository,
        _auth = auth,
        _perms = permissions,
        _initialFilter = initialFilter;

  final LessonPlanFilter? _initialFilter;

  LessonPlanRepository get repo => _repo ?? Get.find<LessonPlanRepository>();
  AuthController get auth => _auth ?? Get.find<AuthController>();
  PermissionService get perms => _perms ?? Get.find<PermissionService>();

  final state = Rx<SectionState<List<LessonPlanRecord>>>(const SectionState.loading());
  final filter = LessonPlanFilter.all.obs;
  int _token = 0;

  /// The ids my plans can be stored under: my Staff id (lesson-plan.schema.ts:9) and my TeacherProfile id (legacy rows written by the
  /// web, which sends the profile id; teaching.service.ts:381-392 tolerates both). Both come from `/staff-portal/me` only.
  List<String> get myIds {
    final out = <String>[];
    final s = auth.staffId;
    final p = auth.teacherProfileId;
    if (s != null && s.isNotEmpty) out.add(s);
    if (p != null && p.isNotEmpty && p != s) out.add(p);
    return out;
  }

  bool get canView {
    auth.staffMe.value;
    return perms.canAccess('teaching:view');
  }

  List<LessonPlanRecord> get items => state.value.data ?? const [];

  List<LessonPlanRecord> get filtered {
    final st = filter.value.status;
    return st == null ? items : items.where((p) => p.status == st).toList();
  }

  int countFor(LessonPlanFilter f) => f.status == null ? items.length : items.where((p) => p.status == f.status).length;

  /// The server caps one request at 100 rows: when that many came back, older plans may be missing.
  bool get maybeTruncated => items.length >= LessonPlanRepository.serverLimit;

  @override
  void onInit() {
    super.onInit();
    filter.value = _initialFilter ?? LessonPlanFilter.fromArgument(Get.arguments);
  }

  @override
  void onReady() {
    super.onReady();
    load();
  }

  void setFilter(LessonPlanFilter f) => filter.value = f;

  Future<void> load({bool force = false}) async {
    if (!canView) {
      state.value = const SectionState.forbidden();
      return;
    }
    if (myIds.isEmpty) {
      state.value = const SectionState.error("Your teacher profile isn't loaded yet. Pull down to refresh.");
      return;
    }
    if (!force && state.value.hasData) return;
    final token = ++_token;
    if (!state.value.hasData) state.value = const SectionState.loading();
    try {
      final list = await repo.fetchMine(myIds);
      if (token != _token) return;
      state.value = list.isEmpty ? const SectionState.empty() : SectionState.data(list);
    } catch (e) {
      if (token != _token) return;
      state.value = SectionState<List<LessonPlanRecord>>.fromError(e);
    }
  }

  Future<void> reload() async {
    await auth.refreshProfile(force: true);
    await load(force: true);
  }

  /// Resolves once the first load finished (detail screens opened from a Home link before the list was requested).
  Future<void> ensureLoaded() async {
    if (state.value.hasData || state.value.status == SectionStatus.empty) return;
    await load(force: state.value.status == SectionStatus.error);
  }

  LessonPlanRecord? byId(String id) {
    for (final p in items) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Inserts or replaces [p] (after create / edit / submit), keeping the newest-plan-date-first order of the server.
  void upsert(LessonPlanRecord p) {
    final list = [...items];
    final i = list.indexWhere((x) => x.id == p.id);
    if (i >= 0) {
      list[i] = p;
    } else {
      list.add(p);
    }
    final far = DateTime.fromMillisecondsSinceEpoch(0);
    list.sort((a, b) => (b.planDate ?? far).compareTo(a.planDate ?? far));
    state.value = SectionState.data(list);
  }
}
