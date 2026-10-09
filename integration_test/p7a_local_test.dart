// PHASE 7 PART 1 (communication) END-TO-END flows against the LOCAL backend (isolated DB eldermin_teacher_verify; NOT staging, NOT the stub,
// NO shim: the backend's id-match plugin is on, backend 265fcfa). One scenario per run: --dart-define=P7_SCENARIO=<msg|notif|leaves|ptm|fx|leave>,
// run through tool/dev/capture_p7a.sh (watchdog, screenshots, DB actions between taps, logging proxy). Credentials only via --dart-define.
// Report: eldermin-teacher-app-docs/LOCAL_VERIFICATION.md, section "Phase 7 part 1 - communication (no shim, backend 265fcfa)".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'p7a_local_common.dart';

// ignore_for_file: avoid_print, curly_braces_in_flow_control_structures

void expectEq(String what, Object? actual, Object? expected) {
  result(what, actual);
  if ('$actual' != '$expected') throw TestFailure('$what: expected $expected, got $actual');
}

void expectTrue(String what, bool cond) {
  result(what, cond);
  if (!cond) throw TestFailure('$what: expected true');
}

Finder thread(String name) => find.byKey(Key('thread_${pid(name)}'));
Finder unreadDot(String name) => find.byKey(Key('unread_${pid(name)}'));
bool hasText(String s) => find.textContaining(s).evaluate().isNotEmpty;

Future<void> openChat(WidgetTester t, String name) async {
  await waitFor(t, thread(name));
  await t.ensureVisible(thread(name));
  await settle(t, 300);
  await t.tap(thread(name));
  await waitFor(t, find.byKey(const Key('chat_title')));
  await settle(t, 1500);
}

Future<void> sendFromComposer(WidgetTester t, String text) async {
  await t.enterText(find.byKey(const Key('chat_input')), text);
  await settle(t, 400);
  await t.tap(find.byKey(const Key('chat_send')));
  await settle(t, 200);
}

