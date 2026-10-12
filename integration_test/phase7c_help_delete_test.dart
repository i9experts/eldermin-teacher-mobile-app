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
    // Bundled FAQs on top; the stub KB holds 3 HR articles (Dashboard / Employees / Leave) which must NOT be listed, and 2 general DUMMY ones which are.
    await waitFor(t, find.byKey(const ValueKey('help_general/getting-started')));
    await settle(t, 800);
    expect(find.byKey(const Key('help_faqs')), findsOneWidget);
    expect(find.text('How do I mark attendance?'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing, reason: 'HR article hidden');
    expect(find.text('Employees'), findsNothing, reason: 'HR article hidden');
    expect(find.text('Staff & HR'), findsNothing);
    await t.tap(find.text('How do I mark attendance?'));
    await settle(t, 600);
    expect(find.textContaining('last 7 days'), findsOneWidget);
    await shot(t, '7c_50_help_faqs_and_teacher_articles');
    await t.tap(find.text('How do I mark attendance?')); // collapse again
    await settle(t, 600);
    await t.ensureVisible(find.byKey(const ValueKey('help_general/getting-started')));
    await t.tap(find.byKey(const ValueKey('help_general/getting-started')));
    await waitFor(t, find.byKey(const Key('help_article_title')));
    await settle(t, 1200);
    await shot(t, '7c_51_help_article_markdown');
    await leaveScreen(t);
    await t.ensureVisible(find.byKey(const ValueKey('help_general/adversarial')));
    await t.tap(find.byKey(const ValueKey('help_general/adversarial')));
    await waitFor(t, find.byKey(const Key('help_article_title')));
    await settle(t, 1200);
    await shot(t, '7c_52_help_article_unsafe_markup_rendered_inert');
    await leaveScreen(t);
    await t.drag(find.byType(ListView).first, const Offset(0, 2000)); // back to the top (the search field scrolled away)
    await settle(t, 600);
    await t.enterText(find.byKey(const Key('help_search')), 'attendance');
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
    expect(find.byKey(const Key('help_faqs')), findsOneWidget, reason: 'bundled FAQs survive a KB failure');
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

    print('DONE:7c_help_delete');
  });
}
