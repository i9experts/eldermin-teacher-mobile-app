// Phase 7c: the leave screen with the Apply bar (7b review: the floating button covered the last card) against the LOCAL STUB:
//   tool/dev/capture_7c.sh <sim> <out-dir> <port> leave
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'phase7c_common.dart';

// ignore_for_file: avoid_print

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Phase 7c leave Apply bar against the stub', (t) async {
    step('sign in');
    await signInAs(t, 'teacher@stub.test');
    step('leave apply bar');
    await openFromMore(t, 'My leave', find.byKey(const Key('leave_apply')));
    await shot(t, '7c_70_leave_apply_bar_no_overlap');
    await t.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await settle(t, 800);
    await shot(t, '7c_71_leave_scrolled_to_end_last_card_clear_of_bar');
    await leaveToShell(t);
    print('DONE:7c_leave');
  });
}
