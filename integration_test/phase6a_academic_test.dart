// Phase 6a (lesson plans + syllabus) walkthrough against the LOCAL STUB (tool/dev/stub_server.py, dummy data). Prints SHOT:<name> /
// STUB:<path> markers for tool/dev/capture_walkthrough.sh:
//   tool/dev/capture_walkthrough.sh <sim> <out-dir> integration_test/phase6a_academic_test.dart
// The native document picker cannot be driven by an integration test, so a test LessonPlanSourcePicker (registered in GetX) hands the app a
// real temp file; everything after the pick (multipart upload to the stub, parse failure / success, prefilled form) is real. Dates and
// the plan date are set through the controller (the date sheet is not under test here).
import 'dart:io';
import 'package:eldermin_teacher_app/app/modules/lesson_plans/controllers/lesson_plan_form_controller.dart';
import 'package:eldermin_teacher_app/core/services/attachment_picker.dart' show PickedAttachment;
import 'package:eldermin_teacher_app/core/services/lesson_plan_source_picker.dart';
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
  await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
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

class _TestSourcePicker implements LessonPlanSourcePicker {
  PickedAttachment? next;
  @override
  Future<PickedAttachment?> pick() async => next;
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

  testWidgets('Phase 6a lesson plans and syllabus walkthrough against the stub', (t) async {
    final picker = _TestSourcePicker();
    Get.put<LessonPlanSourcePicker>(picker, permanent: true);
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

    // ── Classes grid: both modules live ──
    await t.tap(navLabel('Classes'));
    await settle(t, 1500);
    await shot(t, '6a_00_classes_grid_live');

    // ── Lesson plans list: status chips, rejected reason ──
    await t.tap(find.byKey(const ValueKey('module_lesson_plans')));
    await waitFor(t, find.byKey(const Key('lp_new_fab')));
    await waitFor(t, find.text('Fractions (DUMMY)'));
    await settle(t, 1200);
    await shot(t, '6a_10_lesson_plans_list');
    await t.tap(find.byKey(const Key('chip_rejected')));
    await settle(t, 800);
    await shot(t, '6a_11_rejected_filter_reason');
    await t.tap(find.text('Fractions (DUMMY)'));
    await waitFor(t, find.byKey(const Key('lp_rejection')));
    await settle(t, 1000);
    await shot(t, '6a_12_rejected_plan_detail');

    // ── Edit and resubmit the rejected plan ──
    await t.tap(find.byKey(const Key('lp_edit')));
    await waitFor(t, find.byKey(const Key('lp_edit_rejection')));
    await settle(t, 1000);
    await shot(t, '6a_13_edit_rejected_plan');
    await t.enterText(find.byKey(const Key('lp_assessment_field')), 'Exit ticket: three fraction questions.');
    await settle(t, 500);
    await t.tap(find.byKey(const Key('lp_submit_approval')));
    await waitFor(t, find.byKey(const Key('confirm_dialog_confirm')));
    await shot(t, '6a_14_resubmit_confirm', ms: 500);
    await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
    await waitFor(t, find.byKey(const Key('lp_under_review')));
    await settle(t, 1500);
    await t.pageBack();
    await waitFor(t, find.byKey(const Key('lp_new_fab')));
    await settle(t, 1200);

    // ── Create: pristine submit -> validation errors, then fill ──
    await t.tap(find.byKey(const Key('chip_all')));
    await t.tap(find.byKey(const Key('lp_new_fab')));
    await waitFor(t, find.byKey(const Key('lp_save_draft')));
    await settle(t, 800);
    await t.tap(find.byKey(const Key('lp_save_draft')));
    await settle(t, 800);
    await shot(t, '6a_20_create_validation_errors');
    await t.tap(find.byKey(const ValueKey('class_chip_0')));
    await settle(t, 600);
    await t.enterText(find.byKey(const Key('lp_topic_field')), 'Adding fractions with unlike denominators');
    final form = Get.find<LessonPlanFormController>();
    form.setPlanDay(DateTime.now().add(const Duration(days: 2)));
    await t.enterText(find.byKey(const Key('lp_duration_field')), '45');
    await t.enterText(find.byKey(ValueKey('lp_obj_${form.objectives.first.id}')), 'Students will be able to add fractions with unlike denominators.');
    await settle(t, 400);
    await scroll(t, 500);
    await t.tap(find.byKey(const Key('method_activity')));
    await t.tap(find.byKey(const Key('res_Textbook')));
    await t.tap(find.byKey(const Key('res_Whiteboard')));
    await settle(t, 600);
    await shot(t, '6a_21_create_form_filled');
    await t.tap(find.byKey(const Key('lp_submit_approval')));
    await waitFor(t, find.byKey(const Key('confirm_dialog_confirm')));
    await shot(t, '6a_22_submit_confirm', ms: 500);
    await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
    await waitFor(t, find.byKey(const Key('lp_new_fab')));
    await settle(t, 2400);
    await t.tap(find.byKey(const Key('chip_submitted')));
    await settle(t, 800);
    await shot(t, '6a_23_list_after_submit');
    await t.tap(find.byKey(const Key('chip_all')));

    // ── Upload & parse: failure (AI unavailable), then success -> prefilled form for review ──
    await t.tap(find.byKey(const Key('lp_upload_action')));
    await waitFor(t, find.byKey(const Key('lp_pick_file')));
    await settle(t, 800);
    await shot(t, '6a_30_upload_idle');
    picker.next = tempFile('Term 2 week 5 lesson plan.docx', 2048);
    await t.tap(find.byKey(const Key('lp_pick_file')));
    await waitFor(t, find.byKey(const Key('lp_picked')));
    await stub(t, '/__stub/mode?feature=lpparse&value=aioff');
    await t.tap(find.byKey(const Key('lp_parse')));
    await waitFor(t, find.byKey(const Key('lp_parse_failure')));
    await settle(t, 800);
    await shot(t, '6a_31_parse_failure_manual');
    await stub(t, '/__stub/mode?feature=lpparse&value=ok');
    await t.tap(find.byKey(const Key('lp_parse')));
    await waitFor(t, find.byKey(const Key('lp_prefill_banner')));
    await settle(t, 1500);
    await shot(t, '6a_32_parse_prefill_review');
    await scroll(t, 600);
    await shot(t, '6a_33_parse_prefill_fields');
    await t.pageBack();
    await waitFor(t, find.byKey(const Key('confirm_dialog_confirm')));
    await shot(t, '6a_34_discard_prefill_confirm', ms: 400);
    await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
    await waitFor(t, find.byKey(const Key('lp_new_fab')));
    await settle(t, 800);

    // ── Syllabus: list, detail, optimistic tick and rollback ──
    await t.pageBack();
    await settle(t, 800);
    await t.tap(find.byKey(const ValueKey('module_syllabus')));
    await waitFor(t, find.byKey(const Key('syl_planner_card')));
    await waitFor(t, find.text('BEHIND SCHEDULE'));
    await settle(t, 1200);
    await shot(t, '6a_40_syllabus_list');
    await t.tap(find.text('Mathematics').first);
    await waitFor(t, find.byKey(const Key('syl_overall_bar')));
    await settle(t, 1000);
    await shot(t, '6a_41_syllabus_detail_progress');
    await t.tap(find.text('1. Adding fractions'));
    await settle(t, 800);
    await stub(t, '/__stub/mode?feature=sylmark&value=slow');
    await t.tap(find.byKey(const ValueKey('tick_sub_1_1_3')));
    await settle(t, 500);
    await shot(t, '6a_42_mark_topic_optimistic', ms: 300);
    await settle(t, 6500);
    await stub(t, '/__stub/mode?feature=sylmark&value=403');
    await t.tap(find.byKey(const ValueKey('tick_sub_1_1_1')));
    await settle(t, 1200);
    await shot(t, '6a_43_mark_rolled_back_403', ms: 300);
    await stub(t, '/__stub/mode?feature=sylmark&value=ok');
    await settle(t, 3500);
    await scroll(t, 500);
    await shot(t, '6a_44_syllabus_detail_lessons_units');

    // ── Weekly planner ──
    await t.pageBack();
    await waitFor(t, find.byKey(const Key('syl_planner_card')));
    await t.tap(find.byKey(const Key('syl_planner_card')));
    await waitFor(t, find.byKey(const Key('planner_label')));
    await settle(t, 1500);
    await shot(t, '6a_50_weekly_planner_this_week');
    await t.tap(find.byKey(const Key('planner_next')));
    await settle(t, 800);
    await shot(t, '6a_51_weekly_planner_next_week');
    await t.pageBack();
    await waitFor(t, find.byKey(const Key('syl_planner_card')));

    // ── 403 states ──
    await stub(t, '/__stub/mode?feature=syllabus&value=403');
    await t.drag(page, const Offset(0, 500));
    await waitFor(t, find.byKey(const Key('screen_forbidden')));
    await settle(t, 800);
    await shot(t, '6a_91_syllabus_403');
    await stub(t, '/__stub/mode?feature=syllabus&value=ok');
    await t.pageBack();
    await settle(t, 800);
    await stub(t, '/__stub/mode?feature=lessonplans&value=403');
    await t.tap(find.byKey(const ValueKey('module_lesson_plans')));
    await waitFor(t, find.byKey(const Key('screen_forbidden')));
    await settle(t, 800);
    await shot(t, '6a_90_lesson_plans_403');
    await stub(t, '/__stub/mode?feature=lessonplans&value=ok');
  });
}