// =============================================================================================================== messages (teacher B)
Future<void> msgScenario(WidgetTester t) async {
  await step(t, 'B login + home badges', () async {
    await bootAndSignIn(t, e2eClassEmail, e2eClassPassword);
    await settle(t, 3000);
    result('badges at home (B)', badges());
    await pshot(t, 'B_home_badges');
  });
  await step(t, 'inbox: open threads with unread badges', () async {
    await openInbox(t);
    await waitFor(t, thread('T1'));
    await settle(t, 1500);
    expectTrue('T1 unread dot shown', unreadDot('T1').evaluate().isNotEmpty);
    expectTrue('T2 unread dot shown', unreadDot('T2').evaluate().isNotEmpty);
    expectTrue('T3 (read thread) has no unread dot', unreadDot('T3').evaluate().isEmpty);
    expectTrue('closed T4 is not in the Open list', thread('T4').evaluate().isEmpty);
    result('tab badge', badgeOf('messages_badge'));
    await pshot(t, 'B_inbox_open_unread');
    await dbAction(t, 'check_unread');
  });
  await step(t, 'chat opens: oldest -> newest, newest visible; mark-read clears badge', () async {
    await openChat(t, 'T1');
    final first = t.getTopLeft(find.textContaining('P7 first')).dy;
    final second = t.getTopLeft(find.textContaining('P7 second')).dy;
    final third = t.getTopLeft(find.textContaining('P7 third')).dy;
    expectTrue('order first<second<third (oldest at the top, newest at the bottom)', first < second && second < third);
    await pshot(t, 'B_chat_order_oldest_to_newest');
    await realWait(t, 3);
    await leaveScreen(t);
    await waitFor(t, find.byKey(const Key('messages_new')));
    await settle(t, 1500);
    expectTrue('T1 unread dot cleared after opening', unreadDot('T1').evaluate().isEmpty);
    expectEq('tab badge after reading T1 (open unread: T2 + base thread = 2)', badgeOf('messages_badge'), '2');
    await dbAction(t, 'check_unread');
    await pshot(t, 'B_inbox_after_mark_read');
  });
  await step(t, 'send once (double tap) -> DB', () async {
    await openChat(t, 'T1');
    await t.enterText(find.byKey(const Key('chat_input')), 'P7 double tap message');
    await settle(t, 400);
    await t.tap(find.byKey(const Key('chat_send')));
    await t.tap(find.byKey(const Key('chat_send')), warnIfMissed: false); // second tap right away
    await settle(t, 2500);
    expectEq('bubbles with the sent text', find.text('P7 double tap message').evaluate().length, 1);
    await pshot(t, 'B_chat_sent_double_tap');
    await dbAction(t, 'check_send');
  });
  await step(t, 'poll: new guardian message appears within ~10 s, composer draft kept (after= proof in the proxy log)', () async {
    await t.enterText(find.byKey(const Key('chat_input')), 'P7 half-typed draft');
    await settle(t, 400);
    await dbAction(t, 'mark_poll_start');
    await dbAction(t, 'guardian_reply');
    final sw = Stopwatch()..start();
    var appeared = false;
    for (var i = 0; i < 16 && !appeared; i++) {
      await realWait(t, 1);
      appeared = hasText('P7 LIVE guardian reply');
    }
    result('seconds until the live guardian message showed (cap 16)', appeared ? (sw.elapsedMilliseconds / 1000).toStringAsFixed(1) : 'NOT SHOWN');
    expectTrue('live message appeared', appeared);
    expectEq('composer text kept', fieldText(t, find.byKey(const Key('chat_input'))), 'P7 half-typed draft');
    await pshot(t, 'B_chat_poll_new_message_draft_kept');
    await dbAction(t, 'mark_poll_end');
  });
  await step(t, 'close a thread (confirm) -> closed; closed thread composer read-only', () async {
    await t.enterText(find.byKey(const Key('chat_input')), '');
    await leaveScreen(t);
    await waitFor(t, find.byKey(const Key('messages_new')));
    await openChat(t, 'T3');
    await t.tap(find.byKey(const Key('chat_menu')));
    await settle(t, 800);
    await t.tap(find.byKey(const Key('chat_close')));
    await waitFor(t, find.text('Close this conversation?'));
    await pshot(t, 'B_close_confirm', ms: 600);
    await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
    await waitFor(t, find.byKey(const Key('chat_closed_banner')));
    await settle(t, 2000);
    expectTrue('composer replaced by the closed banner', find.byKey(const Key('chat_input')).evaluate().isEmpty);
    await pshot(t, 'B_chat_closed_composer_read_only');
    await dbAction(t, 'check_closed');
    await leaveScreen(t);
    await waitFor(t, find.byKey(const Key('messages_new')));
    await t.tap(find.descendant(of: find.byKey(const Key('messages_filter')), matching: find.text('Closed')));
    await waitFor(t, thread('T4'));
    await settle(t, 1000);
    expectTrue('closed filter lists T4 and the just-closed T3', thread('T4').evaluate().isNotEmpty && thread('T3').evaluate().isNotEmpty);
    await t.tap(thread('T4'));
    await waitFor(t, find.byKey(const Key('chat_closed_banner')));
    await settle(t, 1500);
    expectTrue('older closed thread: composer read-only', find.byKey(const Key('chat_input')).evaluate().isEmpty);
    await pshot(t, 'B_closed_thread_old');
    await leaveScreen(t);
    await t.tap(find.descendant(of: find.byKey(const Key('messages_filter')), matching: find.text('Open')));
    await settle(t, 800);
  });
  await step(t, 'long thread (520 messages) shows the NEWEST', () async {
    await openChat(t, 'T5');
    await waitFor(t, find.textContaining('P7 long msg 520 (NEWEST)'));
    expectTrue('newest message visible', hasText('P7 long msg 520 (NEWEST)'));
    expectTrue('truncation banner shown (latest 500 only)', find.byKey(const Key('chat_truncated')).evaluate().isNotEmpty);
    await pshot(t, 'B_chat_520_newest_shown');
    await leaveScreen(t);
  });
  await step(t, 'new thread from inbox +: student -> guardian -> subject + message (server 403 shown, then success)', () async {
    await waitFor(t, find.byKey(const Key('messages_new')));
    await t.tap(find.byKey(const Key('messages_new')));
    await waitFor(t, find.byKey(const Key('new_student_picker')));
    await settle(t, 800);
    await t.tap(find.byKey(const Key('new_student_picker')));
    await waitFor(t, find.text(pname('S8')));
    await settle(t, 600);
    await t.tap(find.text(pname('S8')).first);
    await waitFor(t, find.text('P7 Kamran Five (DUMMY)'));
    await settle(t, 800);
    result('guardian chips shown (names only)', [for (final n in ['P7 Kamran Five (DUMMY)', 'P7 Lubna FiveB (DUMMY)']) hasText(n)]);
    await dbAction(t, 'unlink_guardian');
    await t.tap(find.text('P7 Lubna FiveB (DUMMY)'));
    await settle(t, 500);
    await t.enterText(find.byKey(const Key('new_subject')), 'P7 New thread from UI');
    await t.enterText(find.byKey(const Key('new_message')), 'P7 first message of the new thread');
    await settle(t, 500);
    await t.tap(find.byKey(const Key('new_submit')));
    await waitFor(t, find.byKey(const Key('new_submit_error')));
    await settle(t, 800);
    result('server 403 text in the form', bannerTextOf(t, const Key('new_submit_error')));
    await pshot(t, 'B_new_thread_403_not_a_guardian');
    await t.pump(const Duration(seconds: 5)); // the 403 snackbar floats over the Send button for ~4 s
    await t.tap(find.text('P7 Kamran Five (DUMMY)'));
    await settle(t, 500);
    await t.tap(find.byKey(const Key('new_submit')));
    await waitFor(t, find.byKey(const Key('chat_input')));
    await settle(t, 2000);
    await pshot(t, 'B_new_thread_created_chat');
    await dbAction(t, 'check_new_thread');
    await leaveScreen(t);
    await waitFor(t, find.byKey(const Key('messages_new')));
  });
  await step(t, 'new thread from Student 360 (Message guardian)', () async {
    await leaveToShell(t);
    await t.tap(navLabel('Classes'));
    await settle(t, 1200);
    await t.tap(find.byKey(const ValueKey('module_students')));
    await waitFor(t, find.text(pname('S2')));
    await settle(t, 800);
    await t.tap(find.text(pname('S2')).first);
    await waitFor(t, find.byKey(const Key('student_profile')));
    await settle(t, 1500);
    await t.scrollUntilVisible(find.byKey(const Key('student_message_guardian')), 300, scrollable: find.byType(Scrollable).last, maxScrolls: 20);
    await settle(t, 500);
    await t.tap(find.byKey(const Key('student_message_guardian')));
    await waitFor(t, find.byKey(const Key('new_selected_student')));
    await waitFor(t, find.text('P7 Gulnaz One (DUMMY)'));
    await settle(t, 800);
    await t.tap(find.text('P7 Gulnaz One (DUMMY)'));
    await t.enterText(find.byKey(const Key('new_subject')), 'P7 From Student 360');
    await t.enterText(find.byKey(const Key('new_message')), 'P7 message started from the student profile');
    await settle(t, 500);
    await pshot(t, 'B_new_thread_from_student360_filled');
    await t.tap(find.byKey(const Key('new_submit')));
    await waitFor(t, find.byKey(const Key('chat_input')));
    await settle(t, 2000);
    await dbAction(t, 'check_new_thread_360');
    await leaveToShell(t);
  });
  await step(t, '>100 open threads: inbox cap vs badge', () async {
    await dbAction(t, 'threads120');
    await t.tap(navLabel('Home'));
    await settle(t, 800);
    await openInbox(t);
    await pullToRefresh(t);
    await settle(t, 2500);
    result('tab badge with 120 extra unread open threads', badgeOf('messages_badge'));
    await pshot(t, 'B_inbox_120_extra_threads_badge');
    await t.drag(find.byType(Scrollable).last, const Offset(0, -30000));
    await settle(t, 1200);
    for (var i = 0; i < 6 && find.byKey(const Key('messages_cut')).evaluate().isEmpty; i++) {
      await t.drag(find.byType(Scrollable).last, const Offset(0, -30000));
      await settle(t, 800);
    }
    result('cut note "most recent 100" shown', find.byKey(const Key('messages_cut')).evaluate().isNotEmpty);
    await pshot(t, 'B_inbox_bottom_cut_note');
    await dbAction(t, 'check_cap');
    await dbAction(t, 'threads120_remove');
  });
}

