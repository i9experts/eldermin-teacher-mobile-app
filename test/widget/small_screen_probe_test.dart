// D1a/D1b small-screen probe: records (does NOT assert) layout exceptions for the
// shell tabs at phone widths and text scales. Findings are printed as
// `PROBE <size> x<scale> <tab>: <first line of the exception>`.
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show FontLoader;
import 'package:eldermin_teacher_app/app/modules/attendance/controllers/attendance_controller.dart';
import 'package:eldermin_teacher_app/app/modules/auth/views/login_screen.dart';
import 'package:eldermin_teacher_app/app/modules/forgot_password/views/forgot_password_screen.dart';
import 'package:eldermin_teacher_app/app/modules/home/controllers/home_badges_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/controllers/home_dashboard_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/views/home_shell.dart';
import 'package:eldermin_teacher_app/app/modules/timetable/controllers/timetable_controller.dart';
import 'package:eldermin_teacher_app/core/services/home_repository.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/auth_harness.dart';
import '../support/fake_classroom_repositories.dart';
import '../support/fake_home_repository.dart';

// ignore_for_file: avoid_print

Future<void> _loadFont() async {
  final loader = FontLoader('PlusJakartaSans');
  for (final f in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final b = File('assets/fonts/PlusJakartaSans-$f.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(Uint8List.fromList(b).buffer)));
  }
  await loader.load();
}

void main() {
  setUpAll(_loadFont);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.testMode = true;
  });
  tearDown(Get.reset);

  final sizes = {'SE 375x667': const Size(375, 667), 'Android 360x640': const Size(360, 640), 'Android 360x800': const Size(360, 800)};
  for (final classTeacher in [false, true]) {
    for (final e in sizes.entries) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('probe ${classTeacher ? 'class' : 'plain'} ${e.key} x$scale', (t) async {
          t.view.physicalSize = e.value * 3;
          t.view.devicePixelRatio = 3;
          t.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(t.view.reset);
          final captured = <FlutterErrorDetails>[];
          final prev = FlutterError.onError;
          FlutterError.onError = captured.add;
          addTearDown(() => FlutterError.onError = prev);
          addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
          final h = (await t.runAsync(() => signedIn(classTeacher: classTeacher)))!;
          final repo = FakeHomeRepository();
          Get.put<HomeRepository>(repo);
          final badges = Get.put(HomeBadgesController(repository: repo, auth: h.auth, autoPoll: false));
          Get.put(HomeDashboardController(repository: repo, auth: h.auth, permissions: h.perms, badges: badges, tick: null));
          Get.put(TimetableController(repository: repo, tick: null));
          Get.put(AttendanceController(students: FakeStudentsRepository(), attendance: FakeAttendanceRepository()));
          await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: const HomeShell()));
          final tabs = ['Home', 'Classes', classTeacher ? 'Attendance' : 'Timetable', 'Messages', 'More'];
          for (final tab in tabs) {
            await t.tap(find.descendant(of: find.byType(BottomNavigationBar), matching: find.text(tab)));
            await t.pump(const Duration(milliseconds: 400));
            for (final d in captured) {
              final txt = d.toString();
              final first = txt.split('\n').firstWhere((l) => l.contains('overflowed'), orElse: () => txt.split('\n').first);
              final where = RegExp(r'The relevant error-causing widget was:\s*\n\s*([^\n]+)\n\s*([^\n]+)').firstMatch(txt);
              print('PROBE ${classTeacher ? 'class' : 'plain'} ${e.key} x$scale $tab: ${first.trim()} @ ${where?.group(1)} ${where?.group(2)}');
            }
            captured.clear();
          }
        });
      }
    }
  }

  for (final scale in [1.0, 1.3]) {
    testWidgets('probe auth screens 360x640 x$scale', (t) async {
      t.view.physicalSize = const Size(360, 640) * 3;
      t.view.devicePixelRatio = 3;
      t.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(t.view.reset);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await t.runAsync(() => signedIn());
      for (final entry in {'Login': const LoginScreen(), 'Forgot': const ForgotPasswordScreen()}.entries) {
        await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: entry.value));
        await t.pump(const Duration(milliseconds: 300));
        Object? ex;
        while ((ex = t.takeException()) != null) {
          print('PROBE auth 360x640 x$scale ${entry.key}: ${ex.toString().split('\n').first}');
        }
      }
    });
  }
}
