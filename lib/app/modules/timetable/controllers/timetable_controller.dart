import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/services/home_repository.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/utils/home_time.dart';
import '../../../../core/utils/timetable_week.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/models/section_state.dart';

enum TimetableMode { day, week }

/// "My timetable" (read-only): a day view and a week view (Sunday..Saturday) of
/// MY periods from `GET /staff-portal/timetable?date|from&to` via
/// [HomeRepository.getMyTimetable] (max 14 days; one request covers a week).
///
/// * A/B weeks are never guessed (U1): periods keep their own `both|A|B` tag; A and B
///   variants of one slot are listed side by side and tagged.
/// * 404 (endpoint not deployed) falls back to the OLD whole-class endpoint filtered
///   client-side, exactly like Home. 403/5xx never fall back.
/// * Dates are the device-local calendar dates; the clock is injectable and the NOW/NEXT
///   highlight is computed only for today's date.
class TimetableController extends GetxController with WidgetsBindingObserver {
  final HomeRepository? _repo;
  final AuthController? _auth;
  final PermissionService? _perms;
  final Clock clock;

  /// How often "now" advances (null = no ticker; [TimetableBinding] enables it for the app).
  final Duration? tick;

  TimetableController({
    HomeRepository? repository,
    AuthController? auth,
    PermissionService? permissions,
    Clock? clock,
    this.tick,
  })  : _repo = repository,
        _auth = auth,
        _perms = permissions,
        clock = clock ?? DateTime.now,
        now = Rx<DateTime>((clock ?? DateTime.now)()),
        selectedDate = Rx<DateTime>(dateOnly((clock ?? DateTime.now)()));

  HomeRepository get repo => _repo ?? Get.find<HomeRepository>();
  AuthController get auth => _auth ?? Get.find<AuthController>();
  PermissionService get perms => _perms ?? Get.find<PermissionService>();

  /// Eagerly initialised (a lazy `late` would first read the clock AFTER it had moved on).
  final Rx<DateTime> now;
  final Rx<DateTime> selectedDate;
  final mode = TimetableMode.day.obs;

  /// State of the week that contains [selectedDate]; data = every period of that week.
  final week = Rx<SectionState<List<TeacherPeriod>>>(const SectionState.loading());

  Timer? _ticker;
  int _token = 0;
  String _loadedWeekKey = '';
  bool _followToday = true;

  // ── derived ──────────────────────────────────────────────────
  DateTime get today => dateOnly(now.value);
  DateTime get weekStart => weekStartOf(selectedDate.value);
  List<DateTime> get weekDays => weekDaysFrom(weekStart);
  bool get isTodaySelected => sameDate(selectedDate.value, today);

  /// Touching `auth.staffMe` makes Obx re-evaluate when permissions are rebuilt.
  bool get canView {
    auth.staffMe.value;
    return perms.canAccess('teaching:view');
  }

  List<TodayPeriod> dayPeriods(DateTime date) {
    final s = week.value;
    if (!s.hasData) return const [];
    return periodsForDate(s.data!, date, now.value);
  }

  bool get showsWeekTags => week.value.hasData && hasWeekTags(week.value.data!);

  // ── lifecycle ────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onReady() {
    super.onReady();
    if (tick != null) _ticker = Timer.periodic(tick!, (_) => advanceClock());
    load();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) advanceClock();
  }

  /// Re-reads the clock. When the date changes and the user was looking at "today",
  /// the view follows to the new today (and loads that week if it differs).
  void advanceClock() {
    final before = today;
    now.value = clock();
    if (!sameDate(before, today) && _followToday) {
      selectedDate.value = today;
      load();
    }
  }

  // ── actions ──────────────────────────────────────────────────
  void setMode(TimetableMode m) => mode.value = m;

  void selectDate(DateTime d) {
    selectedDate.value = dateOnly(d);
    _followToday = isTodaySelected;
    load();
  }

  void nextWeek() => selectDate(addDays(selectedDate.value, 7));
  void previousWeek() => selectDate(addDays(selectedDate.value, -7));
  void goToToday() => selectDate(today);

  Future<void> refreshWeek() => load(force: true);

  Future<void> load({bool force = false}) async {
    if (!canView) {
      week.value = const SectionState.forbidden();
      return;
    }
    final start = weekStart;
    final key = dateKeyOf(start);
    if (!force && key == _loadedWeekKey && week.value.status != SectionStatus.error) return;
    final token = ++_token;
    _loadedWeekKey = key;
    if (!week.value.hasData || force == false) week.value = SectionState.loading(previous: week.value.data);
    try {
      final periods = await _fetchWeek(start);
      if (token != _token) return;
      week.value = periods.isEmpty ? const SectionState.empty() : SectionState.data(periods);
    } catch (e) {
      if (token != _token) return;
      _loadedWeekKey = ''; // retry must reload
      week.value = SectionState<List<TeacherPeriod>>.fromError(e);
    }
  }

  Future<List<TeacherPeriod>> _fetchWeek(DateTime start) async {
    try {
      return teacherPeriodsFromTimetable(await repo.getMyTimetable(start, addDays(start, 6)));
    } on ApiException catch (e) {
      if (e.statusCode != 404) rethrow; // endpoint not deployed -> old path only on 404
    }
    final id = auth.staffId;
    if (id == null || id.isEmpty) throw ApiException('Your teacher profile could not be loaded. Pull to refresh.');
    return teacherPeriodsOf(await repo.fetchTeacherTimetable(id), id);
  }
}
