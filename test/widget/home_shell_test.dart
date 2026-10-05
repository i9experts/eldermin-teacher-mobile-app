import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/views/home_shell.dart';
import 'package:eldermin_teacher_app/core/models/auth_me.dart';
import 'package:eldermin_teacher_app/core/models/staff_me.dart';
import 'package:eldermin_teacher_app/core/network/base_client.dart';
import 'package:eldermin_teacher_app/core/services/auth_api_service.dart';
import 'package:eldermin_teacher_app/core/services/permission_service.dart';
import 'package:eldermin_teacher_app/core/services/token_store.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Tokens implements TokenStore {
  @override
  Future<String?> readToken() async => 'tok';
  @override
  Future<void> saveToken(String t) async {}
  @override
  Future<void> clearAll() async {}
}

class _Api extends AuthApiService {
  _Api() : super(BaseClient());
  bool classTeacher = false;
  int meCalls = 0;

  @override
  Future<AuthMe> fetchAuthMe({String? token}) async =>
      const AuthMe(id: 'u', name: 'Tess Teacher', email: 't@s.test', role: 'teacher');

  @override
  Future<StaffMe> fetchStaffMe() async {
    meCalls++;
    return StaffMe.fromJson({
      'user': {'id': 'u', 'name': 'Tess Teacher', 'email': 't@s.test', 'role': 'teacher'},
      'staffId': 's1',
      'teacherProfile': {'isClassTeacher': classTeacher},
      'institution': {'slug': 's'},
    });
  }

  @override
  Future<void> logout() async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.testMode = true;
  });
  tearDown(Get.reset);

  testWidgets('class-teacher change swaps Timetable <-> Attendance tab live, no re-login; Home pull refreshes',
      (tester) async {
    final api = _Api();
    final auth = AuthController(
      api: api,
      permissions: PermissionService(),
      tokenStore: _Tokens(),
      minSplash: Duration.zero,
      resetScopedControllers: () async {},
      notify: (_) {},
    );
    Get.put<AuthApiService>(api);
    Get.put<PermissionService>(PermissionService());
    Get.put<AuthController>(auth);
    await tester.runAsync(auth.bootstrap);
    expect(auth.status.value, AuthStatus.authenticated);

    await tester.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: const HomeShell()));
    await tester.pump();
    expect(find.text('Timetable'), findsWidgets);
    expect(find.text('Attendance'), findsNothing);

    // Pull-to-refresh on the Home placeholder re-fetches /staff-portal/me.
    api.classTeacher = true;
    final before = api.meCalls;
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, 400));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 600));
    expect(api.meCalls, greaterThan(before), reason: 'pull on Home must call /staff-portal/me');

    expect(find.text('Attendance'), findsWidgets);
    expect(find.text('Timetable'), findsNothing);
    expect(auth.status.value, AuthStatus.authenticated);

    // ...and back.
    api.classTeacher = false;
    await tester.runAsync(() => auth.refreshProfile(force: true));
    await tester.pump();
    expect(find.text('Timetable'), findsWidgets);
    expect(find.text('Attendance'), findsNothing);
  });
}
