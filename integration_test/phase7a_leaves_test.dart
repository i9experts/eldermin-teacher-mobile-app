// Phase 7a (student leave requests, Student 360 "Message guardian") walkthrough against the LOCAL STUB (dummy data), CLASS TEACHER account:
//   tool/dev/capture_7a.sh <sim> <out-dir>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'phase7a_common.dart';

// ignore_for_file: avoid_print

String leaveKey(int n) => 'leave_${oid7(0xC00 + n)}';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Phase 7a student leaves walkthrough against the stub', (t) async {
    step('sign in');
    await signInAs(t, 'classteacher@stub.test');
    await settle(t, 2500);

    // ── More -> Student leave requests (class teachers only) ──
    step('pending tab');
    await t.tap(navLabel('More'));
    await settle(t, 1000);
    final entry = find.text('Student leave requests');
    await t.scrollUntilVisible(entry, 250, scrollable: find.byType(Scrollable).last, maxScrolls: 10);
    await shot(t, '7a_40_more_has_student_leaves_entry', ms: 600);
    await t.tap(entry);
    await waitFor(t, find.byKey(Key(leaveKey(1))));
    await settle(t, 1200);
    await shot(t, '7a_41_leaves_pending_tab');
    await t.tap(find.textContaining('Approved'));
    await waitFor(t, find.byKey(Key(leaveKey(4))));
    await settle(t, 800);
    await shot(t, '7a_42_leaves_approved_tab');
    await t.tap(find.textContaining('Rejected'));
    await waitFor(t, find.byKey(Key(leaveKey(6))));
    await settle(t, 800);
    await shot(t, '7a_43_leaves_rejected_tab');
    await t.tap(find.textContaining('Pending'));
    await settle(t, 800);

    // ── Detail + review sheet ──
    step('review sheet');
    await t.tap(find.byKey(Key(leaveKey(1))));
    await waitFor(t, find.byKey(const Key('leave_approve')));
    await settle(t, 1000);
    await shot(t, '7a_44_leave_detail');
    await t.tap(find.byKey(const Key('leave_approve')));
    await waitFor(t, find.byKey(const Key('review_title')));
    await t.enterText(find.byKey(const Key('review_remarks')), 'Get well soon. Please send the doctor note when back.');
    await settle(t, 600);
    await shot(t, '7a_45_review_sheet_with_remarks');

    // ── 409: somebody else decided it first ──
    step('409 already decided');
    await stub(t, '/__stub/mode?feature=leavereview&value=decided');
    await t.tap(find.byKey(const Key('review_confirm')));
    await waitFor(t, find.byKey(const Key('leave_conflict')));
    await settle(t, 1500);
    await shot(t, '7a_46_review_409_already_decided');
    await stub(t, '/__stub/mode?feature=leavereview&value=ok');
    await leaveScreen(t);
    await settle(t, 800);

    // ── Approve another request: moves to Approved, counts follow ──
    step('approve');
    await t.tap(find.byKey(Key(leaveKey(2))));
    await waitFor(t, find.byKey(const Key('leave_approve')));
    await t.tap(find.byKey(const Key('leave_approve')));
    await waitFor(t, find.byKey(const Key('review_title')));
    await t.tap(find.byKey(const Key('review_confirm')));
    await waitFor(t, find.byKey(const Key('leave_decided')));
    await settle(t, 800);
    await shot(t, '7a_47_leave_approved_result');
    await settle(t, 3500);
    await leaveScreen(t);
    await settle(t, 1000);
    await shot(t, '7a_48_leaves_pending_after_decisions');

    // ── 403 in the review sheet (server text) ──
    step('403 review');
    await stub(t, '/__stub/mode?feature=leavereview&value=notmyclass');
    await t.tap(find.byKey(Key(leaveKey(3))));
    await waitFor(t, find.byKey(const Key('leave_reject')));
    await t.tap(find.byKey(const Key('leave_reject')));
    await waitFor(t, find.byKey(const Key('review_title')));
    await t.tap(find.byKey(const Key('review_confirm')));
    await waitFor(t, find.byKey(const Key('review_error')));
    await settle(t, 800);
    await shot(t, '7a_49_review_403_server_text');
    await stub(t, '/__stub/mode?feature=leavereview&value=ok');
    await t.tap(find.byKey(const Key('review_cancel')));
    await settle(t, 800);
    await leaveScreen(t);

    // ── list states: 403 / 404 ──
    step('list states');
    await stub(t, '/__stub/mode?feature=leaves&value=notclassteacher');
    await t.drag(find.byType(Scrollable).last, const Offset(0, 400));
    await waitFor(t, find.byKey(const Key('screen_forbidden')));
    await shot(t, '7a_50_leaves_403');
    await stub(t, '/__stub/mode?feature=leaves&value=404');
    await t.drag(find.byType(Scrollable).last, const Offset(0, 400));
    await waitFor(t, find.byKey(const Key('screen_unavailable')));
    await shot(t, '7a_51_leaves_not_available');
    await stub(t, '/__stub/mode?feature=leaves&value=ok');
    await leaveToShell(t);

    // ── Student 360 -> Message guardian ──
    step('student 360 entry');
    await t.tap(navLabel('Classes'));
    await settle(t, 1200);
    await t.tap(find.byKey(const ValueKey('module_students')));
    await waitFor(t, find.text('Zara Qureshi (DUMMY)'));
    await settle(t, 800);
    await t.tap(find.text('Zara Qureshi (DUMMY)'));
    await waitFor(t, find.byKey(const Key('student_profile')));
    await settle(t, 1500);
    await t.scrollUntilVisible(find.byKey(const Key('student_message_guardian')), 300, scrollable: find.byType(Scrollable).last, maxScrolls: 20);
    await settle(t, 600);
    await shot(t, '7a_60_student360_message_guardian_entry');
    await t.tap(find.byKey(const Key('student_message_guardian')));
    await waitFor(t, find.byKey(const Key('new_selected_student')));
    await waitFor(t, find.text('Mrs Qureshi (DUMMY)'));
    await settle(t, 1000);
    await shot(t, '7a_61_new_message_from_student360');
    await leaveScreen(t);
    print('DONE:7a_leaves');
  });
}
