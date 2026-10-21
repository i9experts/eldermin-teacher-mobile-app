// D8 (communication + calendar screens) walkthrough against the LOCAL STUB (tool/dev/stub_server.py + stub_7a/7b/7c, dummy data).
// Prints SHOT:<name> / STUB:<path> markers for tool/dev/capture_walkthrough.sh; every screen is captured at text scale 1.0 and 1.3:
//   tool/dev/capture_walkthrough.sh <sim> <out-dir> integration_test/d8_comms_shots_test.dart
import 'package:eldermin_teacher_app/app/modules/calendar/controllers/calendar_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'phase7c_common.dart';

// ignore_for_file: avoid_print

/// stub_7b._oid(0x1000 + n): the n-th seeded meeting.
String ptmId(int n) => '64d${(0x1000 + n).toRadixString(16).padLeft(21, '0')}';
Finder card(int n) => find.byKey(ValueKey('ptm_${ptmId(n)}'));

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

Future<void> homeTab(WidgetTester t) async {
  await leaveToShell(t);
  await t.tap(navLabel('Home'));
  await settle(t, 800);
}

Future<void> screens(WidgetTester t, String sc) async {
  final today = DateTime.now();
  DateTime inDays(int n) => DateTime(today.year, today.month, today.day + n);

  // ── messages ──
  step('inbox $sc');
  await t.tap(navLabel('Messages'));
  await waitFor(t, find.byKey(Key('thread_${threadId(1)}')));
  await settle(t, 1200);
  await shot(t, 'd8_inbox_$sc');
  await t.tap(find.byKey(Key('thread_${threadId(1)}')));
  await waitFor(t, find.byKey(const Key('chat_input')));
  await settle(t, 1500);
  await shot(t, 'd8_thread_$sc');
  await t.enterText(find.byKey(const Key('chat_input')), 'Thank you. Please see https://example.test/reading-plan/term-1/week-2/homework-guide for the reading plan, and let me know if the link does not open on your phone.');
  await settle(t, 400);
  await t.tap(find.byKey(const Key('chat_send')));
  await waitFor(t, find.textContaining('reading plan'));
  await settle(t, 1500);
  await shot(t, 'd8_thread_long_message_$sc');
  await stub(t, '/__stub/mode?feature=threadsend&value=503');
  await t.enterText(find.byKey(const Key('chat_input')), 'Please bring the signed form.');
  await settle(t, 400);
  await t.tap(find.byKey(const Key('chat_send')));
  await waitFor(t, find.byKey(const Key('msg_failed')));
  await settle(t, 800);
  await shot(t, 'd8_thread_failed_send_$sc');
  await stub(t, '/__stub/mode?feature=threadsend&value=ok');
  await t.tap(find.text('Retry'));
  await waitFor(t, find.text('Please bring the signed form.'));
  await settle(t, 1500);
  await t.tap(find.byKey(const Key('chat_input')));
  await settle(t, 1200);
  await shot(t, 'd8_thread_keyboard_open_$sc');
  FocusManager.instance.primaryFocus?.unfocus();
  await settle(t, 600);
  await leaveScreen(t);
  await waitFor(t, find.byKey(const Key('messages_new')));
  await t.tap(find.byKey(const Key('messages_new')));
  await waitFor(t, find.byKey(const Key('new_student_picker')));
  await settle(t, 800);
  await t.tap(find.byKey(const Key('new_student_picker')));
  await waitFor(t, find.text('Zara Qureshi (DUMMY)'));
  await settle(t, 800);
  await shot(t, 'd8_new_message_picker_$sc', ms: 600);
  await t.tap(find.text('Zara Qureshi (DUMMY)'));
  await waitFor(t, find.text('Mrs Qureshi (DUMMY)'));
  await settle(t, 800);
  await t.tap(find.text('Mrs Qureshi (DUMMY)'));
  await settle(t, 600);
  await t.tap(find.byKey(const Key('new_submit'))); // empty subject / message: the form says what is missing
  await settle(t, 900);
  await shot(t, 'd8_new_message_form_$sc');
  await t.pump(const Duration(seconds: 4));
  await homeTab(t);

  // ── notifications ──
  step('notifications $sc');
  await t.tap(find.byIcon(Icons.notifications_none_rounded).first);
  await waitFor(t, find.byKey(const Key('notif_mark_all')));
  await waitFor(t, find.textContaining('Substitution assigned'));
  await settle(t, 1200);
  await shot(t, 'd8_notifications_$sc');
  await homeTab(t);

  // ── calendar + circulars ──
  step('calendar $sc');
  await openMore(t, 'School calendar', find.byKey(const Key('cal_grid')));
  await waitFor(t, find.byKey(const Key('day_heading')));
  await shot(t, 'd8_calendar_month_$sc');
  final c = Get.find<CalendarController>();
  c.selectDay(inDays(4)); // inside "Autumn break" (multi-day)
  await settle(t, 1200);
  await shot(t, 'd8_calendar_selected_day_$sc');
  await t.tap(find.text('Agenda'));
  await settle(t, 1400);
  await shot(t, 'd8_calendar_agenda_$sc');
  await t.tap(find.text('Month'));
  await settle(t, 800);
  c.selectDay(inDays(4));
  await settle(t, 1000);
  await t.tap(find.textContaining('Autumn break').first);
  await waitFor(t, find.byKey(const Key('cal_entry_sheet')));
  await settle(t, 800);
  await shot(t, 'd8_calendar_entry_sheet_$sc');
  await t.tapAt(const Offset(20, 80));
  await settle(t, 800);
  await t.tap(find.byKey(const Key('tab_circulars')));
  await waitFor(t, find.textContaining('Staff meeting moved'));
  await settle(t, 1000);
  await shot(t, 'd8_circulars_$sc');
  await t.tap(find.textContaining('Fire drill'));
  await waitFor(t, find.byKey(const Key('circular_sheet')));
  await settle(t, 900);
  await shot(t, 'd8_circular_sheet_$sc');
  await t.tapAt(const Offset(20, 80));
  await settle(t, 800);
  await t.tap(find.byKey(const Key('tab_calendar')));
  await settle(t, 600);
  await homeTab(t);

  // ── events ──
  step('events $sc');
  await openMore(t, 'Events', find.text('Annual Day'));
  await shot(t, 'd8_events_list_$sc');
  await t.tap(find.text('Annual Day'));
  await waitFor(t, find.byKey(const Key('event_title')));
  await settle(t, 1500);
  await shot(t, 'd8_event_detail_$sc');
  await homeTab(t);

  // ── PTM ──
  step('ptm $sc');
  await openMore(t, 'Parent meetings', card(1));
  await shot(t, 'd8_ptm_list_$sc');
  await t.tap(find.textContaining('Past'));
  await waitFor(t, card(5));
  await settle(t, 600);
  await shot(t, 'd8_ptm_list_past_overdue_$sc');
  await t.tap(find.textContaining('Today'));
  await settle(t, 600);
  await t.tap(card(1));
  await waitFor(t, find.byKey(const Key('ptm_confirm')));
  await settle(t, 1200);
  await shot(t, 'd8_ptm_detail_$sc');
  await t.ensureVisible(find.byKey(const Key('ptm_cancel')));
  await settle(t, 600);
  await shot(t, 'd8_ptm_detail_actions_$sc');
  await t.tap(find.byKey(const Key('ptm_reschedule')));
  await waitFor(t, find.byKey(const Key('reschedule_save')));
  await settle(t, 800);
  await shot(t, 'd8_ptm_reschedule_sheet_$sc');
  await t.tap(find.byKey(const Key('reschedule_keep')));
  await settle(t, 800);
  await t.ensureVisible(find.byKey(const Key('ptm_outcome_btn')));
  await t.tap(find.byKey(const Key('ptm_outcome_btn')));
  await waitFor(t, find.byKey(const Key('outcome_save')));
  await t.ensureVisible(find.byKey(const Key('outcome_add_item')));
  await t.tap(find.byKey(const Key('outcome_add_item')));
  await settle(t, 600);
  await t.enterText(find.byKey(const Key('outcome_item_who_0')), 'Parent');
  await t.tap(find.byKey(const Key('outcome_save')));
  await settle(t, 900);
  await shot(t, 'd8_ptm_outcome_sheet_$sc');
  await t.tap(find.byKey(const Key('outcome_close')));
  await settle(t, 800);
  await t.ensureVisible(find.byKey(const Key('ptm_cancel')));
  await t.tap(find.byKey(const Key('ptm_cancel')));
  await waitFor(t, find.byKey(const Key('cancel_confirm')));
  await t.tap(find.byKey(const Key('cancel_confirm'))); // a reason is required
  await settle(t, 800);
  await shot(t, 'd8_ptm_cancel_sheet_$sc');
  await t.tap(find.byKey(const Key('cancel_keep')));
  await settle(t, 800);
  await homeTab(t);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('D8 communication + calendar walkthrough', (t) async {
    step('sign in');
    await signInAs(t, 'teacher@stub.test');
    await settle(t, 2500);
    await screens(t, 'normal');
    binding.platformDispatcher.textScaleFactorTestValue = 1.3;
    await settle(t, 1200);
    await screens(t, 'scale13');
    binding.platformDispatcher.clearTextScaleFactorTestValue();
    print('DONE');
  }, timeout: const Timeout(Duration(minutes: 25)));
}
