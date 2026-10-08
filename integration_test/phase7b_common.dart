// Helpers of the Phase 7b walkthroughs (PTM, substitutions, My Leave) against the LOCAL STUB (tool/dev/stub_server.py + stub_7b.py, dummy data).
// Re-exports the 7a helpers (same anti-loop rules: capped waits, 240 s step budget, `leaveScreen` taps Discard never Cancel, shell watchdog).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'phase7a_common.dart';

export 'phase7a_common.dart';

// ignore_for_file: avoid_print

/// stub_7b._oid(0x1000 + n): the n-th seeded meeting.
String ptmId(int n) => '64d${(0x1000 + n).toRadixString(16).padLeft(21, '0')}';

/// stub_7b._oid(0x3000 + n): the n-th seeded fixture.
String fxId(int n) => '64d${(0x3000 + n).toRadixString(16).padLeft(21, '0')}';

/// stub_7b._oid(0x4000 + n): the n-th seeded leave request.
String lvId(int n) => '64d${(0x4000 + n).toRadixString(16).padLeft(21, '0')}';

/// More tab -> the entry with [title] -> waits for [until].
Future<void> openFromMore(WidgetTester t, String title, Finder until) async {
  await t.tap(navLabel('More'));
  await settle(t, 1000);
  final entry = find.text(title);
  await t.scrollUntilVisible(entry, 250, scrollable: find.byType(Scrollable).last, maxScrolls: 12);
  await settle(t, 400);
  await t.tap(entry);
  await waitFor(t, until);
  await settle(t, 1200);
}

/// Pull-to-refresh on the topmost list.
Future<void> pullToRefresh(WidgetTester t) async {
  await t.drag(find.byType(Scrollable).last, const Offset(0, 500));
  await t.pump(const Duration(milliseconds: 600));
  await t.pump(const Duration(seconds: 2));
}

/// Picks the day after today in the custom date sheet (falls back to "Jump to today" at a month end), then waits for the sheet to close.
Future<void> pickTomorrow(WidgetTester t) async {
  await waitFor(t, find.text('Select date'));
  final now = DateTime.now();
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  if (tomorrow.month == now.month) {
    await t.tap(find.descendant(of: find.byType(GridView), matching: find.text('${tomorrow.day}')));
  } else {
    await t.tap(find.text('Jump to today'));
  }
  await settle(t, 900);
}

/// Accepts the time dialog (OK) with whatever time it opened on.
Future<void> acceptTimeDialog(WidgetTester t) async {
  await waitFor(t, find.text('OK'));
  await settle(t, 500);
  await t.tap(find.text('OK'));
  await settle(t, 900);
}
