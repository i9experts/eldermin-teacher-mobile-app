import 'package:get/get.dart';
import '../../../../core/models/behaviour/behaviour_models.dart';
import '../../../../core/models/classroom/student_models.dart';
import '../../../../core/services/behaviour_repository.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/services/students_repository.dart';
import '../../../../core/utils/roster_scope.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/models/section_state.dart';

/// One student's behaviour + Tarbiyah history (`/behaviour/student/:id`), read-only.
///
/// The server does not check that a student is in the teacher's class (`GET /behaviour/records?studentId=` is campus-scoped only), so the
/// app first resolves the student among MY classes' rosters and, if absent, shows "not in one of your classes" WITHOUT requesting any
/// record. Records and Tarbiyah load independently (one failing does not hide the other).
class BehaviourStudentController extends GetxController {
  final String studentId;
  final StudentSummary? initial;
  final BehaviourRepository? _repo;
  final StudentsRepository? _students;
  final AuthController? _auth;
  final PermissionService? _perms;

  BehaviourStudentController({
    required this.studentId,
    this.initial,
    BehaviourRepository? repository,
    StudentsRepository? students,
    AuthController? auth,
    PermissionService? permissions,
  })  : _repo = repository,
        _students = students,
        _auth = auth,
        _perms = permissions;

  BehaviourRepository get repo => _repo ?? Get.find<BehaviourRepository>();
  StudentsRepository get students => _students ?? Get.find<StudentsRepository>();
  AuthController get auth => _auth ?? Get.find<AuthController>();
  PermissionService get perms => _perms ?? Get.find<PermissionService>();

  final student = Rx<SectionState<StudentSummary>>(const SectionState.loading());
  final records = Rx<SectionState<List<BehaviourRecord>>>(const SectionState.loading());
  final tarbiyah = Rx<SectionState<List<TarbiyahAssessment>>>(const SectionState.loading());
  int _token = 0;

  /// Records are paged (50 per page, newest first): nothing is silently cut off.
  static const int recordsPageSize = 50;
  int _recordsPage = 1;
  final recordsHasMore = false.obs;
  final loadingMoreRecords = false.obs;
  final recordsLoadMoreError = RxnString();

  /// All-time signed points of the student from `GET /behaviour/students/:id/profile` (`pointsTotal`), null until / unless it loads.
  final pointsFromServer = Rxn<int>();

  /// The school's character programme (name + trait labels); the built-in Tarbiyah names until / unless it loads.
  final settings = Rx<CharacterSettings>(CharacterSettings.fallback);

  bool get canView {
    auth.staffMe.value;
    return perms.canAccess('behaviour:view');
  }

  bool get canLog {
    auth.staffMe.value;
    return perms.canAccess('behaviour:manage');
  }

  List<ClassRef> get classes => teacherClassesOf(auth.staffMe.value?.teacherProfile);

  String get myId => auth.user.value?.id ?? '';
  String get myName => auth.user.value?.name ?? '';

  /// Behaviour points: the server's total for the student when known (it counts every record, not only the loaded pages), else the
  /// sum of the loaded records (+ merit / - demerit).
  int get totalPoints => pointsFromServer.value ?? (records.value.data ?? const <BehaviourRecord>[]).fold(0, (a, r) => a + r.points);

  @override
  void onReady() {
    super.onReady();
    load();
  }

  Future<void> load() async {
    if (!canView) {
      student.value = const SectionState.forbidden();
      return;
    }
    final token = ++_token;
    student.value = const SectionState.loading();
    records.value = const SectionState.loading();
    tarbiyah.value = const SectionState.loading();
    try {
      final s = await _resolveStudent();
      if (token != _token) return;
      if (s == null) {
        student.value = const SectionState.empty(); // "not in one of your classes"
        return;
      }
      student.value = SectionState.data(s);
    } catch (e) {
      if (token != _token) return;
      student.value = SectionState<StudentSummary>.fromError(e, previous: student.value);
      return;
    }
    await Future.wait([_loadRecords(token), _loadTarbiyah(token), _loadPoints(token), _loadSettings(token)]);
  }

  /// Best effort: the header falls back to the loaded records' sum. A 403 / old server leaves it null.
  Future<void> _loadPoints(int token) async {
    try {
      final p = await repo.fetchPointsTotal(studentId);
      if (token == _token) pointsFromServer.value = p;
    } catch (_) {}
  }