String bannerTextOf(WidgetTester t, Key k) => [for (final e in find.descendant(of: find.byKey(k), matching: find.byType(Text)).evaluate()) (e.widget as Text).data ?? ''].join(' | ');

// ============================================================================================================ notifications (B, then A)
/// Scrolls the (lazily built) list until [title] exists in the tree, then taps it (`last` = the last of several rows with the same title).
Future<void> tapRow(WidgetTester t, String title, {bool last = false}) async {
  final f = find.text(title);
  await t.drag(find.byType(Scrollable).last, const Offset(0, 8000)); // start from the top
  await settle(t, 400);
  for (var i = 0; i < 60 && f.evaluate().length < (last ? 2 : 1); i++) {
    await t.drag(find.byType(Scrollable).last, const Offset(0, -300));
    await settle(t, 250);
  }
  final target = last ? f.last : f.first;
  await t.ensureVisible(target);
  await settle(t, 300);
  await t.tap(target);
  await settle(t, 900);
}

Future<void> backToNotifications(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    if (find.byKey(const Key('notif_mark_all')).evaluate().isNotEmpty) return;
    if (find.byType(BottomNavigationBar).evaluate().isNotEmpty && find.byType(Dialog).evaluate().isEmpty) {
      await openNotifications(t); // the link ended on a shell tab: reopen the bell
      return;
    }
    await leaveScreen(t);
    await settle(t, 600);
  }
  if (find.byKey(const Key('notif_mark_all')).evaluate().isEmpty) {
    await leaveToShell(t);
    await openNotifications(t);
  }
}

