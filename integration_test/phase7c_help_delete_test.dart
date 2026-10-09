// Phase 7c: help (knowledge base), about, delete-account request and the leave Apply bar against the LOCAL STUB (DUMMY data):
//   tool/dev/capture_7c.sh <sim> <out-dir> <port> help
import 'package:eldermin_teacher_app/app/modules/help/controllers/help_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'phase7c_common.dart';

// ignore_for_file: avoid_print

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Phase 7c help, about, delete account and leave against the stub', (t) async {
    step('sign in');
    await signInAs(t, 'teacher@stub.test');

    step('help');
    await openFromMore(t, 'Help', find.byKey(const Key('help_search')));
    await waitFor(t, find.text('Dashboard'));
    await settle(t, 800);
    await shot(t, '7c_50_help_list_by_module');
    await t.tap(find.byKey(const ValueKey('help_general/getting-started')));
    await waitFor(t, find.byKey(const Key('help_article_title')));
    await settle(t, 1200);
    await shot(t, '7c_51_help_article_markdown');
    await leaveScreen(t);
    await t.tap(find.byKey(const ValueKey('help_general/adversarial')));
    await waitFor(t, find.byKey(const Key('help_article_title')));
    await settle(t, 1200);
    await shot(t, '7c_52_help_article_unsafe_markup_rendered_inert');
    await leaveScreen(t);
    await t.enterText(find.byKey(const Key('help_search')), 'leave');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await settle(t, 2000);
    await shot(t, '7c_53_help_search_results');
    await t.tap(find.byKey(const Key('help_search_clear')));
    await settle(t, 800);
    await t.tap(find.byKey(const Key('help_search')));
    await t.enterText(find.byKey(const Key('help_search')), 'zzzzqq');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await settle(t, 2000);
    await shot(t, '7c_54_help_search_no_match');
    await t.tap(find.byKey(const Key('help_search_clear')));
    await settle(t, 800);
    await mode(t, 'kb', '404');
    await t.runAsync(() => Get.find<HelpController>().load(userInitiated: true));
    await settle(t, 1200);
    await shot(t, '7c_55_help_404_not_deployed');
    await mode(t, 'kb', 'ok');
    await leaveToShell(t);

    step('about');
    await openFromMore(t, 'About', find.byKey(const Key('about_name')));
    await settle(t, 1500);
    await shot(t, '7c_56_about');
    await leaveToShell(t);

    step('delete account');
    await openFromMore(t, 'Delete account', find.byKey(const Key('delete_explainer')));
    await shot(t, '7c_60_delete_account_explanation');
    await t.enterText(find.byKey(const Key('delete_reason')), 'DUMMY reason');
    await t.enterText(find.byKey(const Key('delete_confirm_field')), 'DELETE');
    await settle(t, 800);
    await shot(t, '7c_61_delete_account_typed_confirmation');
    await mode(t, 'deletereq', '403');
    await t.tap(find.byKey(const Key('delete_submit')));
    await waitFor(t, find.byKey(const Key('delete_error')), seconds: 8);
    await settle(t, 800);
    await shot(t, '7c_62_delete_account_403');
    await mode(t, 'deletereq', 'ok');
    await t.tap(find.byKey(const Key('delete_submit')));
    await waitFor(t, find.byKey(const Key('delete_done_title')));
    await settle(t, 1200);
    await shot(t, '7c_63_delete_account_request_sent_still_signed_in');
    await t.tap(find.byKey(const Key('delete_done')));
    await settle(t, 1000);
    await openFromMore(t, 'Delete account', find.byKey(const Key('delete_explainer')));
    await t.enterText(find.byKey(const Key('delete_confirm_field')), 'DELETE');
    await settle(t, 500);
    await t.tap(find.byKey(const Key('delete_submit')));
    await waitFor(t, find.byKey(const Key('delete_done_title')));
    await settle(t, 1200);
    await shot(t, '7c_64_delete_account_already_requested');
    await t.tap(find.byKey(const Key('delete_done')));
    await settle(t, 800);
    await leaveToShell(t);

    step('leave apply bar');
    await openFromMore(t, 'My leave', find.byKey(const Key('leave_apply')));
    await shot(t, '7c_70_leave_apply_bar_no_overlap');
    await leaveToShell(t);
    print('DONE:7c_help_delete');
  });
}
