import 'package:get/get.dart';
import '../../../../core/models/attendance/self_attendance_models.dart';
import '../../../../core/services/self_attendance_repository.dart';
import '../../../../core/utils/self_attendance_rules.dart';
import '../../home/models/section_state.dart';

enum MyAttendanceTab { attendance, requests }

/// My attendance (`/my-attendance`): one month of my own attendance records + my correction requests, two independent reads
/// (`GET /hr/attendance/self?month=&year=`, `GET /hr/attendance/self/correction-requests`; hr.controller.ts:321-333). The server decides "me" from the
/// login. When the login has no Staff record both answer 404 'No staff record is linked...': [noStaffRecord] then turns on and the screen shows one
/// plain explanation instead of two errors.
class MyAttendanceController extends GetxController {
  final SelfAttendanceRepository? _repo;
  final DateTime Function() _clock;
  MyAttendanceController({SelfAttendanceRepository? repository, DateTime Function()? clock})
      : _repo = repository,
        _clock = clock ?? DateTime.now;

  SelfAttendanceRepository get repo => _repo ?? Get.find<SelfAttendanceRepository>();

  late final month = Rx<DateTime>(_thisMonth);
  final tab = MyAttendanceTab.attendance.obs;
  final days = Rx<SectionState<List<StaffAttendanceDay>>>(const SectionState.loading());
  final requests = Rx<SectionState<List<AttendanceCorrectionRequest>>>(const SectionState.loading());
  final noStaffRecord = false.obs;
  int _dToken = 0, _rToken = 0;
  String? _shownKey; // the month the current [days] belong to

  DateTime get _thisMonth {
    final n = _clock();
    return DateTime(n.year, n.month);
  }

  DateTime get today {
    final n = _clock();
    return DateTime(n.year, n.month, n.day);
  }

  bool get canGoNext => month.value.isBefore(_thisMonth);

  List<StaffAttendanceDay> get rows => days.value.data ?? const [];
  MonthSummary get summary => MonthSummary.of(rows);

  @override
  void onReady() {
    super.onReady();
    reload();
  }

  Future<void> reload({bool userInitiated = false}) => Future.wait([loadDays(userInitiated: userInitiated), loadRequests(userInitiated: userInitiated)]);

  void setTab(MyAttendanceTab t) => tab.value = t;

  /// Previous month (no lower limit: the server has none).
  Future<void> previousMonth() => _goTo(DateTime(month.value.year, month.value.month - 1));

  /// Next month; never past the current month (a future month has no records).
  Future<void> nextMonth() async {
    if (!canGoNext) return;
    await _goTo(DateTime(month.value.year, month.value.month + 1));
  }

  /// Jump to [m] (clamped to the current month).
  Future<void> setMonth(DateTime m) => _goTo(DateTime(m.year, m.month));

  Future<void> _goTo(DateTime m) {
    final cap = _thisMonth;
    month.value = m.isAfter(cap) ? cap : m;
    return loadDays();
  }

  Future<void> loadDays({bool userInitiated = false}) async {
    final token = ++_dToken;
    final m = month.value;
    final key = '${m.year}-${m.month}';
    // A refresh of the SAME month keeps its rows under a failed reload; another month starts from the skeleton.
    final previous = _shownKey == key ? days.value : const SectionState<List<StaffAttendanceDay>>.loading();
    if (!previous.hasData) days.value = const SectionState.loading();
    try {
      final r = await repo.fetchMonth(m.month, m.year);
      if (token != _dToken) return;
      _shownKey = key;
      noStaffRecord.value = false;
      days.value = r.isEmpty ? const SectionState.empty() : SectionState.data(r);
    } on NoStaffRecord {
      if (token != _dToken) return;
      noStaffRecord.value = true;
      _shownKey = key;
      days.value = const SectionState.empty();
    } catch (e) {
      if (token != _dToken) return;
      final failed = SectionState<List<StaffAttendanceDay>>.fromError(e, previous: previous);
      days.value = previous.hasData && failed.status == SectionStatus.error && !userInitiated ? previous : failed;
    }
  }

  Future<void> loadRequests({bool userInitiated = false}) async {
    final token = ++_rToken;
    final previous = requests.value;
    if (!previous.hasData) requests.value = const SectionState.loading();
    try {
      final r = await repo.listCorrections();
      if (token != _rToken) return;
      noStaffRecord.value = false;
      requests.value = r.isEmpty ? const SectionState.empty() : SectionState.data(r);
    } on NoStaffRecord {
      if (token != _rToken) return;
      noStaffRecord.value = true;
      requests.value = const SectionState.empty();
    } catch (e) {
      if (token != _rToken) return;
      final failed = SectionState<List<AttendanceCorrectionRequest>>.fromError(e, previous: previous);
      requests.value = previous.hasData && failed.status == SectionStatus.error && !userInitiated ? previous : failed;
    }
  }

  /// A correction was just submitted: show it at the top of Requests at once, switch to that tab, then re-read the list (the server owns it).
  void submitted(AttendanceCorrectionRequest r) {
    final rows = requests.value.data ?? const <AttendanceCorrectionRequest>[];
    requests.value = SectionState.data([r, ...rows.where((x) => x.id != r.id)]);
    tab.value = MyAttendanceTab.requests;
    loadRequests();
  }

  /// The request for [day] that is still pending, if any (a hint only: the server accepts several).
  AttendanceCorrectionRequest? pendingFor(DateTime day) {
    for (final r in requests.value.data ?? const <AttendanceCorrectionRequest>[]) {
      final d = r.day;
      if (r.status == CorrectionStatus.pending && d != null && d.year == day.year && d.month == day.month && d.day == day.day) return r;
    }
    return null;
  }
}