Future<void> notifScenario(WidgetTester t) async {
  await step(t, 'B login; bell opens the inbox from the DB rows', () async {
    await bootAndSignIn(t, e2eClassEmail, e2eClassPassword);
    await settle(t, 3000);
    result('badges at home (B)', badges());
    await dbAction(t, 'check_notif_unread');
    await openNotifications(t);
    result('group headings present (Today / Yesterday / dated)', [hasText('Today'), hasText('Yesterday')]);
    await pshot(t, 'B_notifications_inbox_grouped_by_day');
  });
  await step(t, 'mark one read (a no-destination row stays in the inbox)', () async {
    final before = badgeOf('bell_badge');
    await tapRow(t, 'P7 General notice');
    await settle(t, 2000);
    result('after tapping "General notice": landed', landed());
    await backToNotifications(t);
    result('bell before/after reading one row (the badge is on the app bar of the shell; value read from the inbox route may be stale)', '$before -> ${badgeOf('bell_badge')}');
    await dbAction(t, 'check_notif_unread');
  });
  Future<void> link(String title, String label, {bool shotIt = false}) async {
    await tapRow(t, title);
    await settle(t, 2800);
    result('LINK $label -> landed', landed());
    if (shotIt) await pshot(t, 'B_link_${label.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}');
    await backToNotifications(t);
    await settle(t, 700);
  }

  await step(t, 'deep links by type (valid + invalid ids)', () async {
    await link('P7 New message from Gulnaz', 'message_valid', shotIt: true);
    await link('P7 message with bad id', 'message_badid');
    await link('P7 message without id', 'message_noid');
    await link('P7 PTM scheduled', 'ptm_valid', shotIt: true);
    await link('P7 PTM id does not exist', 'ptm_unknown_id', shotIt: true);
    await link('P7 Substitution assigned', 'substitution_valid');
    await link('P7 substitution bad id', 'substitution_badid');
  });
  await step(t, 'deep links 2: lesson plan, leave_status (both meanings), leave_decision, homework, other, unknown', () async {
    await link('P7 Lesson plan approved', 'lesson_plan_valid', shotIt: true);
    await link('P7 lesson plan bad id', 'lesson_plan_badid');
    await tapRow(t, 'New leave request');
    await settle(t, 2800);
    result('LINK leave_status "New leave request" (student leave, class teacher) -> landed', landed());
    await pshot(t, 'B_link_leave_status_student_leave');
    await backToNotifications(t);
    await tapRow(t, 'New leave request', last: true);
    await settle(t, 2800);
    result('LINK leave_status "New leave request" with a malformed id (class teacher) -> landed', landed());
    await backToNotifications(t);
    await tapRow(t, 'Leave request approved');
    await settle(t, 2800);
    result('LINK leave_status "Leave request approved" (staff meaning) -> landed', landed());
    await pshot(t, 'B_link_leave_status_staff_leave');
    await backToNotifications(t);
    await link('P7 Homework submitted', 'homework_valid', shotIt: true);
    await link('P7 homework bad id', 'homework_badid');
    await link('P7 Leave request approved (guardian type)', 'leave_decision');
    await link('P7 unknown future type', 'unknown_type');
  });
  await step(t, 'mark all read -> bell + DB', () async {
    await backToNotifications(t);
    await settle(t, 2500);
    await t.tap(find.byKey(const Key('notif_mark_all')));
    await settle(t, 2500);
    await pshot(t, 'B_notifications_after_mark_all_read');
    await dbAction(t, 'check_notif_unread');
    await leaveToShell(t);
    await settle(t, 1500);
    result('bell after mark all', badges());
    expectEq('bell badge cleared', badgeOf('bell_badge'), '0');
  });
  await step(t, 'cursor paging with 80 extra rows', () async {
    await dbAction(t, 'notif80');
    await openNotifications(t);
    await pullToRefresh(t);
    await settle(t, 2000);
    var drags = 0;
    while (find.byKey(const Key('notif_end')).evaluate().isEmpty && drags < 14) {
      await t.drag(find.byType(Scrollable).last, const Offset(0, -3000));
      await settle(t, 1500);
      drags++;
    }
    result('end marker reached after drags', '${find.byKey(const Key('notif_end')).evaluate().isNotEmpty} ($drags drags)');
    expectTrue('end marker shown', find.byKey(const Key('notif_end')).evaluate().isNotEmpty);
    await pshot(t, 'B_notifications_paged_to_end');
    await dbAction(t, 'check_notif_total');
    await dbAction(t, 'notif80_remove');
    await leaveToShell(t);
  });
  await step(t, 'A: login, leave_status (own staff leave) lands on /leave', () async {
    await signOutViaUi(t);
    await signIn(t, e2eTeacherEmail, e2eTeacherPassword);
    await settle(t, 2500);
    result('badges at home (A)', badges());
    await openNotifications(t);
    await pshot(t, 'A_notifications_inbox');
    await tapRow(t, 'Leave request rejected');
    await settle(t, 2800);
    result('LINK A leave_status (own leave) -> landed', landed());
    await pshot(t, 'A_link_leave_status_own_leave');
    await backToNotifications(t);
    await tapRow(t, 'New leave request');
    await settle(t, 2800);
    result('LINK A leave_status "New leave request" (A is not a class teacher) -> landed', landed());
    await backToNotifications(t);
    await tapRow(t, 'P7 guardian type in staff inbox (A)');
    await settle(t, 2000);
    result('LINK A leave_decision (not a class teacher) -> landed', landed());
    await backToNotifications(t);
    await leaveToShell(t);
  });
}

