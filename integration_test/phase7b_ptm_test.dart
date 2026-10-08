// Phase 7b parent-teacher meetings walkthrough against the LOCAL STUB (dummy data), TEACHER account:
//   tool/dev/capture_7b.sh <sim> <out-dir> <port> ptm
import 'package:eldermin_teacher_app/app/modules/students/views/widgets/student_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'phase7b_common.dart';

// ignore_for_file: avoid_print

Finder card(int n) => find.byKey(ValueKey('ptm_${ptmId(n)}'));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Phase 7b PTM walkthrough against the stub', (t) async {
    step('sign in');
    await signInAs(t, 'teacher@stub.test');
    await settle(t, 2500);

    // ── list tabs ──
    step('list tabs');
    await openFromMore(t, 'Parent meetings', card(1));
    await shot(t, '7b_01_ptm_list_today');
    await t.tap(find.textContaining('Upcoming'));
    await waitFor(t, card(3));
    await settle(t, 600);
    await shot(t, '7b_02_ptm_list_upcoming');
    await t.tap(find.textContaining('Past'));
    await waitFor(t, card(5));
    await settle(t, 600);
    await shot(t, '7b_03_ptm_list_past_with_overdue_hint');
    await t.tap(find.textContaining('Cancelled'));
    await waitFor(t, card(8));
    await settle(t, 600);
    await shot(t, '7b_04_ptm_list_cancelled');
    await t.tap(find.textContaining('Today'));
    await settle(t, 600);

    // ── detail of a requested meeting (mine) -> confirm ──
    step('detail + confirm');
    await t.tap(card(1));
    await waitFor(t, find.byKey(const Key('ptm_confirm')));
    await settle(t, 1200);
    await shot(t, '7b_05_ptm_detail_requested_actions');
    await t.ensureVisible(find.byKey(const Key('ptm_cancel')));
    await settle(t, 600);
    await shot(t, '7b_06_ptm_detail_requested_buttons');
    await t.tap(find.byKey(const Key('ptm_confirm')));
    await waitFor(t, find.byKey(const Key('confirm_dialog_confirm')));
    await settle(t, 600);
    await shot(t, '7b_07_ptm_confirm_dialog');
    await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
    await waitFor(t, find.text('Meeting confirmed.'));
    await settle(t, 600);
    await shot(t, '7b_08_ptm_confirmed');
    await t.pump(const Duration(seconds: 4));

    // ── reschedule (the sheet opens with the current date and times) ──
    step('reschedule');
    await t.ensureVisible(find.byKey(const Key('ptm_reschedule')));
    await t.tap(find.byKey(const Key('ptm_reschedule')));
    await waitFor(t, find.byKey(const Key('reschedule_save')));
    await settle(t, 800);
    await shot(t, '7b_09_ptm_reschedule_sheet');
    await t.tap(find.byKey(const Key('reschedule_save')));
    await waitFor(t, find.textContaining('confirmed again'));
    await settle(t, 800);
    await shot(t, '7b_10_ptm_rescheduled_back_to_requested');
    await t.pump(const Duration(seconds: 4));
    await leaveScreen(t);
    await settle(t, 800);

    // ── record outcome + action items (meeting 3: confirmed, in two days) ──
    step('outcome');
    await t.tap(find.textContaining('Upcoming'));
    await waitFor(t, card(3));
    await t.tap(card(3));
    await waitFor(t, find.byKey(const Key('ptm_outcome_btn')));
    await t.ensureVisible(find.byKey(const Key('ptm_outcome_btn')));
    await t.tap(find.byKey(const Key('ptm_outcome_btn')));
    await waitFor(t, find.byKey(const Key('outcome_save')));
    await t.enterText(find.byKey(const Key('outcome_notes')), 'Parent attended. Agreed a daily reading routine and a check-in next month.');
    await t.ensureVisible(find.byKey(const Key('outcome_add_item')));
    await t.tap(find.byKey(const Key('outcome_add_item')));
    await settle(t, 600);
    await t.enterText(find.byKey(const Key('outcome_item_who_0')), 'Parent');
    await t.tap(find.byKey(const Key('outcome_save')));
    await settle(t, 900);
    await shot(t, '7b_11_ptm_outcome_sheet_item_needs_description');
    await t.enterText(find.byKey(const Key('outcome_item_desc_0')), 'Read together for 15 minutes every evening');
    await settle(t, 600);
    await shot(t, '7b_12_ptm_outcome_sheet_filled');
    await t.tap(find.byKey(const Key('outcome_save')));
    await waitFor(t, find.textContaining('Outcome recorded'));
    await settle(t, 900);
    await shot(t, '7b_13_ptm_outcome_recorded_with_action_item');
    await t.pump(const Duration(seconds: 4));
    final check = find.byWidgetPredicate((w) => w is Checkbox && w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('ptm_item_check_'));
    await t.ensureVisible(check.first);
    await t.tap(check.first);
    await waitFor(t, find.text('Marked as done.'));
    await settle(t, 700);
    await shot(t, '7b_14_ptm_action_item_done');
    await t.pump(const Duration(seconds: 4));
    await leaveScreen(t);
    await settle(t, 800);

    // ── cancel with a reason (meeting 4: requested, in five days) ──
    step('cancel');
    await t.tap(find.textContaining('Upcoming'));
    await waitFor(t, card(4));
    await t.tap(card(4));
    await waitFor(t, find.byKey(const Key('ptm_cancel')));
    await t.ensureVisible(find.byKey(const Key('ptm_cancel')));
    await t.tap(find.byKey(const Key('ptm_cancel')));
    await waitFor(t, find.byKey(const Key('cancel_confirm')));
    await t.tap(find.byKey(const Key('cancel_confirm')));
    await settle(t, 800);
    await shot(t, '7b_15_ptm_cancel_sheet_reason_required');
    await t.enterText(find.byKey(const Key('cancel_reason')), 'Parent is travelling that week');
    await settle(t, 500);
    await t.tap(find.byKey(const Key('cancel_confirm')));
    await waitFor(t, find.byKey(const Key('ptm_cancelled_box')));
    await settle(t, 900);
    await shot(t, '7b_16_ptm_cancelled_detail');
    await t.pump(const Duration(seconds: 4));
    await leaveScreen(t);
    await settle(t, 600);

    // ── someone else's meeting: no actions (reached through the student's history) ──
    step('not mine');
    await t.tap(find.textContaining('Today'));
    await waitFor(t, card(1));
    await t.tap(card(1));
    await waitFor(t, find.byKey(const Key('ptm_student')));
    await t.ensureVisible(find.byKey(ValueKey('ptm_hist_${ptmId(9)}')));
    await settle(t, 600);
    await shot(t, '7b_17_ptm_detail_with_student_history');
    await t.tap(find.byKey(ValueKey('ptm_hist_${ptmId(9)}')));
    await waitFor(t, find.byKey(const Key('ptm_not_mine')));
    await settle(t, 900);
    await shot(t, '7b_18_ptm_other_teachers_meeting_no_actions');
    await leaveScreen(t);
    await leaveScreen(t);

    // ── create ──
    step('create');
    await t.tap(find.byKey(const Key('ptm_new')));
    await waitFor(t, find.byKey(const Key('ptm_new_submit')));
    await settle(t, 1000);
    await shot(t, '7b_19_ptm_new_empty');
    await t.tap(find.byKey(const Key('ptm_new_submit')));
    await settle(t, 900);
    await shot(t, '7b_20_ptm_new_validation_errors');
    await t.pump(const Duration(seconds: 4));
    await t.tap(find.byKey(const Key('ptm_new_student')));
    await waitFor(t, find.byType(StudentTile));
    await settle(t, 800);
    await shot(t, '7b_21_ptm_new_student_picker');
    await t.tap(find.byType(StudentTile).first);
    await settle(t, 800);
    await t.tap(find.byKey(const Key('ptm_new_day')));
    await pickTomorrow(t);
    await t.tap(find.byKey(const Key('ptm_new_start')));
    await acceptTimeDialog(t);
    await t.enterText(find.byKey(const Key('ptm_new_point_0')), 'Progress in maths and reading');
    await settle(t, 600);
    await shot(t, '7b_22_ptm_new_filled');
    await t.ensureVisible(find.byKey(const Key('ptm_new_submit')));
    await t.tap(find.byKey(const Key('ptm_new_submit')));
    await waitFor(t, find.byKey(const Key('ptm_student')));
    await settle(t, 1200);
    await shot(t, '7b_23_ptm_created_requested');
    await leaveScreen(t);

    // ── list states ──
    step('list states');
    await stub(t, '/__stub/mode?feature=ptmlist&value=403');
    await pullToRefresh(t);
    await waitFor(t, find.byKey(const Key('screen_forbidden')));
    await shot(t, '7b_24_ptm_list_403');
    await stub(t, '/__stub/mode?feature=ptmlist&value=404');
    await pullToRefresh(t);
    await waitFor(t, find.byKey(const Key('screen_unavailable')));
    await shot(t, '7b_25_ptm_list_not_available');
    await stub(t, '/__stub/mode?feature=ptmlist&value=500');
    await pullToRefresh(t);
    await waitFor(t, find.byKey(const Key('screen_error')));
    await shot(t, '7b_26_ptm_list_error_retry');
    await stub(t, '/__stub/mode?feature=ptmlist&value=empty');
    await pullToRefresh(t);
    await t.tap(find.text('Try again'));
    await waitFor(t, find.byKey(const Key('screen_empty')));
    await shot(t, '7b_27_ptm_list_empty');
    await stub(t, '/__stub/mode?feature=ptmlist&value=ok');
    await pullToRefresh(t);
    await waitFor(t, card(1));

    // ── server rejections on an action ──
    step('server rejection');
    await stub(t, '/__stub/mode?feature=ptmconfirm&value=notrequested');
    await t.tap(find.textContaining('Today'));
    await settle(t, 500);
    await t.tap(card(1));
    await waitFor(t, find.byKey(const Key('ptm_student')));
    await settle(t, 800);
    await stub(t, '/__stub/mode?feature=ptmcancel&value=403');
    await t.ensureVisible(find.byKey(const Key('ptm_cancel')));
    await t.tap(find.byKey(const Key('ptm_cancel')));
    await waitFor(t, find.byKey(const Key('cancel_confirm')));
    await t.enterText(find.byKey(const Key('cancel_reason')), 'Testing the 403 text');
    await t.tap(find.byKey(const Key('cancel_confirm')));
    await waitFor(t, find.byKey(const Key('sheet_error')));
    await settle(t, 800);
    await shot(t, '7b_28_ptm_cancel_403_server_text_in_sheet');
    await stub(t, '/__stub/mode?feature=ptmcancel&value=ok');
    await t.tap(find.byKey(const Key('cancel_keep')));
    await settle(t, 800);
    await leaveToShell(t);
    print('DONE:7b_ptm');
  });
}