  /// Best effort: trait labels / programme name; the built-in names are the fallback.
  Future<void> _loadSettings(int token) async {
    try {
      final st = await repo.fetchCharacterSettings();
      if (token == _token) settings.value = st;
    } catch (_) {}
  }

  Future<StudentSummary?> _resolveStudent() async {
    final cs = classes;
    final i = initial;
    if (i != null && i.id == studentId) return inAnyClass(i, cs, includeUnsectioned: true) ? i : null;
    GradesSections? known;
    var triedKnown = false;
    for (final c in cs) {
      if (!triedKnown) {
        triedKnown = true;
        try {
          known = await students.fetchGradesSections();
        } catch (_) {}
      }
      final roster = await students.fetchClassRoster(c, known: known, includeUnsectioned: true);
      for (final s in roster) {
        if (s.id == studentId) return s;
      }
    }
    return null;
  }

  Future<void> _loadRecords(int token) async {
    try {
      _recordsPage = 1;
      final page = await repo.fetchRecordsPage(studentId: studentId, page: 1, limit: recordsPageSize);
      if (token != _token) return;
      final list = page.records.where((r) => r.studentId == studentId).toList();
      recordsHasMore.value = page.pages > 1;
      recordsLoadMoreError.value = null;
      records.value = list.isEmpty ? const SectionState.empty() : SectionState.data(list);
    } catch (e) {
      if (token != _token) return;
      records.value = SectionState<List<BehaviourRecord>>.fromError(e, previous: records.value);
    }
  }

  Future<void> _loadTarbiyah(int token) async {
    try {
      final list = await repo.fetchTarbiyah(studentId);
      if (token != _token) return;
      tarbiyah.value = list.isEmpty ? const SectionState.empty() : SectionState.data(list);
    } catch (e) {
      if (token != _token) return;
      tarbiyah.value = SectionState<List<TarbiyahAssessment>>.fromError(e, previous: tarbiyah.value);
    }
  }

  Future<void> loadMoreRecords() async {
    if (loadingMoreRecords.value || !recordsHasMore.value || !records.value.hasData) return;
    final token = _token;
    loadingMoreRecords.value = true;
    recordsLoadMoreError.value = null;
    try {
      final next = _recordsPage + 1;
      final page = await repo.fetchRecordsPage(studentId: studentId, page: next, limit: recordsPageSize);
      if (token != _token) return;
      _recordsPage = next;
      final have = {for (final r in records.value.data!) r.id};
      final more = page.records.where((r) => r.studentId == studentId && have.add(r.id));
      recordsHasMore.value = next < page.pages;
      records.value = SectionState.data([...records.value.data!, ...more]);
    } catch (_) {
      if (token == _token) recordsLoadMoreError.value = "Couldn't load more. Check your connection and try again.";
    } finally {
      loadingMoreRecords.value = false;
    }
  }

  /// An edited / resolved record replaces its old version.
  void replaceRecord(BehaviourRecord r) {
    final cur = records.value.data;
    if (cur == null || !cur.any((x) => x.id == r.id)) return;
    records.value = SectionState.data([for (final x in cur) x.id == r.id ? r : x]);
  }

  /// A Tarbiyah assessment just created / edited from the form replaces (or joins) the list, newest first.
  void upsertTarbiyah(TarbiyahAssessment a) {
    final cur = tarbiyah.value.data ?? const <TarbiyahAssessment>[];
    final list = [a, ...cur.where((x) => x.id != a.id)];
    list.sort((x, y) => (y.day ?? DateTime(0)).compareTo(x.day ?? DateTime(0)));
    tarbiyah.value = SectionState.data(list);
  }

  /// Creating an assessment needs `behaviour:manage`; editing one also needs me to be its author (the server's rule; a coordinator or admin may
  /// edit any, but they do not use this app).
  bool canEditTarbiyah(TarbiyahAssessment a) => canLog && a.isMine(userId: myId, userName: myName);

  Future<void> reload() => load();

  /// Adds a record logged from this screen.
  void addRecord(BehaviourRecord r) {
    final list = [r, ...(records.value.data ?? const <BehaviourRecord>[]).where((x) => x.id != r.id)];
    records.value = SectionState.data(list);
  }
}