// ===================================================================================================== student leaves (B; A has none)
Future<void> leavesScenario(WidgetTester t) async {
  Finder row(String n) => find.byKey(Key('leave_${pid(n)}'));
  await step(t, 'B: student leave requests tabs from the DB', () async {
    await bootAndSignIn(t, e2eClassEmail, e2eClassPassword);
    await settle(t, 2500);
    await openFromMore(t, 'Student leave requests', find.byKey(const Key('leaves_tabs')));
    await waitFor(t, row('lv0'));
    expectTrue('the 6-A request is not listed for B', row('lv6').evaluate().isEmpty);
    await pshot(t, 'B_leaves_pending_tab');
    await t.tap(find.descendant(of: find.byKey(const Key('leaves_tabs')), matching: find.textContaining('Approved')));
    await waitFor(t, row('lv4'));
    await settle(t, 800);
    await pshot(t, 'B_leaves_approved_tab');
    await t.tap(find.descendant(of: find.byKey(const Key('leaves_tabs')), matching: find.textContaining('Rejected')));
    await waitFor(t, row('lv5'));
    await settle(t, 800);
    await pshot(t, 'B_leaves_rejected_tab');
    await t.tap(find.descendant(of: find.byKey(const Key('leaves_tabs')), matching: find.textContaining('Pending')));
    await settle(t, 800);
    result('tab labels (counts after all three loaded)', [for (final e in find.descendant(of: find.byKey(const Key('leaves_tabs')), matching: find.byType(Text)).evaluate()) (e.widget as Text).data ?? '']);
  });
  await step(t, 'approve with remarks -> DB + guardian notification', () async {
    await t.tap(row('lv0'));
    await waitFor(t, find.byKey(const Key('leave_approve')));
    await settle(t, 1000);
    await pshot(t, 'B_leave_detail_pending');
    await t.tap(find.byKey(const Key('leave_approve')));
    await waitFor(t, find.byKey(const Key('review_title')));
    await t.enterText(find.byKey(const Key('review_remarks')), 'P7 approved: please send the invitation card.');
    await settle(t, 600);
    await pshot(t, 'B_leave_review_sheet_remarks');
    await t.tap(find.byKey(const Key('review_confirm')));
    await waitFor(t, find.byKey(const Key('leave_decided')));
    await settle(t, 1200);
    await pshot(t, 'B_leave_approved_result');
    await dbAction(t, 'check_leave_approved');
    await leaveScreen(t);
    await settle(t, 1000);
  });
  await step(t, 'reject another', () async {
    await waitFor(t, row('lv1'));
    await t.tap(row('lv1'));
    await waitFor(t, find.byKey(const Key('leave_reject')));
    await t.tap(find.byKey(const Key('leave_reject')));
    await waitFor(t, find.byKey(const Key('review_title')));
    await t.enterText(find.byKey(const Key('review_remarks')), 'P7 rejected: exams that day.');
    await t.tap(find.byKey(const Key('review_confirm')));
    await waitFor(t, find.byKey(const Key('leave_decided')));
    await settle(t, 1200);
    await dbAction(t, 'check_leave_rejected');
    await leaveScreen(t);
    await settle(t, 1000);
  });
  await step(t, 'second review of the same request -> 409 with who/when', () async {
    await waitFor(t, row('lv2'));
    await t.tap(row('lv2'));
    await waitFor(t, find.byKey(const Key('leave_approve')));
    await settle(t, 800);
    await dbAction(t, 'decide_leave_409');
    await t.tap(find.byKey(const Key('leave_approve')));
    await waitFor(t, find.byKey(const Key('review_title')));
    await t.tap(find.byKey(const Key('review_confirm')));
    await waitFor(t, find.byKey(const Key('leave_conflict')), seconds: 30);
    await settle(t, 1500);
    result('409 banner text', bannerTextOf(t, const Key('leave_conflict')));
    await pshot(t, 'B_leave_409_already_decided_who_when');
    await leaveScreen(t);
    await settle(t, 800);
  });
  await step(t, 'request of another class -> server 403 shown', () async {
    await waitFor(t, row('lv3'));
    await t.tap(row('lv3'));
    await waitFor(t, find.byKey(const Key('leave_approve')));
    await settle(t, 800);
    await dbAction(t, 'move_leave_other_class');
    await t.tap(find.byKey(const Key('leave_approve')));
    await waitFor(t, find.byKey(const Key('review_title')));
    await t.tap(find.byKey(const Key('review_confirm')));
    await waitFor(t, find.byKey(const Key('review_error')), seconds: 30);
    await settle(t, 1000);
    result('403 text in the sheet', bannerTextOf(t, const Key('review_error')));
    await pshot(t, 'B_leave_403_not_your_class');
    await t.tap(find.byKey(const Key('review_cancel')));
    await settle(t, 800);
    await leaveScreen(t);
    await settle(t, 800);
    await pshot(t, 'B_leaves_pending_after_decisions');
    await dbAction(t, 'check_leaves_final');
  });
  await step(t, 'A: no student-leave entry in More', () async {
    await leaveToShell(t);
    await signOutViaUi(t);
    await signIn(t, e2eTeacherEmail, e2eTeacherPassword);
    await settle(t, 2500);
    await t.tap(navLabel('More'));
    await settle(t, 1200);
    for (var i = 0; i < 4; i++) {
      await t.drag(find.byType(Scrollable).last, const Offset(0, -700));
      await settle(t, 500);
    }
    expectTrue('A: "Student leave requests" entry absent from More', find.text('Student leave requests').evaluate().isEmpty);
    await pshot(t, 'A_more_no_student_leave_entry');
  });
}

