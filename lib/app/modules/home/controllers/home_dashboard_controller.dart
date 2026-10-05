import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../../core/models/home/class_snapshot.dart';
import '../../../../core/models/home/messaging.dart';
import '../../../../core/models/home/summaries.dart';
import '../../../../core/models/home/teaching.dart';
import '../../../../core/services/home_repository.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/utils/home_time.dart';
import '../../auth/controllers/auth_controller.dart';
import '../models/section_state.dart';
import 'home_badges_controller.dart';

/// Home dashboard. Every section has its OWN [SectionState]: one failing
/// request never affects another section. Sections the user lacks permission
/// for are not loaded and not shown.
class HomeDashboardController extends GetxController with WidgetsBindingObserver {
  final HomeRepository? _repo;
  final AuthController? _auth;
  final PermissionService? _perms;
  final HomeBadgesController? _badges;
  final Clock clock;

  /// How often the "now" used for current/next highlighting advances (null = no ticker, for tests).
  final Duration? tick;

  HomeDashboardController({
    HomeRepository? repository,
    AuthController? auth,
    PermissionService? permissions,
    HomeBadgesController? badges,
    Clock? clock,
    this.tick = const Duration(seconds: 30),
  })  : _repo = repository,
        _auth = auth,
        _perms = permissions,
        _badges = badges,
        clock = clock ?? DateTime.now;

  HomeRepository get repo => _repo ?? Get.find<HomeRepository>();
  AuthController get auth => _auth ?? Get.find<AuthController>();
  PermissionService get perms => _perms ?? Get.find<PermissionService>();
  HomeBadgesController get badges => _badges ?? Get.find<HomeBadgesController>();

  late final now = Rx<DateTime>(clock());

  final timetable = Rx<SectionState<List<TeacherPeriod>>>(const SectionState.loading());
  final classCard = Rx<SectionState<ClassAttendanceSnapshot>>(const SectionState.loading());
  final homework = Rx<SectionState<HomeworkToGrade>>(const SectionState.loading());
  final lessonPlans = Rx<SectionState<LessonPlanSummary>>(const SectionState.loading());
  final ptms = Rx<SectionState<List<PtmMeeting>>>(const SectionState.loading());
  final substitutions = Rx<SectionState<SubstitutionsToday>>(const SectionState.loading());

  /// Messages summary lives in [HomeBadgesController] (shared with the tab badge).
  Rx<SectionState<ThreadsResult>> get messages => badges.threads;

  Timer? _ticker;
  Worker? _profileWorker;
  String _dateKey = '';
  final _tokens = <Object, int>{};

  // ── Visibility (permissions) ─────────────────────────────────
  String? get staffId {
    final id = auth.staffId;
    return (id == null || id.isEmpty) ? null : id;
  }

  bool get canTeaching => perms.canAccess('teaching:view');
  bool get showTimetable => canTeaching;
  bool get showHomework => canTeaching;
  bool get showLessonPlans => canTeaching;
  bool get showPtms => canTeaching;
  bool get showSubstitutions => canTeaching;
  bool get showClassCard => auth.isClassTeacher && perms.canAccess('students:view');

