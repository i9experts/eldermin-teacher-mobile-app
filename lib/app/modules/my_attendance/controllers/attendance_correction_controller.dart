import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../../core/models/attendance/self_attendance_models.dart';
import '../../../../core/models/json_helpers.dart';
import '../../../../core/services/self_attendance_repository.dart';
import '../../../../core/utils/self_attendance_rules.dart';
import '../../../common/action_failure.dart';
import 'my_attendance_controller.dart';

sealed class CorrectionResult {
  const CorrectionResult();
}

class CorrectionDone extends CorrectionResult {
  final AttendanceCorrectionRequest request;
  const CorrectionDone(this.request);
}

class CorrectionInvalid extends CorrectionResult {
  final Map<String, String> errors;
  const CorrectionInvalid(this.errors);
}

class CorrectionFailed extends CorrectionResult {
  final ActionFailure failure;
  final String text;

  /// The login has no Staff record: the form cannot work at all (shown as its own state).
  final bool noStaffRecord;
  const CorrectionFailed(this.failure, this.text, {this.noStaffRecord = false});
}

class CorrectionIgnored extends CorrectionResult {
  const CorrectionIgnored();
}

/// Request an attendance correction (`/my-attendance/correct`): `POST /hr/attendance/self/correction-requests {attendanceDate, requestedStatus,
/// requestedCheckInTime?, requestedCheckOutTime?, reason}` (self-attendance-correction.dto.ts). The server never applies it: an admin reviews it.
/// Validation: a date that is not in the future, one of the eight requestable statuses, reason 10..2000 characters.
/// Double submit: `saving` blocks a second request while one is in flight AND after success (the screen leaves).
class AttendanceCorrectionController extends GetxController {
  final SelfAttendanceRepository? _repo;
  final MyAttendanceController? _list;
  final DateTime? _initialDate;
  final DateTime Function() _clock;
  AttendanceCorrectionController({SelfAttendanceRepository? repository, MyAttendanceController? list, DateTime? initialDate, DateTime Function()? clock})
      : _repo = repository,
        _list = list,
        _initialDate = initialDate,
        _clock = clock ?? DateTime.now;

  SelfAttendanceRepository get repo => _repo ?? Get.find<SelfAttendanceRepository>();
  MyAttendanceController? get list => _list ?? (Get.isRegistered<MyAttendanceController>() ? Get.find<MyAttendanceController>() : null);

  final date = Rxn<DateTime>();
  final status = Rxn<StaffDayStatus>();
  final checkIn = RxnString();
  final checkOut = RxnString();
  final reasonC = TextEditingController();
  final reasonLength = 0.obs;
  final errors = <String, String>{}.obs;
  final saving = false.obs;
  final failure = Rxn<ActionFailure>();
  final failureText = RxnString();
  final noStaffRecord = false.obs;
  bool _done = false;

  DateTime get today {
    final n = _clock();
    return DateTime(n.year, n.month, n.day);
  }

  /// The statuses the picker offers: exactly the eight the server accepts.
  List<StaffDayStatus> get statusOptions => StaffDayStatus.requestableValues;

  @override
  void onInit() {
    super.onInit();
    final d = _initialDate ?? _fromArguments(Get.arguments);
    if (d != null) setDate(d);
    reasonC.addListener(() => reasonLength.value = reasonC.text.trim().length);
  }

  @override
  void onClose() {
    reasonC.dispose();
    super.onClose();
  }

  static DateTime? _fromArguments(Object? a) {
    final v = a is Map ? a['date'] : a;
    if (v is DateTime) return DateTime(v.year, v.month, v.day);
    if (v is String) {
      final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(v);
      if (m != null) return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
    }
    return null;
  }

  void setDate(DateTime d) {
    date.value = DateTime(d.year, d.month, d.day);
    errors.remove('date');
  }

  void setStatus(StaffDayStatus s) {
    status.value = s;
    errors.remove('status');
  }

  void setCheckIn(String? hm) => checkIn.value = hm;
  void setCheckOut(String? hm) => checkOut.value = hm;

  bool get isDirty => status.value != null || checkIn.value != null || checkOut.value != null || reasonC.text.trim().isNotEmpty;

  Map<String, String> validate() => validateCorrection(date: date.value, status: status.value, reason: reasonC.text, today: today);

  Future<CorrectionResult> submit() async {
    if (saving.value || _done) return const CorrectionIgnored();
    final problems = validate();
    errors.assignAll(problems);
    if (problems.isNotEmpty) return CorrectionInvalid(problems);
    saving.value = true;
    failure.value = null;
    failureText.value = null;
    try {
      final r = await repo.submitCorrection(AttendanceCorrectionBody(
        date: date.value!,
        status: status.value!,
        checkIn: checkIn.value,
        checkOut: checkOut.value,
        reason: reasonC.text,
      ));
      _done = true;
      list?.submitted(r);
      return CorrectionDone(r);
    } on NoStaffRecord {
      noStaffRecord.value = true;
      const f = ActionFailure(ActionFailureKind.notFound, kNoStaffRecordMessage, serverMessage: kNoStaffRecordMessage);
      failure.value = f;
      failureText.value = kNoStaffRecordMessage;
      return const CorrectionFailed(f, kNoStaffRecordMessage, noStaffRecord: true);
    } catch (e) {
      final f = ActionFailure.from(e, what: 'send this correction request');
      failure.value = f;
      failureText.value = f.serverMessage.isNotEmpty ? f.serverMessage : f.message;
      return CorrectionFailed(f, failureText.value!);
    } finally {
      saving.value = false;
    }
  }

  /// The wire date shown in tests / logs.
  String? get wireDate => date.value == null ? null : wireDay(date.value!);
}
