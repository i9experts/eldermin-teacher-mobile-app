// Phase 7c: safeguarding concern (write only, DUMMY text) and profile + avatar against the LOCAL STUB:
//   tool/dev/capture_7c.sh <sim> <out-dir> <port> safeguarding
import 'package:eldermin_teacher_app/core/services/avatar_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'phase7c_common.dart';

// ignore_for_file: avoid_print

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Phase 7c safeguarding and profile against the stub', (t) async {
    final picker = WalkthroughPicker();
    AvatarPickers.current = picker;
    step('sign in');
    await signInAs(t, 'teacher@stub.test');

    step('safeguarding form');
    await openFromMore(t, 'Raise a concern', find.byKey(const Key('sg_notice')));
    await shot(t, '7c_30_safeguarding_form_notice');
    await t.tap(find.byKey(const Key('sg_submit')));
    await settle(t, 1200);
    await shot(t, '7c_31_safeguarding_validation_errors');
    await t.tap(find.byKey(const Key('sg_student_picker')));
    await waitFor(t, find.text('Only students of your classes are listed.'));
    await settle(t, 1800);
    await shot(t, '7c_32_safeguarding_student_picker_my_classes');
    await t.tap(find.byType(ListTile).first);
    await settle(t, 1000);
    await t.tap(find.byKey(const Key('sg_type_bullying')));
    await t.enterText(find.byKey(const Key('sg_title')), 'DUMMY summary only');
    await t.enterText(find.byKey(const Key('sg_description')), 'DUMMY text for the walkthrough, not a real concern.');
    await t.enterText(find.byKey(const Key('sg_actions')), 'DUMMY action');
    await settle(t, 600);
    await shot(t, '7c_33_safeguarding_filled_dummy');
    await t.tap(find.byKey(const Key('sg_submit')));
    await waitFor(t, find.text('Send this concern?'));
    await settle(t, 500);
    await shot(t, '7c_34_safeguarding_confirm_dialog');
    await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
    await waitFor(t, find.byKey(const Key('sg_sent_title')));
    await settle(t, 1200);
    await shot(t, '7c_35_safeguarding_report_sent');
    await t.tap(find.byKey(const Key('sg_done')));
    await settle(t, 1000);

    step('safeguarding discard');
    await openFromMore(t, 'Raise a concern', find.byKey(const Key('sg_notice')));
    await t.enterText(find.byKey(const Key('sg_description')), 'DUMMY typed text');
    await settle(t, 500);
    await t.pageBack();
    await waitFor(t, find.text('Discard this concern?'));
    await settle(t, 500);
    await shot(t, '7c_36_safeguarding_discard_dialog');
    await t.tap(find.byKey(const Key('confirm_dialog_confirm'))); // Discard, never Cancel
    await settle(t, 1000);

    step('safeguarding 403');
    await mode(t, 'safeguarding', '403');
    await openFromMore(t, 'Raise a concern', find.byKey(const Key('sg_notice')));
    await t.tap(find.byKey(const Key('sg_type_other')));
    await t.enterText(find.byKey(const Key('sg_title')), 'DUMMY');
    await t.enterText(find.byKey(const Key('sg_description')), 'DUMMY');
    await t.tap(find.byKey(const Key('sg_submit')));
    await waitFor(t, find.text('Send this concern?'));
    await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
    await waitFor(t, find.byKey(const Key('sg_submit_error')));
    await settle(t, 800);
    await shot(t, '7c_37_safeguarding_403_no_access');
    await mode(t, 'safeguarding', 'ok');
    await t.pageBack();
    await settle(t, 800);
    await confirmDiscardIfShown(t);
    await leaveToShell(t);

    step('profile');
    await t.tap(find.text('TT')); // the app-bar avatar opens /profile
    await waitFor(t, find.byKey(const Key('profile_name')));
    await settle(t, 1500);
    await shot(t, '7c_40_profile_details');
    await t.drag(find.byType(Scrollable).last, const Offset(0, -600));
    await settle(t, 800);
    await shot(t, '7c_41_profile_teaching_and_settings');
    await t.drag(find.byType(Scrollable).last, const Offset(0, 900));
    await settle(t, 600);
    await t.tap(find.byKey(const Key('avatar_gallery')));
    await waitFor(t, find.byKey(const Key('avatar_outcome_uploaded')));
    await settle(t, 1500);
    await shot(t, '7c_42_profile_photo_uploaded');
    await t.pageBack();
    await settle(t, 1500);
    await shot(t, '7c_43_home_app_bar_shows_new_photo');
    await t.tap(find.byType(InkWell).first);
    await waitFor(t, find.byKey(const Key('profile_name')));
    await mode(t, 'avatar', '503');
    await t.tap(find.byKey(const Key('avatar_gallery')));
    await waitFor(t, find.byKey(const Key('avatar_outcome_unavailable')));
    await settle(t, 1000);
    await shot(t, '7c_44_profile_upload_unavailable_503');
    await mode(t, 'avatar', 'ok');
    await t.pageBack();
    await settle(t, 800);
    await t.tap(find.byType(InkWell).first);
    await waitFor(t, find.byKey(const Key('profile_name')));
    picker.deny = const AvatarPickDenied(AvatarSource.camera);
    await t.tap(find.byKey(const Key('avatar_camera')));
    await waitFor(t, find.byKey(const Key('avatar_outcome_denied')));
    await settle(t, 1000);
    await shot(t, '7c_45_profile_camera_permission_denied');
    await leaveToShell(t);
    print('DONE:7c_safeguarding_profile');
  });
}
