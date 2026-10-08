import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../../core/models/leave/leave_models.dart';
import '../../../../core/services/leave_repository.dart';
import '../../../../core/utils/leave_rules.dart';
import '../../../common/action_failure.dart';
import 'leave_controller.dart';

sealed class ApplyResult {
  const ApplyResult();
}

class ApplyDone extends ApplyResult {
  final StaffLeaveRequest request;
  const ApplyDone(this.request);
}

class ApplyInvalid extends ApplyResult {
  final Map<String, String> errors;
  const ApplyInvalid(this.errors);
}

class ApplyFailed extends ApplyResult {
  final ActionFailure failure;
  final String text;
  const ApplyFailed(this.failure, this.text);
}

class ApplyIgnored extends ApplyResult {
  const ApplyIgnored();
}

/// Apply for leave (`/leave/apply`): `POST /hr/leave/self {leaveType, fromDate, toDate, reason, isHalfDay, halfDaySession?}` (hr.controller.ts:
/// 249-253 -> hr.service.ts:1441-1455). The server counts the days itself; the form only HINTS (calendar span, balance, overlap) and never
/// blocks on them. Validation: type, both dates, end >= start, half day = one day, reason 10..500 characters.
/// Double submit: `saving` blocks a second request while one is in flight AND after success (the screen leaves).
class LeaveApplyController extends GetxController {
  final LeaveRepository? _repo;
  final LeaveController? _list;
  LeaveApplyController({LeaveRepository? repository, LeaveController? list})
      : _repo = repository,
        _list = list;

  LeaveRepository get repo => _repo ?? Get.find<LeaveRepository>();
  LeaveController? get list => _list ?? (Get.isRegistered<LeaveController>() ? Get.find<LeaveController>() : null);

  final type = Rxn<StaffLeaveType>(StaffLeaveType.annual);
  final from = Rxn<DateTime>();
  final to = Rxn<DateTime>();
  final halfDay = false.obs;
  final session = 'morning'.obs;
  final reasonC = TextEditingController();
  final errors = <String, String>{}.obs;
  final saving = false.obs;
  final failure = Rxn<ActionFailure>();
  final failureText = RxnString();
  bool _done = false;

  @override
  void onClose() {
    reasonC.dispose();
    super.onClose();
  }

  void setType(StaffLeaveType t) {
    type.value = t;
    errors.remove('type');
  }

  void setFrom(DateTime d) {
    from.value = DateTime(d.year, d.month, d.day);
    errors.remove('from');
    // Keep the range valid: a later first day pushes the last day along; a half day is one day.
    if (to.value == null || halfDay.value || to.value!.isBefore(from.value!)) to.value = from.value;
    errors.remove('to');
  }

  void setTo(DateTime d) {
    to.value = DateTime(d.year, d.month, d.day);
    errors.remove('to');
  }

  void setHalfDay(bool v) {
    halfDay.value = v;
    if (v && from.value != null) to.value = from.value;
    errors.remove('to');
  }

  LeaveFormInput get input => LeaveFormInput(type: type.value, from: from.value, to: to.value, reason: reasonC.text, halfDay: halfDay.value);

  /// Hints (informational only).
  String? get balanceHint => balanceWarning(list?.balance.value.data, type.value, from.value, to.value, halfDay: halfDay.value);
  List<StaffLeaveRequest> get overlaps => from.value == null || to.value == null ? const [] : overlapping(list?.rows ?? const [], from.value!, to.value!);
  String get daysHint => spanHint(from.value, to.value, halfDay: halfDay.value);

  bool get isDirty => from.value != null || to.value != null || reasonC.text.trim().isNotEmpty || halfDay.value || type.value != StaffLeaveType.annual;

  Future<ApplyResult> submit() async {
    if (saving.value || _done) return const ApplyIgnored();
    final problems = validateLeave(input);
    errors.assignAll(problems);
    if (problems.isNotEmpty) return ApplyInvalid(problems);
    saving.value = true;
    failure.value = null;
    failureText.value = null;
    try {
      final r = await repo.apply(StaffLeaveRequestBody(
        type: type.value!,
        from: from.value!,
        to: to.value!,
        reason: reasonC.text,
        halfDay: halfDay.value,
        halfDaySession: session.value,
      ));
      _done = true;
      list?.added(r);
      return ApplyDone(r);
    } catch (e) {
      final f = ActionFailure.from(e, what: 'send this leave request');
      failure.value = f;
      failureText.value = f.serverMessage.isNotEmpty ? f.serverMessage : f.message;
      return ApplyFailed(f, failureText.value!);
    } finally {
      saving.value = false;
    }
  }
}
