import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/core/models/auth_me.dart';
import 'package:eldermin_teacher_app/core/models/staff_me.dart';
import 'package:eldermin_teacher_app/core/network/base_client.dart';
import 'package:eldermin_teacher_app/core/services/auth_api_service.dart';
import 'package:eldermin_teacher_app/core/services/permission_service.dart';
import 'package:eldermin_teacher_app/core/services/token_store.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemTokens implements TokenStore {
  @override
  Future<String?> readToken() async => 'tok';
  @override
  Future<void> saveToken(String t) async {}
  @override
  Future<void> clearAll() async {}
}

class HarnessApi extends AuthApiService {
  HarnessApi() : super(BaseClient());
  bool classTeacher = false;
  String role = 'teacher';
  List<String>? permissions;

  @override
  Future<AuthMe> fetchAuthMe({String? token}) async =>
      AuthMe(id: 'u', name: 'Tess Teacher', email: 't@s.test', role: role);

  @override
  Future<StaffMe> fetchStaffMe() async => StaffMe.fromJson({
        'user': {
          'id': 'u',
          'name': 'Tess Teacher',
          'email': 't@s.test',
          'role': role,
          'avatarUrl': null,
          if (permissions != null) 'permissions': permissions,
        },
        'staffId': '64a0000000000000000000a1',
        'teacherProfileId': '64a0000000000000000000b1',
        'department': 'Science',
        'campus': {'id': 'c1', 'name': 'Main Campus'},
        'teacherProfile': {
          'isClassTeacher': classTeacher,
          'classTeacherOf': classTeacher
              ? {'gradeId': 'g5', 'gradeName': 'Grade 5', 'sectionName': 'A', 'label': 'Grade 5 - A'}
              : null,
        },
        'institution': {'slug': 's'},
      });

  @override
  Future<void> logout() async {}
}

/// Registers a bootstrapped, authenticated [AuthController] (plus its api and
/// permission service) in GetX and returns it.
Future<({AuthController auth, HarnessApi api, PermissionService perms})> signedIn({
  bool classTeacher = false,
  List<String>? permissions,
}) async {
  SharedPreferences.setMockInitialValues({});
  final api = HarnessApi()
    ..classTeacher = classTeacher
    ..permissions = permissions;
  final perms = PermissionService();
  final auth = AuthController(
    api: api,
    permissions: perms,
    tokenStore: MemTokens(),
    minSplash: Duration.zero,
    resetScopedControllers: () async {},
    notify: (_) {},
  );
  Get.put<AuthApiService>(api);
  Get.put<PermissionService>(perms);
  Get.put<AuthController>(auth);
  await auth.bootstrap();
  return (auth: auth, api: api, perms: perms);
}
