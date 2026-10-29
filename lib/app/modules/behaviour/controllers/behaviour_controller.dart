import 'package:get/get.dart';
import '../../../../core/models/behaviour/behaviour_models.dart';
import '../../../../core/models/classroom/student_models.dart';
import '../../../../core/services/behaviour_repository.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/services/students_repository.dart';
import '../../../../core/utils/roster_scope.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/models/section_state.dart';

enum BehaviourScope { mine, classes }

/// Behaviour & Tarbiyah home (`/behaviour`): the behaviour records of MY classes' students and the ones I logged.
///
/// Source: `GET /behaviour/records?grade=<raw grade>&page=n&limit=50` per distinct raw grade string of my classes (the route filters by
/// an EXACT grade string; since backend B1 it also pages and filters server-side: type, severity, resolved, from, to, search), then
/// re-scoped client-side with the shared class matcher ([ClassRef.containsRecord]: a record WITHOUT a section matches by class only) so
/// records of other classes are NEVER shown. "My entries" is asked of the SERVER (`mine=true`, backend B1: by `reportedById`, else the
/// `reportedBy` name), so entries older than the first page are not missed; the client keeps [BehaviourRecord.isMine] as a second check
/// (an older server ignores `mine`). Each scope (My entries / My classes) keeps its own loaded pages, so switching back is instant.
/// Paging is explicit: [hasMore] / [loadMore], nothing is silently dropped.
class BehaviourController extends GetxController {
  final BehaviourRepository? _repo;
  final StudentsRepository? _students;
  final AuthController? _auth;
  final PermissionService? _perms;

  BehaviourController({BehaviourRepository? repository, StudentsRepository? students, AuthController? auth, PermissionService? permissions})
      : _repo = repository,
        _students = students,
        _auth = auth,
        _perms = permissions;

  BehaviourRepository get repo => _repo ?? Get.find<BehaviourRepository>();
  StudentsRepository get students => _students ?? Get.find<StudentsRepository>();
  AuthController get auth => _auth ?? Get.find<AuthController>();
  PermissionService get perms => _perms ?? Get.find<PermissionService>();

  final state = Rx<SectionState<List<BehaviourRecord>>>(const SectionState.loading());
  final scope = BehaviourScope.mine.obs;

  /// -1 = all my classes, else an index into [classes].
  final classFilter = (-1).obs;
  final query = ''.obs;
  int _token = 0;

  /// Server-side filters (type, severity, resolved, date range, search). Changing them reloads from page 1.
  final filters = Rx<RecordFilters>(RecordFilters.none);

  /// One page = this many records per raw grade string.
  static const int pageLimit = 50;
  final _nextPage = <String, int>{}; // raw grade -> next page to fetch (absent = no more)

  /// What each scope has loaded (records + the next page per raw grade); filled when the user leaves a scope, dropped on every reload.
  final _cache = <BehaviourScope, ({List<BehaviourRecord> records, Map<String, int> next})>{};

  /// Bumped when the other scope's prefetch lands, so the tab labels (read in an Obx) refresh.
  final _cacheTick = 0.obs;
  final hasMore = false.obs;
  final loadingMore = false.obs;
  final loadMoreError = RxnString();

  bool get canView {
    auth.staffMe.value;
    return perms.canAccess('behaviour:view');
  }

  /// Logging also needs `behaviour:manage` (the teacher role has it; the backend allows teachers: STAFF_WRITE_ROLES).
  bool get canLog {
    auth.staffMe.value;
    return perms.canAccess('behaviour:manage');
  }

  List<ClassRef> get classes {
    auth.staffMe.value;
    return teacherClassesOf(auth.staffMe.value?.teacherProfile);
  }

  String get myId => auth.user.value?.id ?? '';
  String get myName => auth.user.value?.name ?? '';

  List<BehaviourRecord> get all => state.value.data ?? const [];

  List<BehaviourRecord> get visible {
    final cs = classes;
    final q = query.value.trim().toLowerCase();
    final f = filters.value;
    return [
      for (final r in all)
        if ((scope.value == BehaviourScope.classes || r.isMine(userId: myId, userName: myName)) &&
            (classFilter.value < 0 || classFilter.value >= cs.length || cs[classFilter.value].containsRecord(r)) &&
            f.accepts(r) &&
            (q.isEmpty || r.studentName.toLowerCase().contains(q) || r.title.toLowerCase().contains(q)))
          r
    ];
  }

