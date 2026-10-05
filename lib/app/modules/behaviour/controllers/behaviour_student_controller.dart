import 'package:get/get.dart';
import '../../../../core/models/behaviour/behaviour_models.dart';
import '../../../../core/models/classroom/student_models.dart';
import '../../../../core/services/behaviour_repository.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/services/students_repository.dart';
import '../../../../core/utils/roster_scope.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/models/section_state.dart';

/// One student's behaviour + Tarbiyah history (`/behaviour/student/:id`), read-only.
///
/// The server does not check that a student is in the teacher's class (`GET /behaviour/records?studentId=` is campus-scoped only), so the
/// app first resolves the student among MY classes' rosters and, if absent, shows "not in one of your classes" WITHOUT requesting any
/// record. Records and Tarbiyah load independently (one failing does not hide the other).
class BehaviourStudentController extends GetxController {
  final String studentId;
  final StudentSummary? initial;
  final BehaviourRepository? _repo;
  final StudentsRepository? _students;
  final AuthController? _auth;
  final PermissionService? _perms;

  BehaviourStudentController({
    required this.studentId,
    this.initial,
    BehaviourRepository? repository,
    StudentsRepository? students,
    AuthController? auth,
    PermissionService? permissions,
  })  : _repo = repository,
        _students = students,
        _auth = auth,
        _perms = permissions;

  BehaviourRepository get repo => _repo ?? Get.find<BehaviourRepository>();
  StudentsRepository get students => _students ?? Get.find<StudentsRepository>();
  AuthController get auth => _auth ?? Get.find<AuthController>();
  PermissionService get perms => _perms ?? Get.find<PermissionService>();

  final student = Rx<SectionState<StudentSummary>>(const SectionState.loading());
  final records = Rx<SectionState<List<BehaviourRecord>>>(const SectionState.loading());
  final tarbiyah = Rx<SectionState<List<TarbiyahAssessment>>>(const SectionState.loading());
  int _token = 0;

  bool get canView {
    auth.staffMe.value;
    return perms.canAccess('behaviour:view');
  }

  bool get canLog {
    auth.staffMe.value;
    return perms.canAccess('behaviour:manage');
  }

  List<ClassRef> get classes => teacherClassesOf(auth.staffMe.value?.teacherProfile);

  String get myId => auth.user.value?.id ?? '';
  String get myName => auth.user.value?.name ?? '';

  /// Behaviour points of the loaded records (+ merit / - demerit).
  int get totalPoints => (records.value.data ?? const <BehaviourRecord>[]).fold(0, (a, r) => a + r.points);

  @override
  void onReady() {
    super.onReady();
    load();
  }

  Future<void> load() async {
    if (!canView) {
      student.value = const SectionState.forbidden();
      return;
    }
    final token = ++_token;
    student.value = const SectionState.loading();
    records.value = const SectionState.loading();
    tarbiyah.value = const SectionState.loading();
    try {
      final s = await _resolveStudent();
      if (token != _token) return;
      if (s == null) {
        student.value = const SectionState.empty(); // "not in one of your classes"
        return;
      }
      student.value = SectionState.data(s);
    } catch (e) {
      if (token != _token) return;
      student.value = SectionState<StudentSummary>.fromError(e);
      return;
    }
    await Future.wait([_loadRecords(token), _loadTarbiyah(token)]);
  }

  Future<StudentSummary?> _resolveStudent() async {
    final cs = classes;
    final i = initial;
    if (i != null && i.id == studentId) return inAnyClass(i, cs) ? i : null;
    GradesSections? known;
    var triedKnown = false;
    for (final c in cs) {
      if (!triedKnown) {
        triedKnown = true;
        try {
          known = await students.fetchGradesSections();
        } catch (_) {}
      }
      final roster = await students.fetchClassRoster(c, known: known);
      for (final s in roster) {
        if (s.id == studentId) return s;
      }
    }
    return null;
  }

  Future<void> _loadRecords(int token) async {
    try {
      final list = await repo.fetchStudentRecords(studentId);
      if (token != _token) return;
      records.value = list.isEmpty ? const SectionState.empty() : SectionState.data(list);
    } catch (e) {
      if (token != _token) return;
      records.value = SectionState<List<BehaviourRecord>>.fromError(e);
    }
  }

  Future<void> _loadTarbiyah(int token) async {
    try {
      final list = await repo.fetchTarbiyah(studentId);
      if (token != _token) return;
      tarbiyah.value = list.isEmpty ? const SectionState.empty() : SectionState.data(list);
    } catch (e) {
      if (token != _token) return;
      tarbiyah.value = SectionState<List<TarbiyahAssessment>>.fromError(e);
    }
  }

  Future<void> reload() => load();

  /// Adds a record logged from this screen.
  void addRecord(BehaviourRecord r) {
    final list = [r, ...(records.value.data ?? const <BehaviourRecord>[]).where((x) => x.id != r.id)];
    records.value = SectionState.data(list);
  }
}
