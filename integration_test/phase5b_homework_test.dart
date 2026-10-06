// Phase 5b homework walkthrough against the LOCAL STUB (tool/dev/stub_server.py, dummy data). Prints SHOT:<name> / STUB:<path>
// markers for tool/dev/capture_walkthrough.sh:
//   tool/dev/capture_walkthrough.sh <sim> <out-dir> integration_test/phase5b_homework_test.dart
// The native file/photo pickers cannot be driven by an integration test, so a test AttachmentPicker (registered in GetX) hands the
// app real files from the temp directory; everything after the pick (multipart upload to the stub, progress, errors, retry) is real.
import 'dart:io';
import 'package:eldermin_teacher_app/app/modules/homework/controllers/homework_form_controller.dart';
import 'package:eldermin_teacher_app/core/services/attachment_picker.dart';
import 'package:eldermin_teacher_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';

// ignore_for_file: avoid_print

Future<void> settle(WidgetTester t, [int ms = 1200]) => t.pump(Duration(milliseconds: ms));

Future<void> shot(WidgetTester t, String name, {int ms = 2000}) async {
  print('SHOT:$name');
  await t.pump(Duration(milliseconds: ms));
}

Future<void> stub(WidgetTester t, String path) async {
  print('STUB:$path');
  await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 2))); // let the capture script apply it
  await t.pump(const Duration(milliseconds: 300));
}

Future<void> waitFor(WidgetTester t, Finder f, {int seconds = 25}) async {
  for (var i = 0; i < seconds * 5; i++) {
    if (f.evaluate().isNotEmpty) return;
    await t.pump(const Duration(milliseconds: 200));
  }
  throw TestFailure('Timed out waiting for $f');
}

Finder navLabel(String label) => find.descendant(of: find.byType(BottomNavigationBar), matching: find.text(label));

class _TestPicker implements AttachmentPicker {
  List<PickedAttachment> next = [];
  @override
  Future<List<PickedAttachment>> pickDocuments() async => next;
  @override
  Future<List<PickedAttachment>> pickPhotos() async => next;
}

PickedAttachment tempFile(String name, int bytes) {
  final f = File('${Directory.systemTemp.path}/$name')..writeAsBytesSync(List<int>.filled(bytes, 37));
  return PickedAttachment(name: name, path: f.path, size: bytes);
}

Finder get page => find.descendant(of: find.byType(ListView).first, matching: find.byType(Scrollable)).first;

