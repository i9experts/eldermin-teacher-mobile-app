import 'package:get/get.dart';
import '../../../../core/models/calendar/calendar_models.dart';
import '../../../../core/services/school_calendar_repository.dart';
import '../../../../core/utils/home_time.dart' show Clock;
import '../../home/models/section_state.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
String _monthKey(DateTime d) => '${d.year}-${d.month}';

/// School calendar (`/calendar`, read only): month view + agenda over `GET /school-calendar/events` (SCS:74-161). One request per visited month
/// (grid window: month start - 7 days .. month end + 7 days, UTC y/m/d bounds); the loaded entries are merged by id. Fee rows never get here (the
/// model drops them). A day's entries are computed from the stored dates: all-day entries by their UTC calendar day (same day in every device
/// zone), timed ones by device-local day.
class CalendarController extends GetxController {
  final SchoolCalendarRepository? _repo;
  final Clock _clock;
  CalendarController({SchoolCalendarRepository? repository, Clock? clock})
      : _repo = repository,
        _clock = clock ?? DateTime.now;

  SchoolCalendarRepository get repo => _repo ?? Get.find<SchoolCalendarRepository>();

  late final focusedDay = Rx<DateTime>(_day(_clock()));
  late final selectedDay = Rx<DateTime>(_day(_clock()));
  final agenda = false.obs;
  final state = Rx<SectionState<List<CalendarEntry>>>(const SectionState.loading());

  final _all = <String, CalendarEntry>{};
  final _loaded = <String>{};
  final version = 0.obs; // bumps when _all changes (calendar markers / day list rebuild)
  int _token = 0;

  DateTime get today => _day(_clock());

  @override
  void onReady() {
    super.onReady();
    load();
  }

  /// First/last day of the request window for the month of [d]: the visible 6-week grid is covered by +-7 days.
  static ({DateTime from, DateTime to}) windowFor(DateTime d) {
    // Calendar arithmetic on y/m/d (NOT Duration: 7 x 24 h across a daylight-saving change would land on 23:00 / 01:00 and shift the day).
    return (from: DateTime(d.year, d.month, 1 - 7), to: DateTime(d.year, d.month + 1, 0 + 7));
  }

  bool get _monthLoaded => _loaded.contains(_monthKey(focusedDay.value));

  Future<void> load({bool force = false, bool userInitiated = false}) async {
    final month = focusedDay.value;
    final key = _monthKey(month);
    if (!force && _loaded.contains(key)) {
      state.value = _stateForMonth(month);
      return;
    }
    final token = ++_token;
    final keep = state.value.hasData && _monthLoaded; // refresh of the month on screen keeps its data while loading
    if (!keep) state.value = const SectionState.loading();
    final w = windowFor(month);
    try {
      final rows = await repo.fetchEvents(fromDay: w.from, toDay: w.to);
      if (token != _token) return;
      for (final e in rows) {
        _all[e.id] = e;
      }
      _loaded.add(key);
      version.value++;
      state.value = _stateForMonth(focusedDay.value);
    } catch (e) {
      if (token != _token) return;
      final failed = SectionState<List<CalendarEntry>>.fromError(e);
      state.value = keep && failed.status == SectionStatus.error && !userInitiated ? state.value : failed;
    }
  }

  SectionState<List<CalendarEntry>> _stateForMonth(DateTime m) {
    final list = entriesInMonth(m);
    return list.isEmpty ? const SectionState.empty() : SectionState.data(list);
  }

  Future<void> reload() async {
    _loaded.remove(_monthKey(focusedDay.value));
    await load(force: true, userInitiated: true);
  }

  void setFocused(DateTime d) {
    final changed = _monthKey(d) != _monthKey(focusedDay.value);
    focusedDay.value = _day(d);
    if (changed) {
      // keep the selection inside the visible month so the day list is never about a day that is not on screen
      selectedDay.value = _day(d);
      load();
    }
  }

  void selectDay(DateTime d) {
    final changed = _monthKey(d) != _monthKey(focusedDay.value);
    selectedDay.value = _day(d);
    focusedDay.value = _day(d);
    if (changed) load();
  }

  void goToToday() => selectDay(today);

  void setAgenda(bool v) => agenda.value = v;

  // ── queries (pure, over what is loaded) ─────────────────────
  List<CalendarEntry> get all => _all.values.toList();

  List<CalendarEntry> entriesOn(DateTime day) {
    version.value; // rx dependency for Obx
    final d = _day(day);
    final out = [for (final e in _all.values) if (e.coversDay(d)) e];
    out.sort((a, b) {
      if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
      final c = a.start.compareTo(b.start);
      return c != 0 ? c : a.title.compareTo(b.title);
    });
    return out;
  }

  List<CalendarEntry> entriesInMonth(DateTime m) {
    final first = DateTime(m.year, m.month, 1), last = DateTime(m.year, m.month + 1, 0);
    final out = [for (final e in _all.values) if (!e.lastDay.isBefore(first) && !e.firstDay.isAfter(last)) e];
    out.sort((a, b) {
      final c = a.firstDay.compareTo(b.firstDay);
      return c != 0 ? c : a.title.compareTo(b.title);
    });
    return out;
  }

  /// Agenda of a month: day -> entries, only days that have entries, ascending. A multi-day entry is listed on each of its days.
  Map<DateTime, List<CalendarEntry>> agendaFor(DateTime m) {
    version.value;
    final first = DateTime(m.year, m.month, 1), last = DateTime(m.year, m.month + 1, 0);
    final map = <DateTime, List<CalendarEntry>>{};
    for (final e in entriesInMonth(m)) {
      var d = e.firstDay.isBefore(first) ? first : e.firstDay;
      final end = e.lastDay.isAfter(last) ? last : e.lastDay;
      while (!d.isAfter(end)) {
        (map[d] ??= []).add(e);
        d = DateTime(d.year, d.month, d.day + 1);
      }
    }
    return Map.fromEntries(map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }
}
