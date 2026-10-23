// M2/M3 walkthrough on the iOS simulator, driven against the stub session (tool/m1/m1_stub_main.dart).
// One scenario per run, chosen with --dart-define=M1_WALK=a|b|c|d|e|f|g; tool/m1/walk.sh records the
// screen while it runs and cuts stills at the MARK lines this test prints:
//   MARK:<name>:<epoch ms>
// The first mark, `flash`, is the clapper (a magenta frame) the recording is aligned on.
//
//   flutter test integration_test/m2m3_walk_test.dart -d <sim> --dart-define=M1_WALK=a
//
// The simulator's software keyboard cannot be opened without UI scripting, so the keyboard is simulated
// (viewInsets + a grey panel, tool/m1 M1Hooks.keyboard); deep links are injected at DeepLinkService.handleUri
// (the same Dart entry point app_links feeds), as in the Phase 3 walkthrough.
import '../tool/m1/m1_stub_main.dart' as stub;
import 'package:eldermin_teacher_app/app/common/services/deep_link_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';

// ignore_for_file: avoid_print

const _walk = String.fromEnvironment('M1_WALK', defaultValue: 'a');
const _keyboard = 0.0 + int.fromEnvironment('M1_KB', defaultValue: 336);

void mark(String name) => print('MARK:$name:${DateTime.now().millisecondsSinceEpoch}');

Future<void> wait(WidgetTester t, int ms) async {
  // real time: the engine keeps rendering while we wait
  var left = ms;
  while (left > 0) {
    final step = left > 50 ? 50 : left;
    await t.pump(Duration(milliseconds: step));
    left -= step;
  }
}

Future<void> waitFor(WidgetTester t, Finder f, {int seconds = 30}) async {
  for (var i = 0; i < seconds * 30; i++) {
    if (f.evaluate().isNotEmpty) return;
    await t.pump(const Duration(milliseconds: 33));
  }
  final texts = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).whereType<String>().take(14).toList();
  throw TestFailure('Timed out waiting for $f (route ${Get.currentRoute}, texts $texts)');
}

Finder field(String label) => find.widgetWithText(TextFormField, label);

Future<void> keyboardUp(WidgetTester t, {int settle = 700}) async {
  stub.M1Hooks.keyboard.value = _keyboard;
  await wait(t, settle);
}

Future<void> keyboardDown(WidgetTester t, {int settle = 700}) async {
  stub.M1Hooks.keyboard.value = 0;
  await wait(t, settle);
}

/// Types [text] one character at a time so the UI reacts the way it does for a person.
Future<void> typeSlowly(WidgetTester t, Finder f, String text, {int perChar = 90}) async {
  for (var i = 1; i <= text.length; i++) {
    await t.enterText(f, text.substring(0, i));
    await wait(t, perChar);
  }
}

/// The test binding drops pointer events whose source is not `test`; dispatching them directly (not through
/// handlePointerEvent) skips the crosshair painting.
void _dispatch(PointerEvent e, HitTestResult hit) {
  final b = WidgetsBinding.instance as TestWidgetsFlutterBinding;
  // ignore: invalid_use_of_protected_member
  b.withPointerEventSource(TestBindingEventSource.test, () => b.dispatchEvent(e, hit));
}

/// A finger, dispatched straight to the gesture binding. (WidgetTester.tap / startGesture go through the live
/// test binding, which paints a crosshair under every touch: not wanted in a recording.)
class Touch {
  Touch._(this.view, this.pointer, this.position, this.hit);
  final int view;
  final int pointer;
  Offset position;
  final HitTestResult hit;
  static int _next = 7;
  static final Stopwatch _clock = Stopwatch()..start();

  static Touch down(WidgetTester t, Offset p) {
    final hit = HitTestResult();
    final view = t.view.viewId;
    WidgetsBinding.instance.hitTestInView(hit, p, view);
    final touch = Touch._(view, _next++, p, hit);
    _dispatch(PointerDownEvent(viewId: view, pointer: touch.pointer, position: p, timeStamp: _clock.elapsed), hit);
    return touch;
  }

  void moveBy(Offset d) {
    position += d;
    _dispatch(PointerMoveEvent(viewId: view, pointer: pointer, position: position, delta: d, timeStamp: _clock.elapsed), hit);
  }

