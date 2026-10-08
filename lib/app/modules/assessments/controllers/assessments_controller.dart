import 'package:get/get.dart';
import '../../../../core/models/assessments/assessment_models.dart';
import '../../../../core/services/assessment_repository.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/utils/assessment_scope.dart';
import '../../../../core/utils/roster_scope.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/models/section_state.dart';

enum AssessmentFilter {
  open('Marks open'),
  upcoming('Upcoming'),
  drafts('Drafts'),
  published('Published'),
  all('All');

  final String label;
  const AssessmentFilter(this.label);
}

/// Why marks of one subject can (not) be entered. [editable] is the only state in which the grid accepts input.
///
/// Owner decisions 2026-10-08 (post-approval fixes):
///  * PUBLISHED / CANCELLED assessments are LOCKED for a teacher ([locked]): the backend answers 403 on marks/bulk and quiz grading for them
///    (planned, see PHASE6B_REPORT section 15) and the app shows the grid read-only with a banner, so the teacher never gets there.
///    Before this the app only warned (owner decision of 2026-10-07: "no gate"); that warning is gone.
///  * DRAFT assessments are listed (badge "Draft") but take no marks yet ([draft]).
/// Still no gate for scheduled / ongoing / completed. The other hard blocks are "not my subject" and the online-quiz subjects (their marks
/// come from quiz grading).
enum MarksAccess {
  editable,
  notMySubject,
  onlineQuiz,
  draft,
  locked;

  bool get canEdit => this == MarksAccess.editable;

  String get explanation => switch (this) {
        MarksAccess.editable => '',
        MarksAccess.notMySubject => "You don't teach this subject in this class, so the marks are view-only.",
        MarksAccess.onlineQuiz => 'Students take this subject as an online quiz. Its marks come from quiz grading, not from this grid.',
        MarksAccess.draft => "Draft assessments can't take marks yet.",
        MarksAccess.locked => 'Marks are locked. Ask an administrator to change them.',
      };
}

MarksAccess marksAccessFor(Assessment a, AssessmentSubject s, {required bool iTeachIt}) {
  if (!iTeachIt) return MarksAccess.notMySubject;
  if (a.status == AssessmentStatus.draft) return MarksAccess.draft;
  if (a.isOnline && s.hasQuizPaper) return MarksAccess.onlineQuiz;
  if (marksLockMessage(a) != null) return MarksAccess.locked;
  return MarksAccess.editable;
}

/// Why a teacher can no longer change the marks of [a] (results published, or cancelled); null while marks can still change. The server
/// refuses these writes with 403 (backend commit e7c4ed2, assessment.service.ts assertTeacherMarksNotLocked; exact text, copied from there and
/// documented in docs/staff-portal/PHASE6_FIXES.md:
/// "Results for this assessment are published (or the assessment is cancelled): marks can no longer be changed. Contact an administrator.").
String? marksLockMessage(Assessment a) {
  if (a.isResultPublished) return 'Results are published \u2014 marks are locked. Ask an administrator to change them.';
  if (a.status == AssessmentStatus.cancelled) return 'This assessment is cancelled \u2014 marks are locked. Ask an administrator to change them.';
  return null;
}

/// "My assessments" (`/assessments`): every assessment of my campus that falls under one of my classes (a subject I teach there, or I am
/// the class teacher), newest first. `GET /assessments` has NO teacher scoping (campus only, assessment.service.ts:994-1021), so the whole
/// list is fetched page by page (limit 100, no server maximum, assessment.dto.ts:14) and scoped here (see [isMyAssessment]).
class AssessmentsController extends GetxController {
  final AssessmentRepository? _repo;
  final AuthController? _auth;
  final PermissionService? _perms;

  AssessmentsController({AssessmentRepository? repository, AuthController? auth, PermissionService? permissions})
      : _repo = repository,
        _auth = auth,
        _perms = permissions;

  AssessmentRepository get repo => _repo ?? Get.find<AssessmentRepository>();
  AuthController get auth => _auth ?? Get.find<AuthController>();
  PermissionService get perms => _perms ?? Get.find<PermissionService>();

  final state = Rx<SectionState<List<Assessment>>>(const SectionState.loading());
  final filter = AssessmentFilter.open.obs;

  /// The server list hit the page cap: older assessments may be missing.
  final truncated = false.obs;
  int _token = 0;

  bool get canView {
    auth.staffMe.value;
    return perms.canAccess('assessments:view');
  }

  List<ClassRef> get myClasses => teacherClassesOf(auth.staffMe.value?.teacherProfile);
  bool get isClassTeacher => myClasses.any((c) => c.isClassTeacherClass);
  List<Assessment> get items => state.value.data ?? const [];