  /// Replaces filters (and reloads from page 1).
  Future<void> setFilters(RecordFilters f) async {
    filters.value = f;
    await load(force: true);
  }

  /// "Search" pressed on the keyboard: the text goes to the server too, so older pages are searched, not just the loaded ones.
  Future<void> submitSearch(String text) async {
    query.value = text;
    if (filters.value.search == text.trim()) return;
    filters.value = filters.value.copyWith(search: text.trim());
    await load(force: true);
  }

  /// "My classes" count for the tab label: the records loaded so far, with a trailing "+" while more pages exist.
  String? classesCountLabel() {
    final n = countClasses();
    if (n == null) return null;
    final more = scope.value == BehaviourScope.classes ? _nextPage.isNotEmpty : (_cache[BehaviourScope.classes]?.next.isNotEmpty ?? false);
    return more ? '$n+' : '$n';
  }

  int countMine() {
    _cacheTick.value;
    if (scope.value == BehaviourScope.mine || _cache[BehaviourScope.mine] == null) return all.where((r) => r.isMine(userId: myId, userName: myName)).length;
    return _cache[BehaviourScope.mine]!.records.where((r) => r.isMine(userId: myId, userName: myName)).length;
  }

  /// Records loaded for "My classes", or null until that scope has been opened (the server filtered "My entries" only).
  int? countClasses() {
    _cacheTick.value;
    return scope.value == BehaviourScope.classes ? all.length : _cache[BehaviourScope.classes]?.records.length;
  }

  @override
  void onReady() {
    super.onReady();
    load();
  }

  /// Switches between "My entries" and "My classes". The first time a scope is opened it is fetched (My entries with `mine=true`).
  Future<void> setScope(BehaviourScope s) async {
    if (scope.value == s) return;
    if (state.value.hasData) _cache[scope.value] = (records: [...all], next: Map.of(_nextPage));
    scope.value = s;
    final cached = _cache[s];
    if (cached != null) {
      _nextPage
        ..clear()
        ..addAll(cached.next);
      hasMore.value = _nextPage.isNotEmpty;
      loadMoreError.value = null;
      state.value = SectionState.data(cached.records);
      return;
    }
    state.value = const SectionState.loading();
    await load(force: true, keepOtherScope: true);
  }
  void setClassFilter(int i) => classFilter.value = i;

  Future<void> load({bool force = false, bool keepOtherScope = false}) async {
    if (!canView) {
      state.value = const SectionState.forbidden();
      return;
    }
    final cs = classes;
    if (cs.isEmpty) {
      state.value = const SectionState.empty();
      return;
    }
    if (!force && state.value.hasData) return;
    final token = ++_token;
    if (!keepOtherScope) _cache.clear();
    if (!state.value.hasData) state.value = const SectionState.loading();
    final mineOnly = scope.value == BehaviourScope.mine;
    try {
      GradesSections? known;
      try {
        known = await students.fetchGradesSections();
      } catch (_) {
        known = null; // optional: the class's own strings are used
      }
      final grades = <String>{for (final c in cs) ...queryVariants(c, known).grades};
      _nextPage.clear();
      final out = <BehaviourRecord>[];
      for (final g in grades) {
        final page = await repo.fetchRecordsPage(grade: g, filters: filters.value, mine: mineOnly, page: 1, limit: pageLimit);
        if (page.pages > 1) _nextPage[g] = 2;
        _merge(out, page.records, cs);
      }
      if (token != _token) return;
      _sort(out);
      hasMore.value = _nextPage.isNotEmpty;
      loadMoreError.value = null;
      // With a filter on, an empty answer is "nothing matches" (the controls must stay so it can be cleared), not "no behaviour yet".
      final filtered = filters.value.isActive || filters.value.search.isNotEmpty;
      state.value = out.isEmpty && !filtered ? const SectionState.empty() : SectionState.data(out);
      // both tab labels carry a count, so the other scope's first page is fetched right away (quietly, cached for the tab switch)
      await _prefetchOtherScope(token, cs, grades, filtered: filtered);
    } catch (e) {
      if (token != _token) return;
      state.value = SectionState<List<BehaviourRecord>>.fromError(e, previous: state.value);
    }
  }