  void up() => _dispatch(PointerUpEvent(viewId: view, pointer: pointer, position: position, timeStamp: _clock.elapsed), hit);
}

Future<void> tap(WidgetTester t, Finder f) async {
  await t.pump(); // layout settled before measuring
  // the photo header pushes the form down: scroll the target into view first, as a person would
  try {
    await t.ensureVisible(f.first);
  } catch (_) {/* not in a scrollable (onboarding buttons): already visible */}
  await t.pump(const Duration(milliseconds: 120));
  final touch = Touch.down(t, t.getCenter(f.first));
  await t.pump(const Duration(milliseconds: 70));
  touch.up();
  await t.pump(const Duration(milliseconds: 30));
}

/// A slow horizontal drag of the onboarding pages, in real time. Returns the open touch.
Future<Touch> dragPages(WidgetTester t, double dx, {int steps = 24, int stepMs = 45, Touch? touch}) async {
  final r = t.getRect(find.byType(PageView));
  final g = touch ?? Touch.down(t, Offset(r.center.dx, r.center.dy));
  for (var i = 0; i < steps; i++) {
    g.moveBy(Offset(dx / steps, 0));
    await t.pump(Duration(milliseconds: stepMs));
  }
  return g;
}

Future<void> boot(WidgetTester t, List<String> args) async {
  await stub.main(args);
  await t.pump();
  stub.M1Hooks.flash.value = true;
  await t.pump(const Duration(milliseconds: 250));
  mark('flash');
  stub.M1Hooks.flash.value = false;
  await t.pump(const Duration(milliseconds: 50));
}

// ---- building blocks -------------------------------------------------------------------------

Future<void> onboardingFull(WidgetTester t, {required String p}) async {
  await waitFor(t, find.byKey(const Key('intro_skip')));
  await wait(t, 1800);
  mark('${p}_intro_page1');
  // half a swipe, held, then completed
  final w = t.getRect(find.byType(PageView)).width;
  var g = await dragPages(t, -w * 0.5);
  mark('${p}_intro_half_swipe');
  await wait(t, 1600);
  mark('${p}_intro_half_swipe_held');
  g = await dragPages(t, -w * 0.5, touch: g);
  g.up();
  await wait(t, 1000);
  mark('${p}_intro_page2');
  // backwards: half way back, held, then back to page 1
  g = await dragPages(t, w * 0.5);
  mark('${p}_intro_back_half');
  await wait(t, 1200);
  g = await dragPages(t, w * 0.5, touch: g);
  g.up();
  await wait(t, 1000);
  mark('${p}_intro_back_page1');
  await wait(t, 500);
  // forward to the last page with the button
  await wait(t, 600); // hold on page 1 before moving on
  await tap(t, find.text('Next'));
  await wait(t, 1200);
  mark('${p}_intro_page2_via_next');
  await tap(t, find.text('Next'));
  await wait(t, 130);
  mark('${p}_intro_next_morphing_to_get_started');
  await wait(t, 1100);
  mark('${p}_intro_page3_get_started');
  await wait(t, 400);
  await tap(t, find.text('Get started'));
  await wait(t, 1000);
  await waitFor(t, find.text('Sign in'));
  await wait(t, 1800);
  mark('${p}_login_after_onboarding');
}

Future<void> loginKeyboard(WidgetTester t, {required String p}) async {
  await tap(t, field('Email'));
  stub.M1Hooks.keyboard.value = _keyboard;
  await wait(t, 160);
  mark('${p}_keyboard_hero_collapsing');
  await wait(t, 700);
  mark('${p}_keyboard_hero_collapsed');
  await typeSlowly(t, field('Email'), 'tess@school.test');
  await tap(t, field('Password'));
  await wait(t, 200);
  await typeSlowly(t, field('Password'), 'wrong');
  mark('${p}_keyboard_filled');
}

Future<void> schoolCode(WidgetTester t, {required String p}) async {
  await tap(t, find.byKey(const Key('school_code_toggle')));
  await wait(t, 110);
  mark('${p}_school_code_expanding');
  await wait(t, 800);
  mark('${p}_school_code_open');
}