// ========================================================================================================================= PTM (B)
Future<void> ptmScenario(WidgetTester t) async {
  Finder card(String n) => find.byKey(Key('ptm_${pid(n)}'));
  await step(t, 'B: PTM list tabs from the DB', () async {
    await bootAndSignIn(t, e2eClassEmail, e2eClassPassword);
    await settle(t, 2500);
    await openFromMore(t, 'Parent meetings', find.byKey(const Key('ptm_new')));
    result('tabs', [for (final s in ['Today', 'Upcoming', 'Past', 'Cancelled']) [for (final e in find.textContaining('$s (').evaluate()) (e.widget as Text).data ?? ''].join()]);
    await pshot(t, 'B_ptm_list_today');
    await t.tap(find.textContaining('Upcoming'));
    await waitFor(t, card('ptm0'));
    await settle(t, 800);
    await pshot(t, 'B_ptm_list_upcoming');
    await t.tap(find.textContaining('Past'));
    await waitFor(t, card('ptm4'));
    await settle(t, 800);
    await pshot(t, 'B_ptm_list_past_completed');
    await t.tap(find.textContaining('Cancelled'));
    await waitFor(t, card('ptm5'));
    await settle(t, 800);
    await pshot(t, 'B_ptm_list_cancelled');
    expectTrue("teacher A's meeting is not in B's list", card('ptm6').evaluate().isEmpty);
    await t.tap(find.textContaining('Upcoming'));
    await settle(t, 600);
  });
  await step(t, 'confirm (requested -> confirmed)', () async {
    await t.tap(card('ptm0'));
    await waitFor(t, find.byKey(const Key('ptm_confirm')));
    await settle(t, 1200);
    expectTrue('no guardian phone/e-mail text on screen', !hasText('0300-7000000') && !hasText('p7.guardian@example.invalid'));
    await pshot(t, 'B_ptm_detail_requested_actions');
    await t.tap(find.byKey(const Key('ptm_confirm')));
    await waitFor(t, find.byKey(const Key('confirm_dialog_confirm')));
    await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
    await waitFor(t, find.text('Meeting confirmed.'));
    await settle(t, 800);
    await pshot(t, 'B_ptm_confirmed');
    await dbAction(t, 'check_ptm_confirm');
    await leaveScreen(t);
    await settle(t, 800);
  });
  final target = DateTime.now().add(const Duration(days: 12));
  await step(t, 'reschedule (day semantics: what the server stores)', () async {
    await t.tap(find.textContaining('Upcoming'));
    await waitFor(t, card('ptm1'));
    await t.tap(card('ptm1'));
    await waitFor(t, find.byKey(const Key('ptm_reschedule')));
    await t.ensureVisible(find.byKey(const Key('ptm_reschedule')));
    await t.tap(find.byKey(const Key('ptm_reschedule')));
    await waitFor(t, find.byKey(const Key('reschedule_save')));
    await settle(t, 800);
    await pickDate(t, const Key('reschedule_day'), target);
    result('picked day (device-local)', '${target.year}-${target.month}-${target.day}');
    await pshot(t, 'B_ptm_reschedule_sheet_new_day');
    await t.tap(find.byKey(const Key('reschedule_save')));
    await waitFor(t, find.textContaining('confirmed again'), seconds: 30);
    await settle(t, 1200);
    await pshot(t, 'B_ptm_rescheduled_back_to_requested');
    await dbAction(t, 'check_ptm_reschedule');
    await leaveScreen(t);
    await settle(t, 800);
  });
  await step(t, 'record outcome with action item + toggle it', () async {
    await waitFor(t, card('ptm2'));
    await t.tap(card('ptm2'));
    await waitFor(t, find.byKey(const Key('ptm_outcome_btn')));
    await t.ensureVisible(find.byKey(const Key('ptm_outcome_btn')));
    await t.tap(find.byKey(const Key('ptm_outcome_btn')));
    await waitFor(t, find.byKey(const Key('outcome_save')));
    await t.enterText(find.byKey(const Key('outcome_notes')), 'P7 parent attended; agreed a reading routine.');
    await t.ensureVisible(find.byKey(const Key('outcome_add_item')));
    await t.tap(find.byKey(const Key('outcome_add_item')));
    await settle(t, 600);
    await t.enterText(find.byKey(const Key('outcome_item_who_0')), 'Parent');
    await t.enterText(find.byKey(const Key('outcome_item_desc_0')), 'P7 read together for 15 minutes every evening');
    await settle(t, 600);
    await pshot(t, 'B_ptm_outcome_sheet_filled');
    await t.tap(find.byKey(const Key('outcome_save')));
    await waitFor(t, find.textContaining('Outcome recorded'), seconds: 30);
    await settle(t, 1200);
    await pshot(t, 'B_ptm_outcome_recorded');
    await t.pump(const Duration(seconds: 4));
    final check = find.byWidgetPredicate((w) => w is Checkbox && w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('ptm_item_check_'));
    await t.ensureVisible(check.first);
    await t.tap(check.first);
    await waitFor(t, find.text('Marked as done.'), seconds: 30);
    await settle(t, 800);
    await pshot(t, 'B_ptm_action_item_done');
    await dbAction(t, 'check_ptm_outcome');
    await leaveScreen(t);
    await settle(t, 800);
  });
  await step(t, 'cancel with a reason', () async {
    await waitFor(t, card('ptm3'));
    await t.tap(card('ptm3'));
    await waitFor(t, find.byKey(const Key('ptm_cancel')));
    await t.ensureVisible(find.byKey(const Key('ptm_cancel')));
    await t.tap(find.byKey(const Key('ptm_cancel')));
    await waitFor(t, find.byKey(const Key('cancel_confirm')));
    await t.enterText(find.byKey(const Key('cancel_reason')), 'P7 parent is travelling');
    await settle(t, 500);
    await t.tap(find.byKey(const Key('cancel_confirm')));
    await waitFor(t, find.byKey(const Key('ptm_cancelled_box')), seconds: 30);
    await settle(t, 1000);
    await pshot(t, 'B_ptm_cancelled_detail');
    await dbAction(t, 'check_ptm_cancel');
    await leaveScreen(t);
    await settle(t, 800);
  });
  await step(t, "another teacher's meeting is view-only (through the student's history)", () async {
    await t.tap(find.textContaining('Today'));
    await settle(t, 800);
    final todayCards = idKeyed('ptm_');
    await t.tap(todayCards.first);
    await waitFor(t, find.byKey(const Key('ptm_student')));
    await settle(t, 1500);
    final hist = find.byKey(ValueKey('ptm_hist_${pid('ptm6')}'));
    await t.scrollUntilVisible(hist, 250, scrollable: find.byType(Scrollable).last, maxScrolls: 15);
    await pshot(t, 'B_ptm_detail_with_student_history');
    await t.tap(hist);
    await waitFor(t, find.byKey(const Key('ptm_not_mine')));
    await settle(t, 1000);
    expectTrue('no action buttons on another teacher\'s meeting', find.byKey(const Key('ptm_confirm')).evaluate().isEmpty && find.byKey(const Key('ptm_cancel')).evaluate().isEmpty);
    await pshot(t, 'B_ptm_other_teachers_meeting_view_only');
    await leaveScreen(t);
    await leaveScreen(t);
  });
  await step(t, 'Message guardian from a PTM + create a new meeting', () async {
    await t.tap(find.textContaining('Upcoming'));
    await waitFor(t, card('ptm0'));
    await settle(t, 600);
    await t.tap(card('ptm0'));
    await waitFor(t, find.byKey(const Key('ptm_message')));
    await t.ensureVisible(find.byKey(const Key('ptm_message')));
    await t.tap(find.byKey(const Key('ptm_message')));
    await waitFor(t, find.byKey(const Key('new_selected_student')));
    await waitFor(t, find.byKey(const Key('new_subject')));
    await settle(t, 1500);
    await pshot(t, 'B_ptm_message_guardian_handoff');
    await leaveScreen(t);
    await leaveScreen(t);
    await waitFor(t, find.byKey(const Key('ptm_new')));
    await t.tap(find.byKey(const Key('ptm_new')));
    await waitFor(t, find.byKey(const Key('ptm_new_submit')));
    await settle(t, 800);
    await t.tap(find.byKey(const Key('ptm_new_student')));
    await waitFor(t, find.text(pname('S2')));
    await t.tap(find.text(pname('S2')).first);
    await settle(t, 800);
    await pickDate(t, const Key('ptm_new_day'), DateTime.now().add(const Duration(days: 14)));
    await t.tap(find.byKey(const Key('ptm_new_start')));
    await waitFor(t, find.text('OK'));
    await t.tap(find.text('OK'));
    await settle(t, 900);
    await t.enterText(find.byKey(const Key('ptm_new_point_0')), 'P7 created from the app');
    await settle(t, 600);
    await pshot(t, 'B_ptm_new_filled');
    await t.ensureVisible(find.byKey(const Key('ptm_new_submit')));
    await t.tap(find.byKey(const Key('ptm_new_submit')));
    await waitFor(t, find.byKey(const Key('ptm_student')), seconds: 30);
    await settle(t, 1500);
    await pshot(t, 'B_ptm_created_requested');
    await dbAction(t, 'check_ptm_created');
    await leaveToShell(t);
  });
}

