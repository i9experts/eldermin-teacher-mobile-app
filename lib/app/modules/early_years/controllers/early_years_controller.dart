import 'package:get/get.dart';
import '../../../../core/models/early_years/ece_models.dart';
import '../../../../core/services/early_years_repository.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/utils/early_years_scope.dart';
import '../../../../core/utils/roster_scope.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/models/section_state.dart';

/// Early Years home (`/early-years`): the Early Years children of MY classes.
///
/// Source: `GET /ece/children` (every Early Years child of the school; the route has no class or campus filter on `main`) narrowed to the
/// classes in `GET /staff-portal/me` with the tolerant class matcher. That narrowing is UI-ONLY scoping (see `early_years_scope.dart`): the
/// unfiltered list is dropped as soon as it is filtered and never cached or logged.
class EarlyYearsController extends GetxController {
  final EarlyYearsRepository? _repo;
  final AuthController? _auth;
  final PermissionService? _perms;

  EarlyYearsController({EarlyYearsRepository? repository, AuthController? auth, PermissionService? permissions})
      : _repo = repository,
        _auth = auth,
        _perms = permissions;

  EarlyYearsRepository get repo => _repo ?? Get.find<EarlyYearsRepository>();
  AuthController get auth => _auth ?? Get.find<AuthController>();
  PermissionService get perms => _perms ?? Get.find<PermissionService>();

  final state = Rx<SectionState<List<EceChild>>>(const SectionState.loading());

  /// -1 = all my classes, else an index into [classes].
  final classFilter = (-1).obs;
  final query = ''.obs;
  int _token = 0;

  bool get canView {
    auth.staffMe.value;
    return perms.canAccess('early-years:view');
  }

  /// Creating observations and portfolio entries also needs `early-years:manage` (the teacher role has it).
  bool get canManage {
    auth.staffMe.value;
    return perms.canAccess('early-years:manage');
  }

  List<ClassRef> get classes {
    auth.staffMe.value;
    return teacherClassesOf(auth.staffMe.value?.teacherProfile);
  }

  List<EceChild> get all => state.value.data ?? const [];

  List<EceChild> get visible {
    final cs = classes;
    final q = query.value.trim().toLowerCase();
    return [
      for (final k in all)
        if ((classFilter.value < 0 || classFilter.value >= cs.length || childInClass(cs[classFilter.value], k)) &&
            (q.isEmpty || k.fullName.toLowerCase().contains(q) || k.studentCode.toLowerCase().contains(q)))
          k
    ];
  }

  /// A child of my classes by id (the detail screens use this to skip a refetch and to refuse a child outside my classes).
  EceChild? childById(String id) {
    for (final k in all) {
      if (k.id == id) return k;
    }
    return null;
  }

  @override
  void onReady() {
    super.onReady();
    load();
  }

  void setClassFilter(int i) => classFilter.value = i;

  Future<void> load({bool force = false}) async {
    if (!canView) {
      state.value = const SectionState.forbidden();
      return;
    }
    final cs = classes;
    if (cs.isEmpty) {
      state.value = const SectionState.empty();
      return;
    }
    if (!force && state.value.hasData) return;
    final token = ++_token;
    if (!state.value.hasData) state.value = const SectionState.loading();
    try {
      final mine = myEarlyYearsChildren(await repo.fetchChildren(), cs);
      if (token != _token) return;
      state.value = mine.isEmpty ? const SectionState.empty() : SectionState.data(mine);
    } catch (e) {
      if (token != _token) return;
      state.value = SectionState<List<EceChild>>.fromError(e, previous: state.value);
    }
  }

  Future<void> reload() async {
    await auth.refreshProfile(force: true);
    await load(force: true);
  }
}
