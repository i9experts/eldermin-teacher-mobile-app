import 'package:get/get.dart';
import '../../core/services/permission_service.dart';
import '../modules/auth/controllers/auth_controller.dart';

/// May the signed-in user create / edit / approve in [module] (optionally one [sub]-module)? The one rule behind every write button:
/// [PermissionService.canManage], i.e. the same permission source as module visibility. Read it inside an `Obx` and it follows a profile
/// refresh. Without a registered [PermissionService] (isolated widget tests) it allows: the route guard ([ModuleCatalog.writeAllowed])
/// is closed in that case and is what protects the real app.
bool canWrite(String module, {String? sub}) {
  if (!Get.isRegistered<PermissionService>()) return true;
  if (Get.isRegistered<AuthController>()) Get.find<AuthController>().staffMe.value; // subscribe to profile refreshes
  return Get.find<PermissionService>().canManage(module, subModuleKey: sub);
}

bool get canWriteHomework => canWrite('teaching', sub: 'homework');
bool get canWriteLessonPlans => canWrite('teaching', sub: 'lesson-plans');
bool get canWritePtm => canWrite('teaching', sub: 'ptm');
bool get canWriteSyllabus => canWrite('teaching', sub: 'syllabus');
bool get canWriteAttendance => canWrite('teaching', sub: 'attendance');
bool get canWriteAssessments => canWrite('assessments');
bool get canWriteBehaviour => canWrite('behaviour');
bool get canApproveStudentLeaves => canWrite('teaching');
