import 'package:get/get.dart';
import '../../../../core/models/behaviour/behaviour_models.dart';
import '../../../../core/models/classroom/student_models.dart';
import '../../../../core/services/behaviour_repository.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/services/students_repository.dart';
import '../../../../core/utils/roster_scope.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/models/section_state.dart';

enum BehaviourScope { mine, classes }

/// Behaviour & Tarbiyah home (`/behaviour`): the behaviour records of MY classes' students and the ones I logged.
///
/// Source: `GET /behaviour/records?grade=<raw grade>` per distinct raw grade string of my classes (the route filters by an EXACT grade
/// string only; no section / reporter / class filter, behaviour.service.ts:154-193), then re-scoped client-side with the tolerant class
/// matcher so records of other classes (returned by the server) are NEVER shown. "My entries" = [BehaviourRecord.isMine]
/// (`reportedById` when present, else the `reportedBy` name): there is no server-side "mine" filter.
class BehaviourController extends GetxController {
  final BehaviourRepository? _repo;
  final StudentsRepository? _students;
  final AuthController? _auth;
  final PermissionService? _perms;

  BehaviourController({BehaviourRepository? repository, StudentsRepository? students, AuthController? auth, PermissionService? permissions})
      : _repo = repository,
        _students = students,
        _auth = auth,
        _perms = permissions;

  BehaviourRepository get repo => _repo ?? Get.find<BehaviourRepository>();
  StudentsRepository get students => _students ?? Get.find<StudentsRepository>();
  AuthController get auth => _auth ?? Get.find<AuthController>();
  PermissionService get perms => _perms ?? Get.find<PermissionService>();

  final state = Rx<SectionState<List<BehaviourRecord>>>(const SectionState.loading());
  final scope = BehaviourScope.mine.obs;

  /// -1 = all my classes, else an index into [classes].
  final classFilter = (-1).obs;
  final query = ''.obs;
  int _token = 0;

  bool get canView {
    auth.staffMe.value;
    return perms.canAccess('behaviour:view');
  }

  /// Logging also needs `behaviour:manage` (the teacher role has it; the backend allows teachers: STAFF_WRITE_ROLES).
  bool get canLog {
    auth.staffMe.value;
    return perms.canAccess('behaviour:manage');
  }

  List<ClassRef> get classes {
    auth.staffMe.value;
    return teacherClassesOf(auth.staffMe.value?.teacherProfile);
  }

  String get myId => auth.user.value?.id ?? '';
  String get myName => auth.user.value?.name ?? '';

  List<BehaviourRecord> get all => state.value.data ?? const [];

  List<BehaviourRecord> get visible {
    final cs = classes;
    final q = query.value.trim().toLowerCase();
    return [
      for (final r in all)
        if ((scope.value == BehaviourScope.classes || r.isMine(userId: myId, userName: myName)) &&
            (classFilter.value < 0 || classFilter.value >= cs.length || cs[classFilter.value].containsRecord(r)) &&
            (q.isEmpty || r.studentName.toLowerCase().contains(q) || r.title.toLowerCase().contains(q)))
          r
    ];
  }

  int countMine() => all.where((r) => r.isMine(userId: myId, userName: myName)).length;

  @override
  void onReady() {
    super.onReady();
    load();
  }

  void setScope(BehaviourScope s) => scope.value = s;
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
      GradesSections? known;
      try {
        known = await students.fetchGradesSections();
      } catch (_) {
        known = null; // optional: the class's own strings are used
      }
      final grades = <String>{for (final c in cs) ...queryVariants(c, known).grades};
      final seen = <String>{};
      final out = <BehaviourRecord>[];
      for (final g in grades) {
        for (final r in await repo.fetchGradeRecords(g)) {
          if (r.id.isNotEmpty && cs.any((c) => c.containsRecord(r)) && seen.add(r.id)) out.add(r);
        }
      }
      if (token != _token) return;
      out.sort((a, b) => (b.day ?? DateTime(0)).compareTo(a.day ?? DateTime(0)));
      state.value = out.isEmpty ? const SectionState.empty() : SectionState.data(out);
    } catch (e) {
      if (token != _token) return;
      state.value = SectionState<List<BehaviourRecord>>.fromError(e);
    }
  }

  Future<void> reload() async {
    await auth.refreshProfile(force: true);
    await load(force: true);
  }

  /// A record the user just logged (so the list shows it without a re-fetch).
  void addRecord(BehaviourRecord r) {
    final list = [r, ...all.where((x) => x.id != r.id)];
    list.sort((a, b) => (b.day ?? DateTime(0)).compareTo(a.day ?? DateTime(0)));
    state.value = SectionState.data(list);
  }
}
