import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../../core/models/classroom/student_models.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/services/students_repository.dart';
import '../../../../core/utils/roster_scope.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/models/section_state.dart';

/// "My students": the roster of each class THIS teacher is responsible for (class-teacher class +
/// `currentAssignments` from `/staff-portal/me`), one class at a time. The server only scopes
/// `GET /students` by campus, so the app asks per class (with the raw grade/section strings that
/// normalise to it) and re-filters client-side with the backend's matcher. Search is client-side
/// (name, roll number, GR no): the server `search` param matches name / ids / guardian phone & email
/// but NOT the roll number, and sending a parent's phone around is not needed.
class StudentsController extends GetxController {
  final StudentsRepository? _repo;
  final AuthController? _auth;
  final PermissionService? _perms;

  StudentsController({StudentsRepository? repository, AuthController? auth, PermissionService? permissions})
      : _repo = repository,
        _auth = auth,
        _perms = permissions;

  StudentsRepository get repo => _repo ?? Get.find<StudentsRepository>();
  AuthController get auth => _auth ?? Get.find<AuthController>();
  PermissionService get perms => _perms ?? Get.find<PermissionService>();

  /// Index into [classes] of the class on screen.
  final selected = 0.obs;
  final query = ''.obs;
  final searchController = TextEditingController();

  /// Roster state per class key ([ClassRef.key]).
  final rosters = <String, SectionState<List<StudentSummary>>>{}.obs;

  GradesSections? _known;
  bool _knownTried = false;
  final _tokens = <String, int>{};

  bool get canView {
    auth.staffMe.value;
    return perms.canAccess('students:view');
  }

  List<ClassRef> get classes {
    auth.staffMe.value; // Obx dependency
    return teacherClassesOf(auth.staffMe.value?.teacherProfile);
  }

  ClassRef? get current {
    final list = classes;
    if (list.isEmpty) return null;
    return list[selected.value.clamp(0, list.length - 1)];
  }

  SectionState<List<StudentSummary>> get state {
    final c = current;
    if (!canView) return const SectionState.forbidden();
    if (c == null) return const SectionState.empty();
    return rosters[c.key] ?? const SectionState.loading();
  }

  /// Roster of the current class filtered by the search text.
  List<StudentSummary> get visible {
    final all = state.data ?? const <StudentSummary>[];
    final q = query.value.trim().toLowerCase();
    if (q.isEmpty) return all;
    return [
      for (final s in all)
        if (s.fullName.toLowerCase().contains(q) ||
            (s.preferredName ?? '').toLowerCase().contains(q) ||
            (s.rollNumber ?? '') == q ||
            (s.grNo ?? '').toLowerCase().contains(q))
          s
    ];
  }

  @override
  void onReady() {
    super.onReady();
    load();
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  void selectClass(int i) {
    if (i == selected.value) return;
    selected.value = i;
    query.value = '';
    searchController.clear();
    load();
  }

  /// Loads the current class (cached after the first success unless [force]).
  Future<void> load({bool force = false}) async {
    final c = current;
    if (c == null || !canView) return;
    final existing = rosters[c.key];
    if (!force && existing != null && (existing.hasData || existing.status == SectionStatus.empty)) return;
    final token = (_tokens[c.key] ?? 0) + 1;
    _tokens[c.key] = token;
    if (existing == null || !existing.hasData) rosters[c.key] = const SectionState.loading();
    try {
      if (!_knownTried) {
        _knownTried = true;
        try {
          _known = await repo.fetchGradesSections();
        } catch (_) {
          _known = null; // optional: the class's own strings are used
        }
      }
      final list = await repo.fetchClassRoster(c, known: _known);
      if (_tokens[c.key] != token) return;
      rosters[c.key] = list.isEmpty ? const SectionState.empty() : SectionState.data(list);
    } catch (e) {
      if (_tokens[c.key] != token) return;
      rosters[c.key] = SectionState<List<StudentSummary>>.fromError(e);
    }
  }

  Future<void> reload() async {
    await auth.refreshProfile(force: true);
    await load(force: true);
  }
}
