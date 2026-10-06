import 'package:get/get.dart';
import '../../../../core/models/academic/syllabus_models.dart';
import '../../../../core/services/syllabus_repository.dart';
import '../../../../core/utils/home_time.dart';
import '../../../../core/utils/timetable_week.dart' show dateOnly;
import '../../auth/controllers/auth_controller.dart';
import '../../home/models/section_state.dart';
import 'syllabus_controller.dart';

/// One row of the planner: a sub-topic planned for the shown week.
typedef PlannerRow = ({SyllabusUnit? unit, SyllabusTopic? topic, SyllabusSubTopic sub});

/// What the planner shows for one syllabus at the chosen week.
class PlannerCard {
  final PlannerEntry entry;
  final Syllabus? syllabus;

  /// The term week shown for this syllabus (`entry.currentWeek + offset`).
  final int week;
  final List<PlannerRow> rows;

  /// Sub-topics planned for EARLIER weeks and still not covered (only on "this week").
  final List<PlannerRow> earlier;
  const PlannerCard({required this.entry, required this.syllabus, required this.week, required this.rows, required this.earlier});
}

/// Weekly planner (`/syllabus/weekly-planner`): `GET /syllabus/weekly-planner?teacherId=<my id>` answers ONLY the CURRENT term week of each
/// syllabus (syllabus.service.ts:301-332: no date / week parameter, status active|approved, a syllabus whose academic-year term is unknown is
/// skipped). Week navigation therefore works on the syllabus documents we already have: week = the server's `currentWeek` + offset, and the
/// rows are the sub-topics whose `plannedWeek` equals it. The server tells no calendar dates for a week (the term start is not exposed), so
/// only "Week N" is shown, never a date range. The anchor is as of the time of the request: when the calendar day changes the planner reloads
/// (`refreshIfStale`, injectable [clock]).
class WeeklyPlannerController extends GetxController {
  final SyllabusRepository? _repo;
  final SyllabusController? _syllabi;
  final AuthController? _auth;
  final Clock clock;

  WeeklyPlannerController({SyllabusRepository? repository, SyllabusController? syllabi, AuthController? auth, Clock? clock})
      : _repo = repository,
        _syllabi = syllabi,
        _auth = auth,
        clock = clock ?? DateTime.now;

  SyllabusRepository get repo => _repo ?? Get.find<SyllabusRepository>();
  SyllabusController get syllabi => _syllabi ?? Get.find<SyllabusController>();
  AuthController get auth => _auth ?? Get.find<AuthController>();

  final state = Rx<SectionState<List<PlannerEntry>>>(const SectionState.loading());

  /// Weeks from "this week" (0), negative = earlier.
  final offset = 0.obs;
  DateTime? _fetchedDay;
  int _token = 0;

  /// The calendar day the anchor (`currentWeek`) was fetched on.
  DateTime? get fetchedDay => _fetchedDay;

  @override
  void onReady() {
    super.onReady();
    load();
  }

  Future<void> load({bool force = false}) async {
    if (!syllabi.canView) {
      state.value = const SectionState.forbidden();
      return;
    }
    final ids = syllabi.myIds;
    if (ids.isEmpty) {
      state.value = const SectionState.error("Your teacher profile isn't loaded yet. Pull down to refresh.");
      return;
    }
    if (!force && state.value.hasData) return;
    final token = ++_token;
    if (!state.value.hasData) state.value = const SectionState.loading();
    try {
      await syllabi.ensureLoaded();
      final list = await repo.weeklyPlanner(ids);
      if (token != _token) return;
      _fetchedDay = dateOnly(clock());
      offset.value = 0;
      state.value = list.isEmpty ? const SectionState.empty() : SectionState.data(list);
    } catch (e) {
      if (token != _token) return;
      state.value = SectionState<List<PlannerEntry>>.fromError(e);
    }
  }

  Future<void> reload() async {
    await auth.refreshProfile(force: true);
    await syllabi.load(force: true);
    await load(force: true);
  }

  /// A new calendar day may have started a new term week: re-anchor.
  Future<void> refreshIfStale() async {
    final day = _fetchedDay;
    if (day == null || day == dateOnly(clock())) return;
    await load(force: true);
  }

  List<PlannerEntry> get entries => state.value.data ?? const [];

  /// The highest week anybody can navigate to: the syllabus' own `totalWeeks` or the last planned week in its tree.
  int _lastWeek(PlannerEntry e) {
    final s = syllabi.byId(e.syllabusId);
    if (s == null) return e.currentWeek;
    var last = s.totalWeeks;
    for (final u in s.units) {
      for (final t in u.topics) {
        for (final sub in t.subTopics) {
          if ((sub.plannedWeek ?? 0) > last) last = sub.plannedWeek!;
        }
      }
    }
    return last < e.currentWeek ? e.currentWeek : last;
  }

  bool get canGoEarlier => entries.any((e) => e.currentWeek + offset.value - 1 >= 1);
  bool get canGoLater => entries.any((e) => e.currentWeek + offset.value + 1 <= _lastWeek(e));

  void earlier() {
    if (canGoEarlier) offset.value -= 1;
  }

  void later() {
    if (canGoLater) offset.value += 1;
  }

  void thisWeek() => offset.value = 0;

  String get weekLabel {
    final o = offset.value;
    if (o == 0) return 'This week';
    if (o == 1) return 'Next week';
    if (o == -1) return 'Last week';
    return o > 0 ? 'In $o weeks' : '${-o} weeks ago';
  }

  /// Cards for the shown week. A syllabus whose week would be before week 1 is left out. Rows come from the syllabus document (so ticks
  /// made here or in the detail screen show at once) and fall back to what the planner answered for "this week".
  List<PlannerCard> get cards {
    final o = offset.value;
    final out = <PlannerCard>[];
    for (final e in entries) {
      final week = e.currentWeek + o;
      if (week < 1) continue;
      final s = syllabi.byId(e.syllabusId);
      List<PlannerRow> rows;
      var earlier = <PlannerRow>[];
      if (s != null) {
        rows = [for (final r in s.plannedIn(week)) (unit: r.unit, topic: r.topic, sub: r.sub)];
        if (o == 0) earlier = [for (final r in s.uncoveredBefore(week)) (unit: r.unit, topic: r.topic, sub: r.sub)];
      } else if (o == 0) {
        rows = [
          for (final i in e.items)
            (
              unit: SyllabusUnit(no: i.unitNo, name: i.unitName),
              topic: SyllabusTopic(no: i.topicNo, name: i.topicName),
              sub: SyllabusSubTopic(no: i.subTopicNo, name: i.subTopicName, isCovered: i.isCovered, plannedWeek: week),
            )
        ];
      } else {
        rows = const [];
      }
      out.add(PlannerCard(entry: e, syllabus: s, week: week, rows: rows, earlier: earlier));
    }
    return out;
  }
}
