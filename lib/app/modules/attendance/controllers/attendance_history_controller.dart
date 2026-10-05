import 'package:get/get.dart';
import '../../../../core/models/classroom/attendance_models.dart';
import '../../../../core/models/classroom/attendance_month.dart';
import '../../../../core/services/attendance_repository.dart';
import '../../../../core/utils/home_time.dart';
import '../../../../core/utils/timetable_week.dart';
import '../../home/models/section_state.dart';
import 'attendance_controller.dart';

/// Month calendar of the class register: per-day summary counts from
/// `GET /students/attendance/list` with a from/to window over the month, and a day detail.
/// The roster comes from [AttendanceController] (shared, loaded on demand).
class AttendanceHistoryController extends GetxController {
  final AttendanceRepository? _attendance;
  final AttendanceController? _daily;
  final Clock clock;

  AttendanceHistoryController({AttendanceRepository? attendance, AttendanceController? daily, Clock? clock})
      : _attendance = attendance,
        _daily = daily,
        clock = clock ?? DateTime.now,
        focusedMonth = Rx<DateTime>(DateTime((clock ?? DateTime.now)().year, (clock ?? DateTime.now)().month, 1)),
        selectedDay = Rx<DateTime>(dateOnly((clock ?? DateTime.now)()));

  AttendanceRepository get attendance => _attendance ?? Get.find<AttendanceRepository>();
  AttendanceController get daily => _daily ?? Get.find<AttendanceController>();

  /// First day of the month on screen.
  final Rx<DateTime> focusedMonth;
  final Rx<DateTime> selectedDay;
  final month = Rx<SectionState<MonthAttendance>>(const SectionState.loading());

  int _token = 0;

  DateTime get today => dateOnly(clock());

  bool get isCurrentMonth => focusedMonth.value.year == today.year && focusedMonth.value.month == today.month;

  DayAttendance? get selected => month.value.data?.day(ymdOf(selectedDay.value));

  bool get canEditSelected => daily.canEditDay(selectedDay.value);

  @override
  void onReady() {
    super.onReady();
    if (daily.allowed) loadMonth();
  }

  /// Moves the calendar; never past the current month.
  void focusMonth(DateTime m) {
    final target = DateTime(m.year, m.month, 1);
    final limit = DateTime(today.year, today.month, 1);
    if (target.isAfter(limit)) return;
    focusedMonth.value = target;
    loadMonth();
  }

  void selectDay(DateTime d) => selectedDay.value = dateOnly(d);

  Future<void> loadMonth({bool force = false}) async {
    final cls = daily.myClass;
    if (!daily.allowed || cls == null) return;
    final token = ++_token;
    month.value = const SectionState.loading();
    try {
      if (!daily.roster.value.hasData) {
        await daily.load();
        if (token != _token) return;
      }
      final roster = daily.roster.value;
      if (!roster.hasData) {
        // surface the roster's own state (empty / 403 / error) instead of a blank calendar
        month.value = switch (roster.status) {
          SectionStatus.empty => const SectionState.empty(),
          SectionStatus.forbidden => const SectionState.forbidden(),
          SectionStatus.unavailable => const SectionState.unavailable(),
          _ => SectionState.error(roster.message ?? 'Could not load the class.'),
        };
        return;
      }
      final first = focusedMonth.value;
      final last = DateTime(first.year, first.month + 1, 0);
      final records = await attendance.fetchRange(grade: cls.grade, section: cls.section, firstDay: first, lastDay: last);
      if (token != _token) return;
      final built = MonthAttendance.build(records, {for (final s in roster.data!) s.id});
      month.value = SectionState.data(built);
    } catch (e) {
      if (token != _token) return;
      month.value = SectionState<MonthAttendance>.fromError(e);
    }
  }

  Future<void> reload() => loadMonth(force: true);
}
