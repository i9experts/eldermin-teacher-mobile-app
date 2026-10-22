// Dev tool (NOT shipped: lives under tool/). Runs the real app (AuthGate, splash,
// login, home) with a stubbed session so the M1 splash can be recorded:
//
//   flutter run -t tool/m1/m1_stub_main.dart --dart-define=M1_SCENARIO=loggedout|loggedin|slow
//
//   loggedout  no token            -> splash -> login
//   loggedin   stub token + profile -> splash -> home (home's own data calls still hit the network and show their error/empty states)
//   slow       no token, the session check takes 7 s (debug builds spend ~2.5 s before the first frame, so 7 s leaves >3 s of visible splash) -> splash (+ "Connecting…" at 3 s) -> login
//   (word `intro`; word `reduce` forces reduce-motion)     leave the first-launch intro unseen (-> intro instead of login)
import 'dart:async';
import 'dart:convert';
import 'dart:developer' show Timeline;
import 'dart:io';
import 'dart:ui' show FramePhase;

import 'package:eldermin_teacher_app/app/common/services/deep_link_service.dart';
import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/app/routes/app_pages.dart';
import 'package:eldermin_teacher_app/core/design/design.dart';
import 'package:eldermin_teacher_app/core/models/auth_me.dart';
import 'package:eldermin_teacher_app/core/models/staff_me.dart';
import 'package:eldermin_teacher_app/core/network/base_client.dart';
import 'package:eldermin_teacher_app/core/services/app_preferences.dart';
import 'package:eldermin_teacher_app/core/services/auth_api_service.dart';
import 'package:eldermin_teacher_app/core/services/permission_service.dart';
import 'package:eldermin_teacher_app/core/services/token_store.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
// ignore: invalid_use_of_visible_for_testing_member
import 'package:eldermin_teacher_app/main.dart' show AuthGate;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Chosen at launch, so one build serves every recording: entrypoint args
// (Android: `am start --esa dart-entrypoint-args slow`), else the file below
// (iOS simulator), else the --dart-define.
String _scenario = const String.fromEnvironment('M1_SCENARIO', defaultValue: 'loggedout');
bool _intro = const bool.fromEnvironment('M1_INTRO');
bool _reduce = false;

class _Tokens implements TokenStore {
  @override
  Future<String?> readToken() async {
    if (_scenario == 'slow') await Future<void>.delayed(const Duration(seconds: 7));
    return _scenario == 'loggedin' ? 'stub-token' : null;
  }

  @override
  Future<void> saveToken(String token) async {}
  @override
  Future<void> clearAll() async {}
}

class _Api extends AuthApiService {
  _Api() : super(BaseClient());

  @override
  Future<AuthMe> fetchAuthMe({String? token}) async => const AuthMe(id: 'u', name: 'Tess Teacher', email: 't@s.test', role: 'teacher');

  @override
  Future<StaffMe> fetchStaffMe() async => StaffMe.fromJson({
        'user': {'id': 'u', 'name': 'Tess Teacher', 'email': 't@s.test', 'role': 'teacher'},
        'staffId': 's1',
        'teacherProfile': {'isClassTeacher': true},
        'institution': {'slug': 's'},
      });

  @override
  Future<void> logout() async {}
}

class _Binding extends Bindings {
  @override
  void dependencies() {
    final api = Get.put<AuthApiService>(_Api(), permanent: true);
    final permissions = Get.put<PermissionService>(PermissionService(), permanent: true);
    final auth = Get.put<AuthController>(AuthController(api: api, permissions: permissions, tokenStore: _Tokens()), permanent: true);
    ever(auth.status, (_) => _events['status_ready'] ??= Timeline.now);
    Get.put<DeepLinkService>(DeepLinkService(auth: auth), permanent: true);
  }
}

/// Frame build/raster times from launch, plus the moments the hand-off started and ended
/// (Timeline.now = the same monotonic clock as FrameTiming). Printed as one `M1PERF {json}`
/// line (adb logcat / simctl log) and written to <tmp>/m1_perf.json after [_perfWindow].
const _perfWindow = Duration(seconds: 14);
final _frames = <List<num>>[]; // [vsyncStartMicros, buildMs, rasterMs, totalMs]
final _events = <String, int>{};

void _startPerfLog() {
  SchedulerBinding.instance.addTimingsCallback((timings) {
    for (final t in timings) {
      _frames.add([
        t.timestampInMicroseconds(FramePhase.vsyncStart),
        t.buildDuration.inMicroseconds / 1000,
        t.rasterDuration.inMicroseconds / 1000,
        t.totalSpan.inMicroseconds / 1000,
      ]);
    }
  });
  EmLogoHandoff.flying.addListener(() => _events[EmLogoHandoff.flying.value ? 'flight_start' : 'flight_end'] = Timeline.now);
  Timer(_perfWindow, () {
    final json = jsonEncode({'scenario': _scenario, 'reduce': _reduce, 'events': _events, 'frames': _frames});
    File('${Directory.systemTemp.path}/m1_perf.json').writeAsStringSync(json);
    debugPrint('M1PERF $json');
  });
}

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // iOS simulator: the harness drops `slow` / `loggedin` / `loggedout` [intro] into <app container>/tmp/m1_scenario
  // (launch environment variables and $HOME did not reach the Dart side).
  final file = File('${Directory.systemTemp.path}/m1_scenario');
  final words = args.isNotEmpty ? args : (file.existsSync() ? file.readAsStringSync().trim().split(RegExp(r'\s+')) : <String>[]);
  if (words.isNotEmpty && words.first != 'intro' && words.first != 'reduce') _scenario = words.first;
  _intro = words.contains('intro') || _intro;
  // `reduce`: force MediaQuery.disableAnimations (the iOS simulator ignores the Reduce Motion default; on Android use the real setting)
  _reduce = words.contains('reduce');
  registerFontLicenses();
  // for the recording log: does Flutter see the OS reduce-motion setting?
  File('${Directory.systemTemp.path}/m1_flags').writeAsStringSync('disableAnimations=${WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations}');
  if (_intro) {
    (await SharedPreferences.getInstance()).remove('eldermin_teacher_intro_seen'); // show the first-launch intro again
  } else {
    await AppPreferences.setIntroSeen();
  }
  _startPerfLog();
  runApp(GetMaterialApp(
    title: 'Eldermin Teacher',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    initialBinding: _Binding(),
    builder: (context, child) => _reduce ? MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!) : child!,
    getPages: AppPages.pages,
    home: const AuthGate(),
  ));
}