// =============================================================================================================== fixtures (B, then A)
Future<void> fxScenario(WidgetTester t) async {
  Finder fx(String n) => find.byKey(Key('fx_${pid(n)}'));
  await step(t, 'B: substitutions both tabs from the DB', () async {
    await bootAndSignIn(t, e2eClassEmail, e2eClassPassword);
    await settle(t, 2500);
    await openFromMore(t, 'Substitutions', find.byKey(const Key('fx_tabs')));
    await waitFor(t, fx('fx0'));
    await pshot(t, 'B_fixtures_covering_for_others');
    await t.tap(find.textContaining('My periods covered'));
    await settle(t, 1000);
    expectTrue('B original: open fixture visible in "My periods covered"', fx('fx4').evaluate().isNotEmpty);
    await pshot(t, 'B_fixtures_my_periods_covered');
    await t.tap(find.textContaining('Covering for others'));
    await settle(t, 800);
  });
  await step(t, 'B (substitute, assigned): mark complete -> DB completed', () async {
    await t.tap(fx('fx0'));
    await waitFor(t, find.byKey(const Key('fx_complete')));
    await settle(t, 1000);
    await pshot(t, 'B_fixture_detail_mark_complete_offered');
    await t.tap(find.byKey(const Key('fx_complete')));
    await waitFor(t, find.byKey(const Key('confirm_dialog_confirm')));
    await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
    await waitFor(t, find.text('Marked as complete.'), seconds: 30);
    await settle(t, 1000);
    await pshot(t, 'B_fixture_completed');
    await dbAction(t, 'check_fx_complete');
    await leaveScreen(t);
    await settle(t, 800);
  });
  await step(t, 'no "Mark complete" for a completed fixture and for a period where B is the original', () async {
    await t.tap(fx('fx3'));
    await waitFor(t, find.byKey(const Key('fx_title')));
    await settle(t, 1000);
    expectTrue('completed fixture: no complete button', find.byKey(const Key('fx_complete')).evaluate().isEmpty);
    await leaveScreen(t);
    await settle(t, 600);
    await t.tap(find.textContaining('My periods covered'));
    await settle(t, 800);
    await t.tap(fx('fx4'));
    await waitFor(t, find.byKey(const Key('fx_title')));
    await settle(t, 1000);
    expectTrue('B is the original teacher of an open fixture: no complete button', find.byKey(const Key('fx_complete')).evaluate().isEmpty);
    await pshot(t, 'B_fixture_original_no_complete');
    await leaveScreen(t);
    await leaveToShell(t);
  });
  await step(t, 'A (original teacher of a fixture B covers): completing is not offered', () async {
    await signOutViaUi(t);
    await signIn(t, e2eTeacherEmail, e2eTeacherPassword);
    await settle(t, 2500);
    await openFromMore(t, 'Substitutions', find.byKey(const Key('fx_tabs')));
    await t.tap(find.textContaining('My periods covered'));
    await waitFor(t, fx('fx2'));
    await settle(t, 800);
    await pshot(t, 'A_fixtures_my_periods_covered');
    await t.tap(fx('fx2'));
    await waitFor(t, find.byKey(const Key('fx_title')));
    await settle(t, 1000);
    expectTrue('A is the ORIGINAL teacher (assigned): complete is not offered', find.byKey(const Key('fx_complete')).evaluate().isEmpty);
    await pshot(t, 'A_fixture_original_assigned_no_complete');
    await leaveScreen(t);
    await leaveToShell(t);
  });
}

