// ignore_for_file: invalid_use_of_protected_member
import 'package:eldermin_teacher_app/app/modules/leave/controllers/leave_controller.dart';
import 'package:eldermin_teacher_app/app/modules/leave/views/leave_detail_sheet.dart';
import 'package:eldermin_teacher_app/app/modules/leave/views/leave_screen.dart';
import 'package:eldermin_teacher_app/core/models/leave/leave_models.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:eldermin_teacher_app/core/widgets/detail_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/fake_phase7b_repositories.dart';

StaffLeaveRequest _req({String status = 'rejected'}) => StaffLeaveRequest.fromJson({
      '_id': 'r1',
      'leaveNo': 'LV-2026-0007',
      'leaveType': 'casual',
      'fromDate': '2026-10-05T00:00:00.000Z',
      'toDate': '2026-10-07T00:00:00.000Z',
      'totalDays': 3,
      'isHalfDay': false,
      'reason': 'Personal errand at the bank and a family matter that cannot be moved to another week',
      'status': status,
      if (status != 'pending') 'approverName': 'Hina HR',
      if (status == 'rejected') 'rejectionReason': 'Exam week, please apply for another date.',
      if (status == 'approved') 'approverNote': 'Enjoy',
      if (status != 'pending') 'approvedAt': '2026-10-02T09:00:00.000Z',
      'createdAt': '2026-10-01T06:00:00.000Z',
      // the server also sends the approver's profile and e-mail: it must never reach the screen
      'approvedBy': {'name': 'Hina', 'email': 'hina.hr@school.example'},
    });

String? _value(DetailSheetData d, String label) => [...d.fields, for (final s in d.sections) ...s.fields].where((f) => f.label == label).firstOrNull?.value;

void main() {
  late FakeLeaveRepository lv;
  setUp(() {
    Get.reset();
    Get.testMode = true;
    lv = FakeLeaveRepository();
  });
  tearDown(Get.reset);

  group('leaveSheetData', () {
    test('a rejected request: dates, number, applied on, reason and the decision', () {
      final d = leaveSheetData(_req());
      expect(d.title, 'Casual leave');
      expect(d.statusLabel, 'Rejected');
      expect(_value(d, 'Dates'), 'Mon 5 Oct - Wed 7 Oct 2026 (3 days)');
      expect(_value(d, 'Request no.'), 'LV-2026-0007');
      expect(_value(d, 'Applied on'), '1 Oct 2026');
      expect(d.longText, startsWith('Personal errand'));
      expect(_value(d, 'Decided by'), 'Hina HR');
      expect(_value(d, 'Decided on'), '2 Oct 2026');
      expect(_value(d, 'Reason given'), 'Exam week, please apply for another date.');
    });
    test('an approved request shows its note; a pending one has no decision section', () {
      expect(_value(leaveSheetData(_req(status: 'approved')), 'Note'), 'Enjoy');
      expect(leaveSheetData(_req(status: 'pending')).sections, isEmpty);
    });
    test('the approver\'s e-mail is never part of the sheet', () {
      final d = leaveSheetData(_req());
      final all = [d.title, d.longText, ...d.fields.map((f) => f.value), for (final s in d.sections) ...s.fields.map((f) => f.value)].join(' ');
      expect(all, isNot(contains('@')));
    });
    test('half day shows the session', () {
      final l = StaffLeaveRequest.fromJson({'_id': 'h', 'leaveType': 'sick', 'fromDate': '2026-10-05T00:00:00.000Z', 'toDate': '2026-10-05T00:00:00.000Z', 'isHalfDay': true, 'halfDaySession': 'morning', 'status': 'pending'});
      expect(_value(leaveSheetData(l), 'Half day'), 'Morning');
    });
  });

  testWidgets('tapping a request row opens its detail sheet; the sheet holds the full reason', (t) async {
    lv.history = () async => [_req(), leaveRow('p', status: 'pending', from: '2026-11-02', to: '2026-11-04', days: 3)];
    final c = Get.put(LeaveController(repository: lv));
    await t.binding.setSurfaceSize(const Size(430, 1600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: const LeaveScreen()));
    await t.runAsync(() => c.reload());
    await t.pump();
    await t.pump(const Duration(milliseconds: 350));

    expect(find.byKey(const Key('detail_sheet')), findsNothing);
    await t.tap(find.byKey(const ValueKey('leave_r1')));
    await t.pumpAndSettle();
    final sheet = find.byKey(const Key('detail_sheet'));
    expect(sheet, findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('Casual leave')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('Rejected')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('LV-2026-0007')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('Decision')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.textContaining('hina.hr@')), findsNothing);
    expect(find.byKey(const Key('detail_sheet_footer')), findsNothing); // read-only

    t.state<NavigatorState>(find.byType(Navigator).first).pop();
    await t.pumpAndSettle();
    expect(sheet, findsNothing);
    await t.tap(find.byKey(const ValueKey('leave_p')));
    await t.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('detail_sheet')), matching: find.text('Annual leave')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('detail_sheet')), matching: find.text('Decision')), findsNothing);
  });
}