Future<void> wrongPassword(WidgetTester t, {required String p, bool shake = true}) async {
  await tap(t, find.text('Sign in'));
  await wait(t, shake ? 140 : 100);
  mark('${p}_submit_morphing');
  await wait(t, 600);
  mark('${p}_submit_spinner');
  await waitFor(t, find.text('Invalid credentials'));
  await wait(t, 30);
  mark('${p}_error_shaking');
  await wait(t, 1000);
  mark('${p}_error_shown');
}

Future<void> goodLogin(WidgetTester t, {required String p, required bool reduce}) async {
  await tap(t, field('Password'));
  await wait(t, 200);
  await typeSlowly(t, field('Password'), 'good-pass-1');
  await keyboardDown(t, settle: 600);
  mark('${p}_ready_to_sign_in');
  await tap(t, find.text('Sign in'));
  await wait(t, 700);
  mark('${p}_success_spinner');
  // sign-in answers ~1.1 s after the tap
  await wait(t, 560);
  mark('${p}_success_check_drawing');
  await wait(t, 330);
  mark('${p}_success_check_done');
  await waitFor(t, find.byKey(const Key('app_shell_nav')));
  await wait(t, 1400);
  mark('${p}_home');
}

Future<void> forgotFlow(WidgetTester t, {required String p}) async {
  await tap(t, find.text('Forgot password?'));
  await wait(t, 1800);
  mark('${p}_forgot_form');
  await tap(t, field('Email'));
  await typeSlowly(t, field('Email'), 'tess@school.test');
  await tap(t, find.text('Send reset link'));
  await wait(t, 350);
  mark('${p}_forgot_sending');
  await waitFor(t, find.text('Check your email'));
  await wait(t, 40);
  mark('${p}_envelope_assembling');
  await wait(t, 300);
  mark('${p}_envelope_gliding');
  await wait(t, 1500);
  mark('${p}_envelope_done');
  await tap(t, find.text('Back to sign in'));
  await wait(t, 1400);
  mark('${p}_forgot_back_on_login');
}