  bool _inFilter(Assessment a, AssessmentFilter f) => switch (f) {
        AssessmentFilter.open => !a.isResultPublished && (a.status == AssessmentStatus.ongoing || a.status == AssessmentStatus.completed),
        AssessmentFilter.upcoming => a.status == AssessmentStatus.scheduled,
        AssessmentFilter.drafts => a.status == AssessmentStatus.draft,
        AssessmentFilter.published => a.isResultPublished,
        AssessmentFilter.all => true,
      };

  List<Assessment> get filtered => items.where((a) => _inFilter(a, filter.value)).toList();
  int countFor(AssessmentFilter f) => items.where((a) => _inFilter(a, f)).length;
  void setFilter(AssessmentFilter f) => filter.value = f;

  /// My subjects of [a] (those I teach in one of its classes).
  List<String> subjectsOf(Assessment a) => mySubjectsOf(a, myClasses);

  bool teachesSubject(Assessment a, String subject) => rosterClassesFor(a, subject, myClasses).isNotEmpty;

  MarksAccess accessFor(Assessment a, AssessmentSubject s) => marksAccessFor(a, s, iTeachIt: teachesSubject(a, s.subject));

  /// I am the class teacher of one of the classes of [a]: report-card remarks apply.
  bool canWriteRemarks(Assessment a) => myClassTeacherClassesFor(a, myClasses).isNotEmpty && a.gradeCardsGenerated;

  @override
  void onReady() {
    super.onReady();
    load();
  }

  Future<void> load({bool force = false}) async {
    if (!canView) {
      state.value = const SectionState.forbidden();
      return;
    }
    if (!force && state.value.hasData) return;
    final token = ++_token;
    if (!state.value.hasData) state.value = const SectionState.loading();
    try {
      final all = await repo.listAssessments();
      if (token != _token) return;
      truncated.value = all.truncated;
      final mine = myAssessments(all.items, myClasses)..sort((a, b) => (b.startDate ?? DateTime(0)).compareTo(a.startDate ?? DateTime(0)));
      state.value = mine.isEmpty ? const SectionState.empty() : SectionState.data(mine);
    } catch (e) {
      if (token != _token) return;
      state.value = SectionState<List<Assessment>>.fromError(e);
    }
  }

  Future<void> reload() async {
    await auth.refreshProfile(force: true);
    await load(force: true);
  }

  Future<void> ensureLoaded() async {
    if (state.value.hasData || state.value.status == SectionStatus.empty) return;
    await load(force: state.value.status == SectionStatus.error);
  }

  Assessment? byId(String id) {
    for (final a in items) {
      if (a.id == id) return a;
    }
    return null;
  }
}

/// One assessment (`/assessments/:id`): from the list's cache, else `GET /assessments/:id` (schoolSlug only: no campus / owner check,
/// assessment.service.ts:1023-1027) followed by the same scope test; an assessment that is not mine is refused.
class AssessmentDetailController extends GetxController {
  final String id;
  final AssessmentsController? _list;
  final AssessmentRepository? _repo;

  AssessmentDetailController({required this.id, AssessmentsController? list, AssessmentRepository? repository})
      : _list = list,
        _repo = repository;

  AssessmentsController get list => _list ?? Get.find<AssessmentsController>();
  AssessmentRepository get repo => _repo ?? Get.find<AssessmentRepository>();

  final state = Rx<SectionState<Assessment>>(const SectionState.loading());

  @override
  void onReady() {
    super.onReady();
    load();
  }

  Future<void> load({bool force = false}) async {
    if (!list.canView) {
      state.value = const SectionState.forbidden();
      return;
    }
    if (force) {
      await list.load(force: true);
    } else {
      await list.ensureLoaded();
    }
    final ls = list.state.value;
    if (ls.status == SectionStatus.forbidden) {
      state.value = const SectionState.forbidden();
      return;
    }
    final cached = list.byId(id);
    if (cached != null) {
      state.value = SectionState.data(cached);
      return;
    }
    if (ls.status == SectionStatus.error) {
      state.value = SectionState.error(ls.message ?? "Couldn't load this assessment.");
      return;
    }
    try {
      final one = await repo.assessment(id);
      if (!isMyAssessment(one, list.myClasses)) {
        state.value = const SectionState.error("This assessment isn't one of yours.");
        return;
      }
      state.value = SectionState.data(one);
    } catch (e) {
      state.value = SectionState<Assessment>.fromError(e);
    }
  }
}
