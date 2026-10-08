// Phase 7a (messages with guardians + notifications inbox) walkthrough against the LOCAL STUB (dummy data), teacher account:
//   tool/dev/capture_7a.sh <sim> <out-dir>      (runs this file, then phase7a_leaves_test.dart)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'phase7a_common.dart';

// ignore_for_file: avoid_print

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Phase 7a messages + notifications walkthrough against the stub', (t) async {
    step('sign in');
    await signInAs(t, 'teacher@stub.test');
    await settle(t, 2500);

    // ── Inbox ──
    step('inbox');
    await t.tap(navLabel('Messages'));
    await waitFor(t, find.byKey(Key('thread_${threadId(1)}')));
    await settle(t, 1200);
    await shot(t, '7a_01_inbox');
    await t.tap(find.text('Closed'));
    await waitFor(t, find.byKey(Key('thread_${threadId(4)}')));
    await shot(t, '7a_02_inbox_closed_filter');
    await t.tap(find.text('Open'));
    await settle(t, 800);

    // ── Chat: opens unread thread 1 (marks it read), history oldest first ──
    step('chat');
    await t.tap(find.byKey(Key('thread_${threadId(1)}')));
    await waitFor(t, find.byKey(const Key('chat_input')));
    await settle(t, 1500);
    await shot(t, '7a_03_chat');
    await t.enterText(find.byKey(const Key('chat_input')), 'Thank you, see you on Thursday.');
    await settle(t, 400);
    await t.tap(find.byKey(const Key('chat_send')));
    await waitFor(t, find.text('Thank you, see you on Thursday.'));
    await settle(t, 1500);
    await shot(t, '7a_04_chat_sent');

    // ── Failed send: the message stays visible with "Not sent" and Retry; Retry succeeds ──
    step('failed send');
    await stub(t, '/__stub/mode?feature=threadsend&value=503');
    await t.enterText(find.byKey(const Key('chat_input')), 'Please bring the signed form.');
    await settle(t, 400);
    await t.tap(find.byKey(const Key('chat_send')));
    await waitFor(t, find.byKey(const Key('msg_failed')));
    await shot(t, '7a_05_chat_failed_send_retry');
    await stub(t, '/__stub/mode?feature=threadsend&value=ok');
    await t.tap(find.text('Retry'));
    await waitFor(t, find.text('Please bring the signed form.'));
    await settle(t, 2500);

    // ── Polling: a guardian answers on the server; the open chat appends it within ~10 s without losing the composer text ──
    step('polling');
    await t.enterText(find.byKey(const Key('chat_input')), 'half-typed reply');
    await stub(t, '/__stub/guardian-reply?thread=${threadId(1)}&body=Could%20we%20also%20talk%20about%20the%20science%20project%3F');
    await realWait(t, 12);
    await waitFor(t, find.text('Could we also talk about the science project?'), seconds: 15);
    await settle(t, 1500);
    await shot(t, '7a_06_chat_polled_new_message');

    // ── Close the conversation: confirm dialog, then a read-only composer ──
    step('close');
    await t.tap(find.byKey(const Key('chat_menu')));
    await settle(t, 700);
    await t.tap(find.byKey(const Key('chat_close')));
    await waitFor(t, find.text('Close this conversation?'));
    await shot(t, '7a_07_close_confirm', ms: 600);
    await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
    await waitFor(t, find.byKey(const Key('chat_closed_banner')));
    await settle(t, 2600);
    await shot(t, '7a_08_chat_closed_composer');
    await leaveScreen(t);
    await waitFor(t, find.byKey(const Key('messages_new')));
    await shot(t, '7a_09_inbox_after_close_and_read');

    // ── New conversation: student -> guardian -> subject + message -> chat ──
    step('new thread');
    await t.tap(find.byKey(const Key('messages_new')));
    await waitFor(t, find.byKey(const Key('new_student_picker')));
    await settle(t, 800);
    await t.tap(find.byKey(const Key('new_student_picker')));
    await waitFor(t, find.text('Zara Qureshi (DUMMY)'));
    await settle(t, 800);
    await shot(t, '7a_10_new_pick_student', ms: 600);
    await t.tap(find.text('Zara Qureshi (DUMMY)'));
    await waitFor(t, find.text('Mrs Qureshi (DUMMY)'));
    await settle(t, 800);
    await t.tap(find.text('Mrs Qureshi (DUMMY)'));
    await settle(t, 600);
    await shot(t, '7a_11_new_choose_guardian');
    await t.enterText(find.byKey(const Key('new_subject')), 'Reading practice');
    await t.enterText(find.byKey(const Key('new_message')), 'Assalamu alaikum. Zara read very well today; could she practise 10 minutes every evening?');
    await settle(t, 600);
    await shot(t, '7a_12_new_filled');
    await t.tap(find.byKey(const Key('new_submit')));
    await waitFor(t, find.byKey(const Key('chat_input')));
    await settle(t, 1800);
    await shot(t, '7a_13_new_thread_created_chat');
    await leaveScreen(t);
    await waitFor(t, find.byKey(const Key('messages_new')));
    await shot(t, '7a_14_inbox_with_new_thread');

    // ── Notifications ──
    step('notifications');
    await t.tap(find.byIcon(Icons.notifications_none_rounded).first);
    await waitFor(t, find.byKey(const Key('notif_mark_all')));
    await waitFor(t, find.textContaining('Substitution assigned'));
    await settle(t, 1200);
    await shot(t, '7a_20_notifications_inbox');
    await t.drag(find.byType(Scrollable).last, const Offset(0, -2500));
    await settle(t, 1500);
    await t.drag(find.byType(Scrollable).last, const Offset(0, -2500));
    await settle(t, 1500);
    await shot(t, '7a_21_notifications_infinite_scroll_more_pages');
    await t.drag(find.byType(Scrollable).last, const Offset(0, 6000));
    await settle(t, 800);
    await t.tap(find.byKey(const Key('notif_mark_all')));
    await settle(t, 1800);
    await shot(t, '7a_22_notifications_after_mark_all_read');
    // deep link: tapping a message notification opens that conversation
    await t.tap(find.textContaining('New message from').first);
    await waitFor(t, find.byKey(const Key('chat_title'))); // the notified thread may be the one closed above (no composer)
    await settle(t, 1500);
    await shot(t, '7a_23_notification_deeplink_opens_chat');
    await leaveScreen(t);
    await settle(t, 800);

    // ── Error / not-deployed / empty states of the inbox and the notifications list ──
    step('states');
    await stub(t, '/__stub/mode?feature=notifs&value=404');
    await t.drag(find.byType(Scrollable).last, const Offset(0, 400));
    await settle(t, 2500);
    await waitFor(t, find.byKey(const Key('screen_unavailable')));
    await shot(t, '7a_24_notifications_not_available');
    await stub(t, '/__stub/mode?feature=notifs&value=ok');
    await leaveToShell(t);
    await t.tap(navLabel('Messages'));
    await settle(t, 1200);
    await stub(t, '/__stub/mode?feature=threads&value=403');
    await t.drag(find.byType(Scrollable).last, const Offset(0, 400));
    await waitFor(t, find.byKey(const Key('screen_forbidden')));
    await shot(t, '7a_30_inbox_403_no_access');
    await stub(t, '/__stub/mode?feature=threads&value=404');
    await t.drag(find.byType(Scrollable).last, const Offset(0, 400));
    await waitFor(t, find.byKey(const Key('screen_unavailable')));
    await shot(t, '7a_31_inbox_not_available_404');
    await stub(t, '/__stub/mode?feature=threads&value=empty');
    await t.drag(find.byType(Scrollable).last, const Offset(0, 400));
    await waitFor(t, find.byKey(const Key('screen_empty')));
    await shot(t, '7a_32_inbox_empty');
    await stub(t, '/__stub/mode?feature=threads&value=ok');
    print('DONE:7a_messages');
  });
}
