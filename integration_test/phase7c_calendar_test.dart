// Phase 7c: school calendar, circulars (+ acknowledge), events against the LOCAL STUB (DUMMY data):
//   tool/dev/capture_7c.sh <sim> <out-dir> <port> calendar
import 'package:eldermin_teacher_app/app/modules/calendar/controllers/calendar_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'phase7c_common.dart';

// ignore_for_file: avoid_print

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Phase 7c calendar, circulars and events against the stub', (t) async {
    step('sign in');
    await signInAs(t, 'teacher@stub.test');
    final today = DateTime.now();
    DateTime inDays(int n) => DateTime(today.year, today.month, today.day + n);

    step('calendar month');
    await openFromMore(t, 'School calendar', find.byKey(const Key('cal_grid')));
    await waitFor(t, find.byKey(const Key('day_heading')));
    await shot(t, '7c_01_calendar_month_today');
    // the fee-due rows the stub sends on purpose must not exist anywhere on screen
    if (find.textContaining('Fee Due').evaluate().isNotEmpty || find.textContaining('outstanding').evaluate().isNotEmpty) throw TestFailure('fee data is visible');
    final c = Get.find<CalendarController>();
    c.selectDay(inDays(4)); // inside "Autumn break" (d+3 .. d+5, multi-day all-day)
    await settle(t, 1200);
    await shot(t, '7c_02_calendar_day_multiday');
    c.selectDay(inDays(1)); // the timed training
    await settle(t, 1200);
    await shot(t, '7c_03_calendar_day_timed');
    await t.tap(find.text('Agenda'));
    await settle(t, 1400);
    await shot(t, '7c_04_calendar_agenda');
    await t.tap(find.text('Month'));
    await settle(t, 800);
    c.selectDay(inDays(4));
    await settle(t, 1000);
    await t.tap(find.textContaining('Autumn break').first);
    await waitFor(t, find.byKey(const Key('cal_entry_sheet')));
    await settle(t, 800);
    await shot(t, '7c_05_calendar_entry_detail');
    await t.tapAt(const Offset(20, 80)); // dismiss the sheet
    await settle(t, 800);

    step('circulars');
    await t.tap(find.byKey(const Key('tab_circulars')));
    await waitFor(t, find.textContaining('Staff meeting moved'));
    await settle(t, 1000);
    await shot(t, '7c_06_circulars_list');
    await t.tap(find.textContaining('Fire drill'));
    await waitFor(t, find.byKey(const Key('circular_sheet')));
    await settle(t, 900);
    await shot(t, '7c_07_circular_detail_ack_button');
    await t.tap(find.byKey(const ValueKey('circular_link_https://example.test/evac')));
    await waitFor(t, find.text('Open this link?'));
    await settle(t, 500);
    await shot(t, '7c_08_circular_link_confirm');
    await t.tap(find.byKey(const Key('confirm_dialog_cancel')));
    await settle(t, 800);
    await t.tap(find.byKey(const Key('circular_ack_button')));
    await waitFor(t, find.byKey(const Key('circular_ack_done')));
    await settle(t, 800);
    await shot(t, '7c_09_circular_acknowledged');
    await t.tapAt(const Offset(20, 80));
    await settle(t, 800);
    await shot(t, '7c_10_circulars_after_ack');
    await t.tap(find.byKey(const Key('tab_calendar')));
    await settle(t, 800);

    step('calendar states');
    for (final e in {'403': '7c_11_calendar_403', '404': '7c_12_calendar_404_not_deployed', 'empty': '7c_13_calendar_empty'}.entries) {
      await mode(t, 'calendar', e.key);
      await pullToRefresh(t);
      await settle(t, 1200);
      await shot(t, e.value);
    }
    await mode(t, 'calendar', '500');
    await pullToRefresh(t);
    await waitFor(t, find.byKey(const Key('screen_error')));
    await shot(t, '7c_14_calendar_error_retry');
    await mode(t, 'calendar', 'ok');
    await t.tap(find.text('Try again'));
    await waitFor(t, find.byKey(const Key('cal_grid')));
    await settle(t, 1200);
    await leaveToShell(t);

    step('events');
    await openFromMore(t, 'Events', find.text('Annual Day'));
    await shot(t, '7c_20_events_list');
    await t.tap(find.text('Annual Day'));
    await waitFor(t, find.byKey(const Key('event_title')));
    await settle(t, 1500);
    await shot(t, '7c_21_event_detail');
    await leaveScreen(t);
    for (final e in {'403': '7c_22_events_403', '404': '7c_23_events_404_not_deployed', 'empty': '7c_24_events_empty'}.entries) {
      await mode(t, 'events', e.key);
      await pullToRefresh(t);
      await settle(t, 1200);
      await shot(t, e.value);
    }
    await mode(t, 'events', 'ok');
    await leaveToShell(t);
    print('DONE:7c_calendar');
  });
}
