import 'package:get/get.dart';
import '../../../../core/models/classroom/attendance_models.dart';
import '../../../../core/models/classroom/student_360.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/services/students_repository.dart';
import '../../../../core/utils/home_time.dart';
import '../../../../core/utils/roster_scope.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/models/section_state.dart';

/// Read-only Student 360 for ONE student (route `/students/:id`).
///
/// `GET /students/:id/360` has no class/campus check (backlog item 6), so after the payload arrives the
/// app verifies the student belongs to one of MY classes; if not, nothing is shown ([outOfScope]) and
/// the parsed data is dropped and no further request is made for that student. The payload is read through the [Student360] whitelist (no fees, no
/// guardian contact data). Sections load independently: the "this month" attendance counts come from
/// `GET /students/:id/attendance/summary?month=` and may fail without hiding the rest.
class StudentDetailController extends GetxController {
  final String studentId;
  final StudentsRepository? _repo;
  final AuthController? _auth;
  final PermissionService? _perms;
  final Clock clock;

  StudentDetailController(this.studentId,
      {StudentsRepository? repository, AuthController? auth, PermissionService? permissions, Clock? clock})
      : _repo = repository,
        _auth = auth,
        _perms = permissions,
        clock = clock ?? DateTime.now;

  StudentsRepository get repo => _repo ?? Get.find<StudentsRepository>();
  AuthController get auth => _auth ?? Get.find<AuthController>();
  PermissionService get perms => _perms ?? Get.find<PermissionService>();

  final detail = Rx<SectionState<Student360>>(const SectionState.loading());
  final month = Rx<SectionState<StatusCounts>>(const SectionState.loading());

  /// True when the student is not in any of my classes (nothing from the payload is kept).
  final outOfScope = false.obs;

  int _token = 0;

  DateTime get monthStart => DateTime(clock().year, clock().month, 1);

  @override
  void onReady() {
    super.onReady();
    load();
  }

  Future<void> load() async {
    if (studentId.isEmpty) {
      detail.value = const SectionState.error('No student was selected.');
      return;
    }
    if (!perms.canAccess('students:view')) {
      detail.value = const SectionState.forbidden();
      return;
    }
    final token = ++_token;
    detail.value = const SectionState.loading();
    month.value = const SectionState.loading();
    outOfScope.value = false;
    try {
      final d = await repo.fetchStudent360(studentId);
      if (token != _token) return;
      if (!inAnyClass(d.student, teacherClassesOf(auth.staffMe.value?.teacherProfile))) {
        outOfScope.value = true;
        detail.value = const SectionState.empty();
        month.value = const SectionState.empty();
        return;
      }
      detail.value = SectionState.data(d);
    } catch (e) {
      if (token != _token) return;
      // 404 here is the backend's 'Student not found' (students.service.ts:1484-1485), not "endpoint missing".
      detail.value = (e is ApiException && e.statusCode == 404) ? const SectionState.empty() : SectionState<Student360>.fromError(e);
      month.value = const SectionState.empty();
      return;
    }
    // Only now (the student is verified to be mine) is anything else requested for them.
    await _loadMonth(token);
  }

  Future<void> _loadMonth(int token) async {
    try {
      final c = await repo.fetchAttendanceSummary(studentId, year: monthStart.year, month: monthStart.month);
      if (token != _token) return;
      month.value = SectionState.data(c);
    } catch (e) {
      if (token != _token) return;
      month.value = SectionState<StatusCounts>.fromError(e);
    }
  }

  Future<void> reload() async {
    await auth.refreshProfile(force: true);
    await load();
  }
}
