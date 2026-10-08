// Phase 7b substitutions + My Leave walkthrough against the LOCAL STUB (dummy data), TEACHER account:
//   tool/dev/capture_7b.sh <sim> <out-dir> <port> fixtures
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'phase7b_common.dart';

// ignore_for_file: avoid_print

Finder fx(int n) => find.byKey(ValueKey('fx_${fxId(n)}'));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Phase 7b substitutions and My Leave walkthrough against the stub', (t) async {
    step('sign in');
    await signInAs(t, 'teacher@stub.test');
    await settle(t, 2500);

    // ── substitutions ──
    step('fixtures tabs');
    await openFromMore(t, 'Substitutions', fx(1));
    await shot(t, '7b_30_fixtures_covering_for_others');
    await t.tap(find.textContaining('My periods covered'));
    await waitFor(t, fx(4));
    await settle(t, 600);
    await shot(t, '7b_31_fixtures_my_periods_covered');
    await t.tap(find.textContaining('Covering for others'));
    await waitFor(t, fx(1));

    step('mark complete');
    await t.tap(fx(1));
    await waitFor(t, find.byKey(const Key('fx_complete')));
    await settle(t, 1000);
    await shot(t, '7b_32_fixture_detail_mark_complete');
    await t.tap(find.byKey(const Key('fx_complete')));
    await waitFor(t, find.byKey(const Key('confirm_dialog_confirm')));
    await settle(t, 500);
    await shot(t, '7b_33_fixture_mark_complete_confirm');
    await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
    await waitFor(t, find.text('Marked as complete.'));
    await settle(t, 800);
    await shot(t, '7b_34_fixture_completed');
    await t.pump(const Duration(seconds: 4));
    await leaveScreen(t);
    await settle(t, 800);

    step('mark complete rejected');
    await stub(t, '/__stub/mode?feature=fxcomplete&value=notassigned');
    await t.tap(fx(2));
    await waitFor(t, find.byKey(const Key('fx_complete')));
    await t.tap(find.byKey(const Key('fx_complete')));
    await waitFor(t, find.byKey(const Key('confirm_dialog_confirm')));
    await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
    await waitFor(t, find.text('Fixture not found or not in an assigned state'));
    await settle(t, 800);
    await shot(t, '7b_35_fixture_complete_rejected_by_server');
    await stub(t, '/__stub/mode?feature=fxcomplete&value=ok');
    await t.pump(const Duration(seconds: 4));
    await leaveScreen(t);

    step('fixtures states');
    await stub(t, '/__stub/mode?feature=fixtures&value=403');
    await pullToRefresh(t);
    await waitFor(t, find.byKey(const Key('screen_forbidden')));
    await shot(t, '7b_36_fixtures_403');
    await stub(t, '/__stub/mode?feature=fixtures&value=404');
    await pullToRefresh(t);
    await waitFor(t, find.byKey(const Key('screen_unavailable')));
    await shot(t, '7b_37_fixtures_not_available');
    await stub(t, '/__stub/mode?feature=fixtures&value=empty');
    await pullToRefresh(t);
    await waitFor(t, find.byKey(const Key('screen_empty')));
    await shot(t, '7b_38_fixtures_empty');
    await stub(t, '/__stub/mode?feature=fixtures&value=ok');
    await leaveToShell(t);

    // ── My leave ──
    step('leave list');
    await openFromMore(t, 'My leave', find.byKey(ValueKey('leave_${lvId(4)}')));
    await shot(t, '7b_40_leave_balance_and_history');
    await t.drag(find.byType(Scrollable).last, const Offset(0, -500));
    await settle(t, 600);
    await shot(t, '7b_41_leave_history_decisions');
    await t.drag(find.byType(Scrollable).last, const Offset(0, 700));

    step('apply form');
    await t.tap(find.byKey(const Key('leave_apply')));
    await waitFor(t, find.byKey(const Key('leave_submit')));
    await settle(t, 1000);
    await shot(t, '7b_42_leave_apply_empty');
    await t.tap(find.byKey(const Key('leave_submit')));
    await settle(t, 900);
    await shot(t, '7b_43_leave_apply_validation_errors');
    await t.pump(const Duration(seconds: 4));
    await t.tap(find.byKey(const Key('leave_type_sick')));
    await t.tap(find.byKey(const Key('leave_from')));
    await pickTomorrow(t);
    await settle(t, 600);
    await t.enterText(find.byKey(const Key('leave_reason')), 'too short');
    await t.tap(find.byKey(const Key('leave_submit')));
    await settle(t, 900);
    await shot(t, '7b_44_leave_apply_dates_and_short_reason');
    await t.pump(const Duration(seconds: 4));
    await t.enterText(find.byKey(const Key('leave_reason')), 'Fever and a doctor rest advice for two days');
    await settle(t, 600);
    await shot(t, '7b_45_leave_apply_filled');

    step('server error then success');
    await stub(t, '/__stub/mode?feature=leaveapply&value=invalid');
    await t.tap(find.byKey(const Key('leave_submit')));
    await waitFor(t, find.byKey(const Key('confirm_dialog_confirm')));
    await settle(t, 500);
    await shot(t, '7b_46_leave_apply_confirm_dialog');
    await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
    await waitFor(t, find.byKey(const Key('leave_submit_error')));
    await settle(t, 800);
    await shot(t, '7b_47_leave_apply_server_400_kept_fields');
    await stub(t, '/__stub/mode?feature=leaveapply&value=ok');
    await t.pump(const Duration(seconds: 4));
    await t.tap(find.byKey(const Key('leave_submit')));
    await waitFor(t, find.byKey(const Key('confirm_dialog_confirm')));
    await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
    await waitFor(t, find.byKey(const Key('leave_apply')));
    await settle(t, 1500);
    await shot(t, '7b_48_leave_request_sent_in_history');
    await t.pump(const Duration(seconds: 4));

    step('decided in HR then refresh');
    await stub(t, '/__stub/leave-decide?id=${lvId(4)}&status=approved&note=Approved%20-%20enjoy');
    await pullToRefresh(t);
    await settle(t, 800);
    await shot(t, '7b_49_leave_pending_became_approved_after_refresh');

    step('leave states');
    await stub(t, '/__stub/mode?feature=leavehistory&value=500');
    await pullToRefresh(t);
    await waitFor(t, find.byKey(const Key('leave_history_error')));
    await shot(t, '7b_50_leave_history_error_balance_kept');
    await stub(t, '/__stub/mode?feature=leavehistory&value=403');
    await stub(t, '/__stub/mode?feature=leavebalance&value=403');
    await pullToRefresh(t);
    await waitFor(t, find.byKey(const Key('screen_forbidden')));
    await shot(t, '7b_51_leave_403');
    await stub(t, '/__stub/mode?feature=leavehistory&value=404');
    await stub(t, '/__stub/mode?feature=leavebalance&value=404');
    await pullToRefresh(t);
    await waitFor(t, find.byKey(const Key('screen_unavailable')));
    await shot(t, '7b_52_leave_not_available');
    await stub(t, '/__stub/mode?feature=leavehistory&value=empty');
    await stub(t, '/__stub/mode?feature=leavebalance&value=ok');
    await pullToRefresh(t);
    await waitFor(t, find.byKey(const Key('leave_history_empty')));
    await shot(t, '7b_53_leave_history_empty');
    await stub(t, '/__stub/mode?feature=leavehistory&value=ok');
    await leaveToShell(t);
    print('DONE:7b_fixtures_leave');
  });
}
