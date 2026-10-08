// Phase 7b My Leave for an account WITHOUT a leave balance document (hasPolicy false), CLASS TEACHER account:
//   tool/dev/capture_7b.sh <sim> <out-dir> <port> nopolicy
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'phase7b_common.dart';

// ignore_for_file: avoid_print

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Phase 7b My Leave without a policy against the stub', (t) async {
    step('sign in');
    await signInAs(t, 'classteacher@stub.test');
    await settle(t, 2500);
    step('leave without policy');
    await openFromMore(t, 'My leave', find.byKey(const Key('leave_no_policy')));
    await shot(t, '7b_54_leave_no_policy_class_teacher');
    await leaveToShell(t);
    print('DONE:7b_nopolicy');
  });
}
