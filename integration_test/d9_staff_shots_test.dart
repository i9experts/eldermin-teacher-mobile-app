// D9 (staff + remaining screens) walkthrough against the LOCAL STUB (tool/dev/stub_server.py, dummy data; DUMMY text only in the safeguarding form).
// Prints SHOT:<name> / STUB:<path> markers for tool/dev/capture_walkthrough.sh; every screen is captured at text scale 1.0 and 1.3:
//   tool/dev/capture_walkthrough.sh <sim> <out-dir> integration_test/d9_staff_shots_test.dart
import 'package:eldermin_teacher_app/app/modules/students/views/widgets/student_widgets.dart';
import 'package:eldermin_teacher_app/core/widgets/coming_soon_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'phase7c_common.dart';

// ignore_for_file: avoid_print

/// stub_7b._oid(0x3000 + n): the n-th seeded substitution; 0x4000 + n: the n-th leave request.
String fxId(int n) => '64d${(0x3000 + n).toRadixString(16).padLeft(21, '0')}';
String lvId(int n) => '64d${(0x4000 + n).toRadixString(16).padLeft(21, '0')}';

Future<void> homeTab(WidgetTester t) async {
  await leaveToShell(t);
  await t.tap(navLabel('Home'));
  await settle(t, 800);
}

/// The More tab keeps its scroll position and its list is lazy: start from the top, then scroll down to the (lazily built) row.
Future<void> openMore(WidgetTester t, String title, Finder until) async {
  await t.tap(navLabel('More'));
  await settle(t, 1000);
  await t.drag(find.byType(Scrollable).last, const Offset(0, 5000));
  await settle(t, 300);
  await t.scrollUntilVisible(find.text(title), 250, scrollable: find.byType(Scrollable).last, maxScrolls: 20);
  await settle(t, 400);
  await t.tap(find.text(title));
  await waitFor(t, until);
  await settle(t, 1200);
}

/// The forms are lazy lists: scroll the field into the built range first.
Future<void> reveal(WidgetTester t, String key) async {
  await t.scrollUntilVisible(find.byKey(Key(key)), 150, scrollable: find.byType(Scrollable).first);
  await settle(t, 300);
}

