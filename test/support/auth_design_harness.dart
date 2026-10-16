import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/core/network/base_client.dart';
import 'package:eldermin_teacher_app/core/services/auth_api_service.dart';
import 'package:eldermin_teacher_app/core/services/permission_service.dart';
import 'package:eldermin_teacher_app/core/services/token_store.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemTokens implements TokenStore {
  String? token;
  @override
  Future<String?> readToken() async => token;
  @override
  Future<void> saveToken(String t) async => token = t;
  @override
  Future<void> clearAll() async => token = null;
}

/// Registers the controllers the signed-out screens need (no network is ever called).
AuthController setUpAuthDeps() {
  SharedPreferences.setMockInitialValues({});
  Get.reset();
  Get.testMode = true;
  final api = AuthApiService(BaseClient());
  final auth = AuthController(
    api: api,
    permissions: PermissionService(),
    tokenStore: MemTokens(),
    minSplash: Duration.zero,
    resetScopedControllers: () async {},
    notify: (_) {},
  )..status.value = AuthStatus.unauthenticated;
  Get.put<AuthApiService>(api);
  Get.put<AuthController>(auth);
  return auth;
}

/// Pumps [screen] full-screen at [width] x [height], with text scale, direction
/// and a simulated on-screen keyboard of [keyboard] logical pixels.
Future<void> pumpScreen(
  WidgetTester t,
  Widget screen, {
  double width = 390,
  double height = 844,
  double textScale = 1,
  TextDirection dir = TextDirection.ltr,
  double keyboard = 0,
  double topInset = 47,
  double bottomInset = 34,
}) async {
  t.view.physicalSize = Size(width, height);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(GetMaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    builder: (context, c) => Directionality(
      textDirection: dir,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          viewInsets: EdgeInsets.only(bottom: keyboard),
          padding: EdgeInsets.only(top: topInset, bottom: keyboard > 0 ? 0 : bottomInset),
        ),
        child: c!,
      ),
    ),
    home: screen,
  ));
  await t.pump(const Duration(milliseconds: 1200));
}