// =============================================================================================================== my leave (A)
Future<void> leaveScenario(WidgetTester t) async {
  await step(t, 'A: balance cards + history from the DB', () async {
    await bootAndSignIn(t, e2eTeacherEmail, e2eTeacherPassword);
    await settle(t, 2500);
    await openFromMore(t, 'My leave', find.byKey(Key('leave_${pid('my0')}')));
    await waitFor(t, find.byKey(const Key('leave_bal_annual')));
    await pshot(t, 'A_leave_balance_and_history');
    await t.drag(find.byType(Scrollable).last, const Offset(0, -500));
    await settle(t, 600);
    await pshot(t, 'A_leave_history_scrolled');
    await t.drag(find.byType(Scrollable).last, const Offset(0, 700));
  });
  await step(t, 'invalid inputs are refused client-side', () async {
    await t.tap(find.byKey(const Key('leave_apply')));
    await waitFor(t, find.byKey(const Key('leave_submit')));
    await settle(t, 800);
    await t.tap(find.byKey(const Key('leave_submit')));
    await settle(t, 900);
    await pshot(t, 'A_leave_apply_empty_refused');
    await t.pump(const Duration(seconds: 4));
    await t.tap(find.byKey(const Key('leave_type_sick')));
    await pickDate(t, const Key('leave_from'), DateTime.now().add(const Duration(days: 20)));
    await pickDate(t, const Key('leave_to'), DateTime.now().add(const Duration(days: 18)));
    await settle(t, 600);
    await t.enterText(find.byKey(const Key('leave_reason')), 'too short');
    await t.tap(find.byKey(const Key('leave_submit')));
    await settle(t, 1000);
    await pshot(t, 'A_leave_apply_end_before_start_short_reason');
    await t.pump(const Duration(seconds: 4));
    expectTrue('no confirm dialog appeared for invalid input', find.byKey(const Key('confirm_dialog_confirm')).evaluate().isEmpty);
  });
  await step(t, 'valid range -> real POST /hr/leave/self -> pending in history + DB', () async {
    await pickDate(t, const Key('leave_to'), DateTime.now().add(const Duration(days: 21)));
    await t.enterText(find.byKey(const Key('leave_reason')), 'P7 fever and a doctor rest advice');
    await settle(t, 600);
    await pshot(t, 'A_leave_apply_filled_valid_range');
    await t.tap(find.byKey(const Key('leave_submit')));
    await waitFor(t, find.byKey(const Key('confirm_dialog_confirm')));
    await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
    for (var i = 0; i < 200 && find.byKey(const Key('leave_submit')).evaluate().isNotEmpty; i++) {
      await t.pump(const Duration(milliseconds: 200)); // the form pops only after the server answered
    }
    expectTrue('the apply form closed after the POST', find.byKey(const Key('leave_submit')).evaluate().isEmpty);
    await settle(t, 2000);
    await pshot(t, 'A_leave_request_sent_pending_in_history');
    await dbAction(t, 'check_leave_applied');
  });
  await step(t, 'balance warning is informational (casual over the remaining days still submits)', () async {
    await t.tap(find.byKey(const Key('leave_apply')));
    await waitFor(t, find.byKey(const Key('leave_submit')));
    await settle(t, 800);
    await t.tap(find.byKey(const Key('leave_type_casual')));
    await pickDate(t, const Key('leave_from'), DateTime.now().add(const Duration(days: 40)));
    await pickDate(t, const Key('leave_to'), DateTime.now().add(const Duration(days: 40 + 17)));
    await t.enterText(find.byKey(const Key('leave_reason')), 'P7 long casual leave over the balance');
    await settle(t, 1000);
    result('balance hint shown', find.byKey(const Key('leave_balance_hint')).evaluate().isNotEmpty);
    await pshot(t, 'A_leave_apply_over_balance_hint');
    await t.tap(find.byKey(const Key('leave_submit')));
    await waitFor(t, find.byKey(const Key('confirm_dialog_confirm')));
    await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
    for (var i = 0; i < 200 && find.byKey(const Key('leave_submit')).evaluate().isNotEmpty; i++) {
      await t.pump(const Duration(milliseconds: 200)); // the form pops only after the server answered
    }
    expectTrue('the apply form closed after the POST', find.byKey(const Key('leave_submit')).evaluate().isEmpty);
    await settle(t, 2000);
    await dbAction(t, 'check_leave_applied');
  });
  await step(t, 'admin decision -> leave_status notification in A inbox -> deep link /leave', () async {
    await dbAction(t, 'admin_decide');
    await pullToRefresh(t);
    await settle(t, 1500);
    await pshot(t, 'A_leave_history_after_admin_decision');
    await leaveToShell(t);
    await settle(t, 1500);
    await t.tap(navLabel('Home'));
    await settle(t, 1500);
    await pullToRefresh(t);
    await settle(t, 2000);
    result('bell after the admin decision', badges());
    await openNotifications(t);
    await pshot(t, 'A_notifications_after_admin_decision');
    await tapRow(t, 'Leave request approved');
    await settle(t, 2800);
    result('LINK A leave_status from the real hook -> landed', landed());
    await pshot(t, 'A_link_leave_status_real_hook_lands_on_my_leave');
    await leaveToShell(t);
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final configured = [e2eBaseUrl, e2eTeacherEmail, e2eTeacherPassword, e2eClassEmail, e2eClassPassword, p7Scenario, p7Ids].every((e) => e.isNotEmpty);
  if (!configured) print('SKIPPED p7a_local_test: pass --dart-define for API_BASE_URL, LOCAL_* credentials, P7_SCENARIO, P7_IDS (see tool/dev/capture_p7a.sh).');
  testWidgets('Phase 7 part 1 against the LOCAL backend: $p7Scenario', skip: !configured, timeout: const Timeout(Duration(minutes: 14)), (t) async {
    switch (p7Scenario) {
      case 'msg':
        await msgScenario(t);
      case 'notif':
        await notifScenario(t);
      case 'leaves':
        await leavesScenario(t);
      case 'ptm':
        await ptmScenario(t);
      case 'fx':
        await fxScenario(t);
      case 'leave':
        await leaveScenario(t);
      default:
        throw TestFailure('unknown P7_SCENARIO $p7Scenario');
    }
    print('P7_DONE scenario=$p7Scenario failures=${e2eFailures.length}');
    for (final f in e2eFailures) print('FAILED_STEP $f');
    expect(e2eFailures, isEmpty);
  });
}