Future<void> screens(WidgetTester t, String sc) async {
  // ── My leave: list, apply form with validation ──
  step('leave $sc');
  await openMore(t, 'My leave', find.byKey(ValueKey('leave_${lvId(4)}')));
  await shot(t, 'd9_leave_list_$sc');
  await t.tap(find.byKey(const Key('leave_apply')));
  await waitFor(t, find.byKey(const Key('leave_submit')));
  await settle(t, 800);
  await shot(t, 'd9_leave_apply_form_$sc');
  await t.tap(find.byKey(const Key('leave_submit')));
  await settle(t, 1000);
  await shot(t, 'd9_leave_apply_validation_$sc');
  await t.pump(const Duration(seconds: 4));
  await reveal(t, 'leave_reason');
  await t.tap(find.byKey(const Key('leave_reason')));
  await settle(t, 1200);
  await shot(t, 'd9_leave_apply_keyboard_open_$sc');
  FocusManager.instance.primaryFocus?.unfocus();
  await settle(t, 500);
  await homeTab(t);

  // ── substitutions ──
  step('substitutions $sc');
  await openMore(t, 'Substitutions', find.byKey(ValueKey('fx_${fxId(1)}')));
  await shot(t, 'd9_substitutions_list_$sc');
  await t.tap(find.byKey(ValueKey('fx_${fxId(1)}')));
  await waitFor(t, find.byKey(const Key('fx_title')));
  await settle(t, 1200);
  await shot(t, 'd9_substitution_detail_$sc');
  await homeTab(t);

  // ── profile ──
  step('profile $sc');
  await openMore(t, 'Profile', find.byKey(const Key('profile_name')));
  await shot(t, 'd9_profile_$sc');
  await t.scrollUntilVisible(find.byKey(const Key('profile_delete_account')), 250, scrollable: find.byType(Scrollable).last);
  await settle(t, 600);
  await shot(t, 'd9_profile_settings_rows_$sc');
  await homeTab(t);

  // ── safeguarding (DUMMY text only) ──
  step('safeguarding $sc');
  await openMore(t, 'Raise a concern', find.byKey(const Key('sg_notice')));
  await shot(t, 'd9_safeguarding_form_$sc');
  await t.tap(find.byKey(const Key('sg_submit')));
  await settle(t, 1200);
  await shot(t, 'd9_safeguarding_validation_$sc');
  await t.pump(const Duration(seconds: 4));
  await t.tap(find.byKey(const Key('sg_student_picker')));
  await waitFor(t, find.text('Only students of your classes are listed.'));
  await settle(t, 1800);
  await shot(t, 'd9_safeguarding_student_picker_$sc');
  await t.tap(find.byType(StudentTile).first);
  await settle(t, 1000);
  await reveal(t, 'sg_type_bullying');
  await t.tap(find.byKey(const Key('sg_type_bullying')));
  await reveal(t, 'sg_title');
  await t.enterText(find.byKey(const Key('sg_title')), 'DUMMY summary only');
  await reveal(t, 'sg_description');
  await t.enterText(find.byKey(const Key('sg_description')), 'DUMMY text for the walkthrough, not a real concern.');
  await settle(t, 600);
  await shot(t, 'd9_safeguarding_filled_$sc');
  await t.tap(find.byKey(const Key('sg_submit')));
  await waitFor(t, find.text('Send this concern?'));
  await settle(t, 500);
  await shot(t, 'd9_safeguarding_confirm_dialog_$sc');
  await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
  await waitFor(t, find.byKey(const Key('sg_sent_title')));
  await settle(t, 1200);
  await shot(t, 'd9_safeguarding_report_sent_$sc');
  await t.tap(find.byKey(const Key('sg_done')));
  await settle(t, 1000);
  await homeTab(t);

  // ── help ──
  step('help $sc');
  await openMore(t, 'Help', find.byKey(const Key('help_search')));
  await waitFor(t, find.byKey(const ValueKey('help_general/getting-started')));
  await settle(t, 800);
  await shot(t, 'd9_help_list_$sc');
  await t.tap(find.text('How do I mark attendance?'));
  await settle(t, 600);
  await shot(t, 'd9_help_faq_expanded_$sc');
  await t.tap(find.text('How do I mark attendance?'));
  await settle(t, 500);
  await t.ensureVisible(find.byKey(const ValueKey('help_general/getting-started')));
  await t.tap(find.byKey(const ValueKey('help_general/getting-started')));
  await waitFor(t, find.byKey(const Key('help_article_title')));
  await settle(t, 1200);
  await shot(t, 'd9_help_article_$sc');
  await homeTab(t);

  // ── about, delete account, sign out confirm, coming soon ──
  step('account $sc');
  await openMore(t, 'About', find.byKey(const Key('about_name')));
  await shot(t, 'd9_about_$sc');
  await homeTab(t);
  await openMore(t, 'Delete account', find.byKey(const Key('delete_explainer')));
  await shot(t, 'd9_delete_account_form_$sc');
  await reveal(t, 'delete_confirm_field');
  await t.enterText(find.byKey(const Key('delete_confirm_field')), 'DELETE');
  await settle(t, 1000);
  await shot(t, 'd9_delete_account_ready_$sc');
  await t.tap(find.byKey(const Key('delete_submit')));
  await waitFor(t, find.byKey(const Key('delete_done_title')));
  await settle(t, 1200);
  await shot(t, 'd9_delete_account_done_$sc');
  await t.tap(find.byKey(const Key('delete_done')));
  await settle(t, 800);
  await homeTab(t);
  await t.tap(navLabel('More'));
  await settle(t, 800);
  await t.scrollUntilVisible(find.byKey(const Key('more_sign_out')), 250, scrollable: find.byType(Scrollable).last, maxScrolls: 25);
  await t.drag(find.byType(Scrollable).last, const Offset(0, -200));
  await settle(t, 600);
  await shot(t, 'd9_more_account_rows_$sc');
  await t.tap(find.byKey(const Key('more_sign_out')));
  await waitFor(t, find.byKey(const Key('confirm_dialog_confirm')));
  await settle(t, 600);
  await shot(t, 'd9_sign_out_confirm_$sc');
  await t.tap(find.byKey(const Key('confirm_dialog_cancel')));
  await settle(t, 700);
  Get.to(() => const ComingSoonScreen(title: 'Early Years')); // the route itself is hidden in v1: show the honest placeholder screen directly
  await waitFor(t, find.text('This screen is still being built'));
  await settle(t, 800);
  await shot(t, 'd9_coming_soon_$sc');
  await homeTab(t);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('D9 staff + remaining walkthrough', (t) async {
    step('sign in');
    await signInAs(t, 'teacher@stub.test');
    await settle(t, 2500);
    await screens(t, 'normal');
    binding.platformDispatcher.textScaleFactorTestValue = 1.3;
    await settle(t, 1200);
    await screens(t, 'scale13');
    binding.platformDispatcher.clearTextScaleFactorTestValue();
    print('DONE');
  }, timeout: const Timeout(Duration(minutes: 30)));
}