  // ── Lifecycle ────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _dateKey = dateKeyOf(now.value);
  }

  @override
  void onReady() {
    super.onReady();
    if (tick != null) _ticker = Timer.periodic(tick!, (_) => _advanceClock());
    _profileWorker = ever(auth.staffMe, (_) => _onProfileChanged());
    loadAll();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _profileWorker?.dispose();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _advanceClock();
  }

  String? _lastStaffId;
  bool? _lastClassTeacher;

  void _onProfileChanged() {
    final id = staffId, ct = auth.isClassTeacher;
    if (id != _lastStaffId) {
      _lastStaffId = id;
      _lastClassTeacher = ct;
      if (id != null) loadAll();
    } else if (ct != _lastClassTeacher) {
      _lastClassTeacher = ct;
      loadClassCard();
    }
  }

  /// Advances "now"; at midnight rollover the day-bound sections reload.
  void _advanceClock() {
    final n = clock();
    now.value = n;
    final key = dateKeyOf(n);
    if (key != _dateKey) {
      _dateKey = key;
      loadClassCard();
      loadSubstitutions();
      loadPtms();
    }
  }

  /// Test hook / manual: re-reads the clock.
  void advanceClock() => _advanceClock();

  // ── Loading ──────────────────────────────────────────────────
  /// Pull-to-refresh: refresh the profile first (class-teacher changes), then everything.
  Future<void> refreshAll() async {
    await auth.refreshProfile(force: true);
    await loadAll(userInitiated: true);
  }

  Future<void> loadAll({bool userInitiated = false}) async {
    _lastStaffId = staffId;
    _lastClassTeacher = auth.isClassTeacher;
    _dateKey = dateKeyOf(clock());
    now.value = clock();
    await Future.wait([
      loadTimetable(),
      loadClassCard(),
      loadHomework(),
      loadLessonPlans(),
      loadPtms(),
      loadSubstitutions(),
      // The badges controller refreshes itself on start and every 60 s.
      if (userInitiated) badges.refreshAll(userInitiated: true),
    ]);
  }

  Future<void> _load<T>(
    Rx<SectionState<T>> rx,
    Future<T> Function() fetch, {
    bool Function(T)? isEmpty,
  }) async {
    final token = (_tokens[rx] ?? 0) + 1;
    _tokens[rx] = token;
    final prev = rx.value;
    if (!prev.hasData) rx.value = const SectionState.loading();
    try {
      final r = await fetch();
      if (_tokens[rx] != token) return;
      rx.value = (isEmpty != null && isEmpty(r)) ? const SectionState.empty() : SectionState.data(r);
    } catch (e) {
      if (_tokens[rx] != token) return;
      rx.value = SectionState<T>.fromError(e);
    }
  }

  Future<void> loadTimetable() async {
    final id = staffId;
    if (!showTimetable || id == null) return;
    await _load<List<TeacherPeriod>>(
      timetable,
      () async => teacherPeriodsOf(await repo.fetchTeacherTimetable(id), id),
    );
  }

  Future<void> loadClassCard() async {
    if (!showClassCard) return;
    final info = auth.staffMe.value?.teacherProfile?.classTeacherOf;
    final grade = info?.gradeName;
    if (info == null || grade == null || grade.isEmpty) {
      classCard.value = const SectionState.error('Your class details are missing. Pull to refresh.');
      return;
    }
    final section = info.sectionName ?? '';
    await _load<ClassAttendanceSnapshot>(classCard, () async {
      final range = todayRangeUtc(clock());
      final roster = await repo.fetchRoster(grade: grade, section: section);
      final marked =
          await repo.fetchAttendanceCount(grade: grade, section: section, from: range.from, to: range.to);
      return ClassAttendanceSnapshot(
        label: info.displayName,
        grade: grade,
        section: section,
        rosterSize: roster.activeCount,
        markedCount: marked,
      );
    });
  }

  Future<void> loadHomework() async {
    final id = staffId;
    if (!showHomework || id == null) return;
    await _load<HomeworkToGrade>(
      homework,
      () async {
        final all = await repo.fetchAssignments(id);
        final sel = selectGradingCandidates(all, id);
        final lookups = await Future.wait(sel.picked.map((a) async {
          try {
            final subs = await repo.fetchSubmissions(a.id);
            return GradingItem(a, subs.where((s) => s.isUngraded).length);
          } catch (_) {
            return null;
          }
        }));
        final ok = lookups.whereType<GradingItem>().toList();
        final failed = lookups.length - ok.length;
        if (sel.picked.isNotEmpty && ok.isEmpty) {
          throw StateError('all submission look-ups failed');
        }
        final items = ok.where((i) => i.ungraded > 0).toList();
        return HomeworkToGrade(
          items: items,
          totalUngraded: items.fold(0, (a, i) => a + i.ungraded),
          assignmentsChecked: sel.picked.length,
          capped: sel.candidates > sel.picked.length,
          failedLookups: failed,
        );
      },
      isEmpty: (h) => h.totalUngraded == 0 && h.failedLookups == 0,
    );
  }

  Future<void> loadLessonPlans() async {
    final id = staffId;
    if (!showLessonPlans || id == null) return;
    await _load<LessonPlanSummary>(
      lessonPlans,
      () async {
        final r = await Future.wait([
          repo.fetchLessonPlans(id, 'submitted'),
          repo.fetchLessonPlans(id, 'rejected'),
        ]);
        return LessonPlanSummary(
          submitted: r[0].where((p) => p.teacherId == id && p.status == 'submitted').toList(),
          rejected: r[1].where((p) => p.teacherId == id && p.status == 'rejected').toList(),
        );
      },
      isEmpty: (s) => s.isEmpty,
    );
  }

  Future<void> loadPtms() async {
    final id = staffId;
    if (!showPtms || id == null) return;
    await _load<List<PtmMeeting>>(
      ptms,
      () async => (await repo.fetchUpcomingPtms(id)).where((m) => m.teacherId == id).toList(),
      isEmpty: (l) => l.isEmpty,
    );
  }

  Future<void> loadSubstitutions() async {
    final id = staffId;
    if (!showSubstitutions || id == null) return;
    await _load<SubstitutionsToday>(
      substitutions,
      () async {
        final range = todayRangeUtc(clock());
        return splitSubstitutions(await repo.fetchSubstitutions(id, from: range.from, to: range.to), id);
      },
      isEmpty: (s) => s.isEmpty,
    );
  }

  // ── Derived ──────────────────────────────────────────────────
  /// Today's periods annotated at [now] (recomputed on every tick / rollover).
  List<TodayPeriod> get todayTimetable {
    final all = timetable.value.data;
    if (all == null) return const [];
    return todayPeriods(all, now.value);
  }
}
