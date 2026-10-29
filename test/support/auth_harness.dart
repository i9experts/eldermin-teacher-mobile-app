import 'dart:convert';

import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/core/models/auth_me.dart';
import 'package:eldermin_teacher_app/core/models/staff_me.dart';
import 'package:eldermin_teacher_app/core/network/base_client.dart';
import 'package:eldermin_teacher_app/core/services/auth_api_service.dart';
import 'package:eldermin_teacher_app/core/services/permission_service.dart';
import 'package:eldermin_teacher_app/core/services/token_store.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An UNSIGNED fake JWT (header.payload.signature) whose payload is [claims]; the app only reads the payload.
String fakeJwt(Map<String, Object?> claims) {
  String seg(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${seg({'alg': 'none', 'typ': 'JWT'})}.${seg(claims)}.sig';
}

/// A token as the backend issues it to a class teacher: `classTeacherAssignments[]` plus the legacy singular claims of the first.
String classTeacherJwt(List<({String grade, String section})> classes) => fakeJwt({
      'sub': 'u',
      if (classes.isNotEmpty) ...{
        'classTeacherAssignments': [for (final c in classes) {'gradeName': c.grade, 'sectionName': c.section}],
        'classTeacherOfGradeName': classes.first.grade,
        'classTeacherOfSectionName': classes.first.section,
      },
    });

class MemTokens implements TokenStore {
  MemTokens([this.token = 'tok']);
  final String token;
  @override
  Future<String?> readToken() async => token;
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
  List<String> activeModules = const [];
  List<Map<String, Object?>> assignments = const [];

  /// `teacherProfile.classTeacherAssignments` (every section). Null = the single legacy ['Grade 5','A'] class when [classTeacher].
  List<Map<String, Object?>>? classTeacherAssignments;
  List<String> subjects = const [];

  /// When set, `/staff-portal/me` waits for it (a hung server); pass `Completer().future` for "never answers".
  Future<void>? staffMeGate;

  @override
  Future<AuthMe> fetchAuthMe({String? token}) async =>
      AuthMe(id: 'u', name: 'Tess Teacher', email: 't@s.test', role: role);

  @override
  Future<StaffMe> fetchStaffMe() async {
    final gate = staffMeGate;
    if (gate != null) await gate;
    return _staffMe();
  }

  static const Map<String, Object?> _g5a = {'gradeId': 'g5', 'gradeName': 'Grade 5', 'sectionName': 'A', 'label': 'Grade 5 - A'};

  StaffMe _staffMe() => StaffMe.fromJson({
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
          'subjectsCanTeach': subjects,
          'currentAssignments': assignments,
          'classTeacherOf': classTeacher ? (classTeacherAssignments?.firstOrNull ?? _g5a) : null,
          if (classTeacher && classTeacherAssignments != null) 'classTeacherAssignments': classTeacherAssignments,
        },
        'institution': {'slug': 's', 'activeModules': activeModules},
      });

  @override
  Future<void> logout() async {}
}

/// Registers a bootstrapped, authenticated [AuthController] (plus its api and
/// permission service) in GetX and returns it.
Future<({AuthController auth, HarnessApi api, PermissionService perms})> signedIn({
  bool classTeacher = false,
  List<String>? permissions,
  String role = 'teacher',
  List<String> activeModules = const [],
  List<Map<String, Object?>>? classTeacherAssignments,
  String token = 'tok',
}) async {
  SharedPreferences.setMockInitialValues({});
  final api = HarnessApi()
    ..classTeacher = classTeacher
    ..classTeacherAssignments = classTeacherAssignments
    ..permissions = permissions
    ..role = role
    ..activeModules = activeModules;
  final perms = PermissionService();
  final auth = AuthController(
    api: api,
    permissions: perms,
    tokenStore: MemTokens(token),
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