  /// First page (per raw grade) of the scope that is NOT shown, stored in [_cache]. A failure is ignored: the tab then loads when opened.
  Future<void> _prefetchOtherScope(int token, List<ClassRef> cs, Set<String> grades, {required bool filtered}) async {
    final other = scope.value == BehaviourScope.mine ? BehaviourScope.classes : BehaviourScope.mine;
    if (_cache.containsKey(other)) return;
    try {
      final next = <String, int>{};
      final out = <BehaviourRecord>[];
      for (final g in grades) {
        final page = await repo.fetchRecordsPage(grade: g, filters: filters.value, mine: other == BehaviourScope.mine, page: 1, limit: pageLimit);
        if (page.pages > 1) next[g] = 2;
        _merge(out, page.records, cs);
      }
      if (token != _token || scope.value == other || _cache.containsKey(other)) return;
      _sort(out);
      _cache[other] = (records: out, next: next);
      _cacheTick.value++;
    } catch (_) {}
  }

  /// The next page of every grade that has one. A failure keeps what is shown and offers "Try again" ([loadMoreError]).
  Future<void> loadMore() async {
    if (loadingMore.value || _nextPage.isEmpty || !state.value.hasData) return;
    final token = _token;
    loadingMore.value = true;
    loadMoreError.value = null;
    try {
      final cs = classes;
      final out = [...all];
      for (final g in _nextPage.keys.toList()) {
        final n = _nextPage[g]!;
        final page = await repo.fetchRecordsPage(grade: g, filters: filters.value, mine: scope.value == BehaviourScope.mine, page: n, limit: pageLimit);
        if (token != _token) return;
        if (n >= page.pages) {
          _nextPage.remove(g);
        } else {
          _nextPage[g] = n + 1;
        }
        _merge(out, page.records, cs);
      }
      _sort(out);
      hasMore.value = _nextPage.isNotEmpty;
      state.value = SectionState.data(out);
    } catch (e) {
      if (token != _token) return;
      loadMoreError.value = 'Couldn\'t load more. Check your connection and try again.';
    } finally {
      loadingMore.value = false;
    }
  }

  void _merge(List<BehaviourRecord> out, List<BehaviourRecord> incoming, List<ClassRef> cs) {
    final seen = {for (final r in out) r.id};
    for (final r in incoming) {
      if (r.id.isNotEmpty && cs.any((c) => c.containsRecord(r)) && seen.add(r.id)) out.add(r);
    }
  }

  void _sort(List<BehaviourRecord> out) => out.sort((a, b) => (b.day ?? DateTime(0)).compareTo(a.day ?? DateTime(0)));

  /// An edited / resolved record replaces its old version in the list.
  void replaceRecord(BehaviourRecord r) {
    for (final k in _cache.keys.toList()) {
      final c = _cache[k]!;
      if (c.records.any((x) => x.id == r.id)) _cache[k] = (records: [for (final x in c.records) x.id == r.id ? r : x], next: c.next);
    }
    if (!all.any((x) => x.id == r.id)) return;
    state.value = SectionState.data([for (final x in all) x.id == r.id ? r : x]);
  }

  Future<void> reload() async {
    await auth.refreshProfile(force: true);
    await load(force: true);
  }

  /// A record the user just logged (so the list shows it without a re-fetch).
  void addRecord(BehaviourRecord r) {
    // a record I just logged belongs to both scopes
    for (final k in _cache.keys.toList()) {
      final c = _cache[k]!;
      _cache[k] = (records: [r, ...c.records.where((x) => x.id != r.id)], next: c.next);
    }
    final list = [r, ...all.where((x) => x.id != r.id)];
    list.sort((a, b) => (b.day ?? DateTime(0)).compareTo(a.day ?? DateTime(0)));
    state.value = SectionState.data(list);
  }
}
