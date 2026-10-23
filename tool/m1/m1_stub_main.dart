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
import 'package:eldermin_teacher_app/core/models/institution.dart';
import 'package:eldermin_teacher_app/core/models/login_result.dart';
import 'package:eldermin_teacher_app/core/models/teacher_user.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
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

/// Knobs the M2/M3 walkthrough (integration_test/m2m3_walk_test.dart) turns while recording:
/// the iOS simulator's software keyboard cannot be opened without UI scripting, so the keyboard
/// is simulated (viewInsets + a grey panel); reduce motion and text scale are forced the same way.
class M1Hooks {
  M1Hooks._();
  static final keyboard = ValueNotifier<double>(0);
  static final reduce = ValueNotifier<bool>(false);
  static final textScale = ValueNotifier<double>(1);

  /// A magenta flash: the clapper that lets the recording be aligned with the test's MARK lines.
  static final flash = ValueNotifier<bool>(false);
}

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

  /// password `wrong` -> 401 "Invalid credentials"; anything else signs in after a short wait (so the spinner is seen)
  @override
  Future<LoginResult> login({required String email, required String password, String? slug}) async {
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (password == 'wrong') throw ApiException('Invalid credentials', statusCode: 401);
    return LoginResult(
      accessToken: 'stub.jwt.token',
      user: TeacherUser(id: 'u', name: 'Tess Teacher', email: email, role: 'teacher'),
      institution: const Institution(slug: 's'),
    );
  }

  @override
  Future<void> forgotPassword(String email) async => Future<void>.delayed(const Duration(milliseconds: 900));

  /// token `expired` -> 401 "invalid or has expired"; anything else succeeds
  @override
  Future<void> resetPassword({required String token, required String newPassword}) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (token == 'expired') throw ApiException('This reset link is invalid or has expired.', statusCode: 401);
  }

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
  M1Hooks.reduce.value = _reduce;
  for (final w in words) {
    if (w.startsWith('scale=')) M1Hooks.textScale.value = double.parse(w.substring(6));
  }
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
    builder: (context, child) => _hooked(context, child!),
    getPages: AppPages.pages,
    home: const AuthGate(),
  ));
}

/// Applies [M1Hooks] around the app: forced reduce motion / text scale, the simulated keyboard, the flash.
Widget _hooked(BuildContext context, Widget child) {
  return ListenableBuilder(
    listenable: Listenable.merge([M1Hooks.keyboard, M1Hooks.reduce, M1Hooks.textScale, M1Hooks.flash]),
    builder: (context, _) {
      final mq = MediaQuery.of(context);
      final kb = M1Hooks.keyboard.value;
      return Stack(
        textDirection: TextDirection.ltr,
        children: [
          Positioned.fill(
            child: MediaQuery(
              data: mq.copyWith(
                disableAnimations: M1Hooks.reduce.value || mq.disableAnimations,
                textScaler: M1Hooks.textScale.value == 1 ? mq.textScaler : TextScaler.linear(M1Hooks.textScale.value),
                viewInsets: kb > 0 ? mq.viewInsets.copyWith(bottom: kb) : mq.viewInsets,
                padding: kb > 0 ? mq.padding.copyWith(bottom: 0) : mq.padding,
              ),
              child: child,
            ),
          ),
          if (kb > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: kb,
              child: const ColoredBox(
                color: Color(0xFFD1D5DB),
                child: Center(child: Text('simulated keyboard', textDirection: TextDirection.ltr, style: TextStyle(color: Color(0xFF4B5563), fontSize: 14))),
              ),
            ),
          if (M1Hooks.flash.value) const Positioned.fill(child: ColoredBox(color: Color(0xFFFF00FF))),
        ],
      );
    },
  );
}
