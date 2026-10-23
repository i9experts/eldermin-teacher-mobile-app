import 'package:get/get.dart';
import '../../../../core/models/early_years/ece_models.dart';
import '../../../../core/services/early_years_repository.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/utils/early_years_scope.dart';
import '../../../../core/utils/roster_scope.dart';
import '../../../common/action_failure.dart';
import '../../auth/controllers/auth_controller.dart';
import 'early_years_child_controller.dart';
import 'early_years_controller.dart';

/// What the three Early Years create forms share: the child (one of MY classes' children, passed in from the child page or found in the list),
/// the `early-years:manage` check, the saving flag and the last failure. Nothing is created for a child outside my classes.
abstract class EyFormBase extends GetxController {
  final String childId;
  final EceChild? initial;
  final EarlyYearsRepository? _repo;
  final AuthController? _auth;
  final PermissionService? _perms;

  EyFormBase({required this.childId, this.initial, EarlyYearsRepository? repository, AuthController? auth, PermissionService? permissions})
      : _repo = repository,
        _auth = auth,
        _perms = permissions;

  EarlyYearsRepository get repo => _repo ?? Get.find<EarlyYearsRepository>();
  AuthController get auth => _auth ?? Get.find<AuthController>();
  PermissionService get perms => _perms ?? Get.find<PermissionService>();

  final saving = false.obs;
  final failure = Rxn<ActionFailure>();
  final errors = <String, String>{}.obs;

  bool get canManage {
    auth.staffMe.value;
    return perms.canAccess('early-years:manage');
  }

  List<ClassRef> get classes {
    auth.staffMe.value;
    return teacherClassesOf(auth.staffMe.value?.teacherProfile);
  }

  /// The child, only when it is one of my classes' children.
  EceChild? get child {
    var k = initial;
    if (k == null && Get.isRegistered<EarlyYearsChildController>()) k = Get.find<EarlyYearsChildController>().child;
    if (k == null && Get.isRegistered<EarlyYearsController>()) k = Get.find<EarlyYearsController>().childById(childId);
    if (k == null || k.id != childId) return null;
    return childInAnyClass(classes, k) ? k : null;
  }

  /// Why the form cannot be used, or null.
  String? get blocked {
    if (!canManage) return "Your account isn't allowed to add Early Years records.";
    if (child == null) return "This child isn't one of the children in your classes. Open the child from the Early Years list.";
    return null;
  }

  /// A child's page that is open behind this form, so the new record shows without a refetch.
  EarlyYearsChildController? get childPage => Get.isRegistered<EarlyYearsChildController>() ? Get.find<EarlyYearsChildController>() : null;
}
