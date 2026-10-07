import 'package:get/get.dart';
import '../../../../core/models/assessments/reference_models.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/services/reference_repository.dart';
import '../../../../core/utils/class_match.dart';
import '../../../../core/utils/roster_scope.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/models/section_state.dart';

enum CurriculumScope {
  mySubjects('My subjects'),
  myGrades('All my grades');

  final String label;
  const CurriculumScope(this.label);
}

/// Curriculum frameworks (SLOs) for my grades, read-only (`/curriculum`, `/curriculum/:id`). `GET /academics/curriculum?status=active` is
/// tenant-wide with no campus or teacher scoping (academics.service.ts:375-383), so the app keeps curricula of my grades; "My subjects"
/// narrows to the subjects I teach in that grade.
class CurriculumController extends GetxController {
  final ReferenceRepository? _repo;
  final AuthController? _auth;
  final PermissionService? _perms;

  CurriculumController({ReferenceRepository? repository, AuthController? auth, PermissionService? permissions})
      : _repo = repository,
        _auth = auth,
        _perms = permissions;

  ReferenceRepository get repo => _repo ?? Get.find<ReferenceRepository>();
  AuthController get auth => _auth ?? Get.find<AuthController>();
  PermissionService get perms => _perms ?? Get.find<PermissionService>();

  final state = Rx<SectionState<List<Curriculum>>>(const SectionState.loading());
  final scope = CurriculumScope.mySubjects.obs;
  int _token = 0;

  bool get canView {
    auth.staffMe.value;
    return perms.canAccess('academics:view');
  }

  List<ClassRef> get myClasses => teacherClassesOf(auth.staffMe.value?.teacherProfile);
  List<Curriculum> get items => state.value.data ?? const [];

  bool forMyGrade(Curriculum c) => myClasses.any((k) => sameGrade(k.grade, c.gradeLevel));
  bool forMySubject(Curriculum c) => myClasses.any((k) => sameGrade(k.grade, c.gradeLevel) && k.subjects.any((s) => s.trim().toLowerCase() == c.subjectName.trim().toLowerCase()));

  List<Curriculum> get filtered => scope.value == CurriculumScope.mySubjects ? items.where(forMySubject).toList() : items;
  int countFor(CurriculumScope s) => s == CurriculumScope.mySubjects ? items.where(forMySubject).length : items.length;
  void setScope(CurriculumScope s) => scope.value = s;

  @override
  void onReady() {
    super.onReady();
    load();
  }

  Future<void> load({bool force = false}) async {
    if (!canView) {
      state.value = const SectionState.forbidden();
      return;
    }
    if (!force && state.value.hasData) return;
    final token = ++_token;
    if (!state.value.hasData) state.value = const SectionState.loading();
    try {
      final all = await repo.curricula();
      if (token != _token) return;
      final mine = all.where((c) => c.isVisibleToTeachers && forMyGrade(c)).toList()
        ..sort((a, b) {
          final g = a.gradeLevel.compareTo(b.gradeLevel);
          return g != 0 ? g : a.subjectName.compareTo(b.subjectName);
        });
      if (mine.isEmpty) {
        state.value = const SectionState.empty();
      } else {
        if (!mine.any(forMySubject)) scope.value = CurriculumScope.myGrades;
        state.value = SectionState.data(mine);
      }
    } catch (e) {
      if (token != _token) return;
      state.value = SectionState<List<Curriculum>>.fromError(e);
    }
  }

  Future<void> reload() async {
    await auth.refreshProfile(force: true);
    await load(force: true);
  }

  Future<void> ensureLoaded() async {
    if (state.value.hasData || state.value.status == SectionStatus.empty) return;
    await load(force: state.value.status == SectionStatus.error);
  }

  Curriculum? byId(String id) {
    for (final c in items) {
      if (c.id == id) return c;
    }
    return null;
  }
}

/// One curriculum (`/curriculum/:id`): from the list's cache, else `GET /academics/curriculum/:id` (tenant check only), then the same
/// grade test (a curriculum of a grade I do not teach is refused).
class CurriculumDetailController extends GetxController {
  final String id;
  final CurriculumController? _list;
  final ReferenceRepository? _repo;

  CurriculumDetailController({required this.id, CurriculumController? list, ReferenceRepository? repository})
      : _list = list,
        _repo = repository;

  CurriculumController get list => _list ?? Get.find<CurriculumController>();
  ReferenceRepository get repo => _repo ?? Get.find<ReferenceRepository>();

  final state = Rx<SectionState<Curriculum>>(const SectionState.loading());

  @override
  void onReady() {
    super.onReady();
    load();
  }

  Future<void> load({bool force = false}) async {
    if (!list.canView) {
      state.value = const SectionState.forbidden();
      return;
    }
    if (force) {
      await list.load(force: true);
    } else {
      await list.ensureLoaded();
    }
    final cached = list.byId(id);
    if (cached != null) {
      state.value = SectionState.data(cached);
      return;
    }
    if (list.state.value.status == SectionStatus.forbidden) {
      state.value = const SectionState.forbidden();
      return;
    }
    try {
      final one = await repo.curriculum(id);
      if (!one.isVisibleToTeachers) {
        state.value = const SectionState.error('This curriculum is not available.'); // a draft / archived one opened by id
        return;
      }
      if (!list.forMyGrade(one)) {
        state.value = const SectionState.error("This curriculum isn't available for your classes.");
        return;
      }
      state.value = SectionState.data(one);
    } catch (e) {
      state.value = SectionState<Curriculum>.fromError(e);
    }
  }
}
