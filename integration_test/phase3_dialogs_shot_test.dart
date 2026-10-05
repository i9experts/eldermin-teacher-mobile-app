// ignore_for_file: avoid_print
// Short walkthrough that only captures the two confirmation dialogs (sign-out
// and switch-account) - see phase3_demo_test.dart for the markers/helpers.
//   tool/dev/capture_walkthrough.sh <sim-id> <out-dir> integration_test/phase3_dialogs_shot_test.dart
import 'package:eldermin_teacher_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'phase3_demo_test.dart' as demo;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('sign-out and switch-account dialogs', (t) async {
    app.main();
    await demo.waitFor(t, find.text('Skip'));
    await t.tap(find.byKey(const Key('intro_skip')));
    await demo.waitFor(t, find.text('Sign in'));
    await demo.settle(t);
    await demo.signIn(t, 'classteacher@stub.test', 'StubPass123');
    await demo.waitFor(t, find.text('Attendance'));
    await demo.settle(t, 1500);
    // Token link while signed in -> confirmation, Cancel keeps the session.
    await demo.openLink(t, 'eldermin-teacher://login?token=stub.teacher.dummy&slug=demo-school');
    await demo.waitFor(t, find.text('Switch account?'));
    await demo.settle(t, 1500);
    await demo.shot(t, '22_deeplink_switch_account_dialog', ms: 2500);
    await t.tap(find.byKey(const Key('confirm_dialog_cancel')));
    await demo.settle(t, 800);
    expect(find.text('Attendance'), findsWidgets);
    await demo.signOutViaUi(t, shotName: '21_sign_out_confirmation_dialog');
    print('DONE');
  }, timeout: const Timeout(Duration(minutes: 6)));
}