Future<void> resetFlow(WidgetTester t, {required String p, bool withKeyboard = false}) async {
  await waitFor(t, find.text('Sign in'));
  await wait(t, 1500);
  Get.find<DeepLinkService>().handleUri(Uri.parse('eldermin-teacher://reset-password?token=abc123def456'));
  await waitFor(t, find.text('Set a new password'));
  await wait(t, 1800);
  mark('${p}_reset_form');
  await tap(t, field('New password'));
  if (withKeyboard) await keyboardUp(t);
  for (final (name, text) in [('weak', 'a'), ('fair', 'abcdefgh'), ('good', 'Abcdefg1'), ('strong', 'Abcdefg1xyz!')]) {
    await typeSlowly(t, field('New password'), text, perChar: 60);
    if (name == 'strong') {
      await wait(t, 120);
      mark('${p}_reset_strength_charging');
    }
    await wait(t, 900);
    mark('${p}_reset_strength_$name');
  }
  await tap(t, field('Confirm new password'));
  await typeSlowly(t, field('Confirm new password'), 'Abcdefg1xyz!', perChar: 40);
  if (withKeyboard) await keyboardDown(t, settle: 500);
  await tap(t, find.text('Update password'));
  await wait(t, 500);
  mark('${p}_reset_submitting');
  await waitFor(t, find.text('Sign in'));
  await wait(t, 1800);
  mark('${p}_reset_success_back_on_login');
  // an expired link
  Get.find<DeepLinkService>().handleUri(Uri.parse('eldermin-teacher://reset-password?token=expired-link-0001'));
  await waitFor(t, find.text('Set a new password'));
  await wait(t, 1500);
  await tap(t, field('New password'));
  await typeSlowly(t, field('New password'), 'Abcdefg1xyz!', perChar: 30);
  await tap(t, field('Confirm new password'));
  await typeSlowly(t, field('Confirm new password'), 'Abcdefg1xyz!', perChar: 30);
  await tap(t, find.text('Update password'));
  await waitFor(t, find.text('Request a new reset link'));
  await wait(t, 1400);
  mark('${p}_reset_expired');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('M2/M3 walkthrough $_walk', timeout: const Timeout(Duration(minutes: 8)), (t) async {
    switch (_walk) {
      case 'a': // onboarding: slow swipes, half-swipe held, backwards, Get started -> login
        await boot(t, ['loggedout', 'intro']);
        await onboardingFull(t, p: 'a');
      case 'b': // login: keyboard, school code, wrong password, success
        await boot(t, ['loggedout']);
        await waitFor(t, find.text('Sign in'));
        await wait(t, 2200);
        mark('b_login_landed');
        await loginKeyboard(t, p: 'b');
        await keyboardDown(t);
        await schoolCode(t, p: 'b');
        await wrongPassword(t, p: 'b');
        await goodLogin(t, p: 'b', reduce: false);
      case 'c': // forgot password
        await boot(t, ['loggedout']);
        await waitFor(t, find.text('Sign in'));
        await wait(t, 2200);
        await forgotFlow(t, p: 'c');
      case 'd': // reset via deep link
        await boot(t, ['loggedout']);
        await resetFlow(t, p: 'd');
      case 'e': // forced reduce motion: onboarding + login
        await boot(t, ['loggedout', 'intro', 'reduce']);
        await onboardingFull(t, p: 'e');
        await loginKeyboard(t, p: 'e');
        await keyboardDown(t);
        await schoolCode(t, p: 'e');
        await wrongPassword(t, p: 'e');
        await goodLogin(t, p: 'e', reduce: true);
      case 'f': // text scale 1.3
        await boot(t, ['loggedout', 'intro', 'scale=1.3']);
        await waitFor(t, find.byKey(const Key('intro_skip')));
        await wait(t, 1800);
        mark('f_intro_page1');
        await tap(t, find.text('Next'));
        await wait(t, 1000);
        mark('f_intro_page2');
        await tap(t, find.text('Next'));
        await wait(t, 1000);
        mark('f_intro_page3');
        await tap(t, find.text('Get started'));
        await waitFor(t, find.text('Sign in'));
        await wait(t, 2000);
        mark('f_login');
        await loginKeyboard(t, p: 'f');
        await keyboardDown(t);
        await resetFlow(t, p: 'f', withKeyboard: true);
      case 'h': // photo splash -> hand-off onto the first onboarding page (marks every ~200-300 ms of the first beat)
        await boot(t, ['loggedout', 'intro']);
        for (final (name, ms) in [('h_splash_a', 90), ('h_splash_b', 200), ('h_splash_c', 250), ('h_splash_d', 300), ('h_splash_e', 300)]) {
          await wait(t, ms);
          mark(name);
        }
        await waitFor(t, find.byKey(const Key('intro_skip')));
        await wait(t, 60);
        mark('h_flight_start');
        await wait(t, 200);
        mark('h_flight_mid');
        await wait(t, 300);
        mark('h_flight_end');
        await wait(t, 1500);
        mark('h_onboarding_1');
      case 'i': // slow init: the splash holds (rings loop, "Connecting…"), then hands off to sign in
        await boot(t, ['slow']);
        for (final (name, ms) in [('i_splash_1s', 900), ('i_splash_2s', 1000), ('i_splash_3_5s', 1500)]) {
          await wait(t, ms);
          mark(name);
        }
        await waitFor(t, find.text('Sign in'), seconds: 40);
        await wait(t, 2200);
        mark('i_login_landed');
      case 'g': // smallest iPhone: onboarding + login with keyboard
        await boot(t, ['loggedout', 'intro']);
        await waitFor(t, find.byKey(const Key('intro_skip')));
        await wait(t, 1800);
        mark('g_intro_page1');
        await tap(t, find.text('Next'));
        await wait(t, 1000);
        mark('g_intro_page2');
        await tap(t, find.text('Next'));
        await wait(t, 1000);
        mark('g_intro_page3');
        await tap(t, find.text('Get started'));
        await waitFor(t, find.text('Sign in'));
        await wait(t, 2000);
        mark('g_login');
        await loginKeyboard(t, p: 'g');
        await t.ensureVisible(find.text('Sign in'));
        await wait(t, 500);
        mark('g_login_keyboard_button_scrolled_into_view');
    }
    await wait(t, 800); // the last mark stays on screen for a moment before the closing flash
    mark('end');
    // the closing clapper: with the opening one it maps wall-clock time onto the recording
    stub.M1Hooks.flash.value = true;
    await t.pump(const Duration(milliseconds: 250));
    mark('flash_end');
    stub.M1Hooks.flash.value = false;
    await t.pump(const Duration(milliseconds: 100));
  });
}