Future<void> scroll(WidgetTester t, double dy) async {
  await t.drag(page, Offset(0, -dy));
  await settle(t, 600);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Phase 5b homework walkthrough against the stub', (t) async {
    final picker = _TestPicker();
    Get.put<AttachmentPicker>(picker, permanent: true);
    app.main();
    await t.pump(const Duration(milliseconds: 300));
    await waitFor(t, find.text('Skip'));
    await t.tap(find.text('Skip'));
    await waitFor(t, find.text('Sign in'));
    await settle(t);
    await stub(t, '/__stub/reset-state');
    await t.enterText(find.widgetWithText(TextFormField, 'Email'), 'teacher@stub.test');
    await t.enterText(find.widgetWithText(TextFormField, 'Password'), 'StubPass123');
    await t.tap(find.text('Sign in'));
    await waitFor(t, navLabel('Classes'));
    await settle(t, 2500);

    // ── Classes grid -> Homework list ──
    await t.tap(navLabel('Classes'));
    await settle(t, 1500);
    await shot(t, '5b_00_classes_grid_live');
    await t.tap(find.byKey(const ValueKey('module_homework')));
    await waitFor(t, find.byKey(const Key('hw_new_fab')));
    await waitFor(t, find.text('Chapter 3 worksheet (DUMMY)'));
    await settle(t, 1200);
    await shot(t, '5b_10_homework_list');

    // ── Create: pristine submit -> validation errors ──
    await t.tap(find.byKey(const Key('hw_new_fab')));
    await waitFor(t, find.byKey(const Key('hw_save_draft')));
    await settle(t, 800);
    await t.tap(find.byKey(const Key('hw_save_draft')));
    await settle(t, 800);
    await shot(t, '5b_11_create_validation_errors');

    // ── fill the form: class (G5A), title, description, due date (via the controller: the date sheet is not under test here) ──
    await t.tap(find.byKey(const ValueKey('class_chip_0')));
    await settle(t, 1800);
    await t.enterText(find.byKey(const Key('hw_title_field')), 'Fractions: exercise 5.3');
    await t.enterText(find.byKey(const Key('hw_desc_field')), 'Complete all questions and show your working.');
    Get.find<HomeworkFormController>().setDueDay(DateTime.now().add(const Duration(days: 7)));
    await settle(t, 600);
    await shot(t, '5b_12_create_form_filled');

    // ── attachment: slow upload (progress), success, then a failing upload with Retry ──
    await stub(t, '/__stub/mode?feature=upload&value=slow');
    picker.next = [tempFile('Fractions worksheet.pdf', 180 * 1024)];
    await scroll(t, 700);
    await t.tap(find.byKey(const Key('hw_add_attachment')));
    await settle(t, 600);
    await t.tap(find.byKey(const Key('hw_pick_files')));
    await settle(t, 1500);
    await shot(t, '5b_13_create_uploading', ms: 400);
    await waitFor(t, find.byIcon(Icons.check_circle_rounded), seconds: 20);
    await settle(t, 800);
    await shot(t, '5b_14_create_attachment_added');
    await stub(t, '/__stub/mode?feature=upload&value=413');
    picker.next = [tempFile('Big scan.jpg', 64 * 1024)];
    await t.scrollUntilVisible(find.byKey(const Key('hw_add_attachment')), 200, scrollable: page);
    await scroll(t, 250);
    await t.tap(find.byKey(const Key('hw_add_attachment')));
    await settle(t, 600);
    await t.tap(find.byKey(const Key('hw_pick_photos')));
    await settle(t, 2000);
    await shot(t, '5b_15_create_upload_error');
    // retry succeeds once the server is fine again
    await stub(t, '/__stub/mode?feature=upload&value=ok');
    await t.scrollUntilVisible(find.textContaining('Retry').first, 200, scrollable: page);
    await scroll(t, 250);
    await t.tap(find.textContaining('Retry').first);
    await settle(t, 2500);

    // ── save fails with a server validation message, then succeeds ──
    await stub(t, '/__stub/mode?feature=hwwrite&value=400');
    await t.tap(find.byKey(const Key('hw_submit')));
    await waitFor(t, find.byKey(const Key('confirm_dialog_confirm')));
    await shot(t, '5b_16_assign_confirm', ms: 500);
    await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
    await settle(t, 2500);
    await t.drag(page, const Offset(0, 4000));
    await waitFor(t, find.byKey(const Key('hw_submit_error')));
    await settle(t, 800);
    await shot(t, '5b_17_create_server_validation_error');
    await stub(t, '/__stub/mode?feature=hwwrite&value=ok');
    await t.tap(find.byKey(const Key('hw_submit')));
    await waitFor(t, find.byKey(const Key('confirm_dialog_confirm')));
    await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
    await waitFor(t, find.byKey(const Key('hw_new_fab')));
    await settle(t, 2200);
    await shot(t, '5b_18_list_after_assign');

    // ── detail of the seeded assignment with an attachment, then its submissions ──
    await t.tap(find.text('Chapter 3 worksheet (DUMMY)'));
    await waitFor(t, find.byKey(const Key('hw_view_submissions')));
    await settle(t, 1200);
    await shot(t, '5b_20_homework_detail');
    await t.tap(find.byKey(const Key('hw_view_submissions')));
    await waitFor(t, find.text('TO GRADE'));
    await settle(t, 1500);
    await shot(t, '5b_30_submissions_list');
    await t.tap(find.byKey(const Key('chip_notHandedIn')));
    await settle(t, 1000);
    await shot(t, '5b_31_submissions_not_handed_in');
    await t.tap(find.byKey(const Key('chip_toGrade')));
    await settle(t, 800);

    // ── grade: validation error, then success ──
    await t.tap(find.text('TO GRADE').first);
    await waitFor(t, find.byKey(const Key('grade_marks')));
    await settle(t, 1000);
    await shot(t, '5b_32_grade_screen');
    await t.enterText(find.byKey(const Key('grade_marks')), '150');
    await t.tap(find.byKey(const Key('grade_save')));
    await settle(t, 800);
    await shot(t, '5b_33_grade_validation_error');
    await t.enterText(find.byKey(const Key('grade_marks')), '87.5');
    await t.enterText(find.byKey(const Key('grade_feedback')), 'Good work, check question 7.');
    await t.tap(find.byKey(const Key('grade_save')));
    await settle(t, 600);
    await shot(t, '5b_34_grade_saved', ms: 600);
    await waitFor(t, find.byKey(const Key('chip_graded')));
    await settle(t, 1200);
    await shot(t, '5b_35_submissions_after_grade');

    // ── 403 states ──
    await t.pageBack();
    await settle(t, 500);
    await t.pageBack();
    await settle(t, 800);
    await stub(t, '/__stub/mode?feature=homework&value=403');
    await t.drag(page, const Offset(0, 500));
    await waitFor(t, find.byKey(const Key('screen_forbidden')));
    await settle(t, 800);
    await shot(t, '5b_90_homework_403');
    await stub(t, '/__stub/mode?feature=homework&value=ok');
  });
}
