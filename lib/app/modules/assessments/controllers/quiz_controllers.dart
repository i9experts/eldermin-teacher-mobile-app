import 'package:get/get.dart';
import '../../../../core/models/assessments/assessment_models.dart';
import '../../../../core/services/assessment_repository.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/utils/assessment_scope.dart';
import '../../../../core/utils/roster_scope.dart';
import '../../../common/action_failure.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/models/section_state.dart';

/// Online-quiz attempts waiting for a teacher (`/assessments/quiz-attempts`). The server list may be broader than what a teacher may see, so
/// the app keeps ONLY the attempts allowed by [isMyAttempt] (class teacher: all subjects of their own class; subject teacher: their subjects
/// in the classes they teach; union when both) and refuses to open an attempt outside that rule even by direct id
/// ([QuizAttemptDetailController.load]). A subject chip row (All + one per subject present) narrows the visible list.
class QuizAttemptsController extends GetxController {
  final AssessmentRepository? _repo;
  final AuthController? _auth;
  final PermissionService? _perms;

  QuizAttemptsController({AssessmentRepository? repository, AuthController? auth, PermissionService? permissions})
      : _repo = repository,
        _auth = auth,
        _perms = permissions;

  AssessmentRepository get repo => _repo ?? Get.find<AssessmentRepository>();
  AuthController get auth => _auth ?? Get.find<AuthController>();
  PermissionService get perms => _perms ?? Get.find<PermissionService>();

  final state = Rx<SectionState<List<QuizAttempt>>>(const SectionState.loading());
  int _token = 0;

  bool get canView {
    auth.staffMe.value;
    return perms.canAccess('assessments:view');
  }

  List<ClassRef> get myClasses => teacherClassesOf(auth.staffMe.value?.teacherProfile);
  List<QuizAttempt> get items => state.value.data ?? const [];

  /// True when /staff-portal/me gives this teacher no class and no subject at all (the empty state then explains why).
  bool get hasNoScope => myClasses.isEmpty;

  /// Selected subject chip; null = All.
  final subjectFilter = RxnString();

  /// Subjects present in the visible attempts (chip row).
  List<String> get subjects => attemptSubjects(items);

  /// [items] narrowed by [subjectFilter].
  List<QuizAttempt> get visible {
    final f = subjectFilter.value?.trim().toLowerCase();
    return f == null ? items : [for (final a in items) if (a.subject.trim().toLowerCase() == f) a];
  }

  int countFor(String? subject) => subject == null ? items.length : items.where((a) => a.subject.trim().toLowerCase() == subject.trim().toLowerCase()).length;

  void setSubjectFilter(String? subject) => subjectFilter.value = subject;

  void _fixFilter() {
    final f = subjectFilter.value;
    if (f != null && !subjects.any((s) => s.toLowerCase() == f.toLowerCase())) subjectFilter.value = null;
  }

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
      final all = await repo.pendingAttempts();
      if (token != _token) return;
      final mine = [for (final a in all) if (a.isPending && isMyAttempt(a, myClasses)) a];
      state.value = mine.isEmpty ? const SectionState.empty() : SectionState.data(mine);
      _fixFilter();
    } catch (e) {
      if (token != _token) return;
      state.value = SectionState<List<QuizAttempt>>.fromError(e);
    }
  }

  Future<void> reload() async {
    await auth.refreshProfile(force: true);
    await load(force: true);
  }

  /// Removes a finished attempt from the queue (it is graded now).
  void remove(String id) {
    final rest = [for (final a in items) if (a.id != id) a];
    state.value = rest.isEmpty ? const SectionState.empty() : SectionState.data(rest);
    _fixFilter();
  }
}

sealed class GradeResult {
  const GradeResult();
}

class GradeSaved extends GradeResult {
  /// Every written answer has a mark now: the attempt is graded and the student's mark entry was written.
  final bool complete;
  const GradeSaved({required this.complete});
}

class GradeInvalid extends GradeResult {
  final String message;
  const GradeInvalid(this.message);
}

class GradeFailed extends GradeResult {
  final ActionFailure failure;
  const GradeFailed(this.failure);
}

class GradeIgnored extends GradeResult {
  const GradeIgnored();
}

/// One attempt (`/assessments/quiz-attempts/:id`): marks for the written (subjective) answers.
///
/// EFFECT on the MarkEntry (assessment.service.ts:1490-1544): `POST .../grade` stores `marksAwarded` per written answer; only when NO written
/// answer is left without a mark does the attempt become `graded` (obtainedMarks = sum of ALL answers' marks) and a MarkEntry for that student
/// and subject is UPSERTED ("Online Quiz (auto)"), replacing any mark already there (verified or not). A partly graded attempt keeps
/// `submitted`, shows no total and writes nothing. The server accepts ANY number: the app bounds each mark to 0..the question's marks.
/// A graded attempt is read-only here (a re-grade would overwrite the mark entry again).
class QuizAttemptDetailController extends GetxController {
  final String id;
  final QuizAttemptsController? _list;
  final AssessmentRepository? _repo;

  QuizAttemptDetailController({required this.id, QuizAttemptsController? list, AssessmentRepository? repository})
      : _list = list,
        _repo = repository;

  QuizAttemptsController get list => _list ?? Get.find<QuizAttemptsController>();
  AssessmentRepository get repo => _repo ?? Get.find<AssessmentRepository>();

  final state = Rx<SectionState<QuizAttempt>>(const SectionState.loading());

  /// Typed marks per question id.
  final inputs = <String, String>{}.obs;
  final saving = false.obs;
  final showErrors = false.obs;
  final failure = Rxn<ActionFailure>();
  final revision = 0.obs;
  Map<String, String> _original = {};

  QuizAttempt? get attempt => state.value.data;
  bool get editable => attempt?.isPending ?? false;

  @override
  void onReady() {
    super.onReady();
    load();
  }

  Future<void> load() async {
    state.value = const SectionState.loading();
    try {
      if (!list.canView) {
        state.value = const SectionState.forbidden();
        return;
      }
      final a = await repo.attempt(id);
      if (!isMyAttempt(a, list.myClasses)) {
        state.value = const SectionState.error("This quiz attempt isn't from your class or one of your subjects.");
        return;
      }
      _seed(a);
      state.value = SectionState.data(a);
    } catch (e) {
      state.value = SectionState<QuizAttempt>.fromError(e);
    }
  }

  Future<void> _refreshAfterConflict() async {
    try {
      final fresh = await repo.attempt(id);
      if (!isMyAttempt(fresh, list.myClasses)) return;
      final keep = failure.value;
      _seed(fresh);
      failure.value = keep;
      state.value = SectionState.data(fresh);
      if (fresh.isGraded) list.remove(id);
    } catch (_) {}
  }

  void _seed(QuizAttempt a) {
    final m = {for (final x in a.manualAnswers) x.questionId: x.marksAwarded == null ? '' : marksText(x.marksAwarded!)};
    _original = Map.of(m);
    inputs.assignAll(m);
    showErrors.value = false;
    failure.value = null;
    revision.value++;
  }

  QuizAnswer? _answer(String qid) {
    for (final a in attempt?.answers ?? const <QuizAnswer>[]) {
      if (a.questionId == qid) return a;
    }
    return null;
  }

  static final RegExp _decimal = RegExp(r'^\d+([.,]\d{0,2})?$|^[.,]\d{1,2}$');

  double? valueOf(String qid) {
    final t = (inputs[qid] ?? '').trim();
    return t.isEmpty ? null : double.tryParse(t.replaceAll(',', '.'));
  }

  /// Bounds: 0 .. the question's marks. A question whose maximum is unknown cannot be graded.
  String? errorFor(String qid) {
    final t = (inputs[qid] ?? '').trim();
    if (t.isEmpty) return null;
    final q = _answer(qid)?.question;
    if (q == null) return "This question's details are missing, so it can't be graded here.";
    if (!_decimal.hasMatch(t)) return 'Enter a number.';
    final v = valueOf(qid);
    if (v == null) return 'Enter a number.';
    if (v < 0) return "Marks can't be negative.";
    if (v > q.marks) return "Can't be more than ${marksText(q.marks)}.";
    return null;
  }

  void setMark(String qid, String text) {
    if (!editable || saving.value) return;
    inputs[qid] = text;
    failure.value = null;
    revision.value++;
  }

  bool get hasChanges => inputs.entries.any((e) => (_original[e.key] ?? '') != e.value);
  bool get hasErrors => inputs.keys.any((k) => errorFor(k) != null);

  /// Manual answers that have a typed mark.
  int get filledCount => inputs.values.where((v) => v.trim().isNotEmpty).length;
  int get manualCount => inputs.length;
  bool get complete => manualCount > 0 && filledCount == manualCount;

  /// What the total would be once every written answer has its mark: auto-graded marks + typed marks (null while one is missing).
  double? get previewTotal {
    final a = attempt;
    if (a == null || !complete || hasErrors) return null;
    var sum = 0.0;
    for (final x in a.answers) {
      sum += x.needsManualGrading ? (valueOf(x.questionId) ?? 0) : (x.marksAwarded ?? 0);
    }
    return sum;
  }

  /// Sends every typed mark of the written answers. A partial set is allowed: the attempt then stays in the queue.
  Future<GradeResult> submit() async {
    if (saving.value || !editable) return const GradeIgnored();
    showErrors.value = true;
    revision.value++;
    if (hasErrors) return const GradeInvalid('Fix the marks marked in red first.');
    if (filledCount == 0) return const GradeInvalid('Enter a mark for at least one written answer.');
    saving.value = true;
    failure.value = null;
    try {
      final grades = [
        for (final e in inputs.entries)
          if (e.value.trim().isNotEmpty) (questionId: e.key, marks: valueOf(e.key)!),
      ];
      final saved = await repo.gradeAttempt(id, grades);
      _seed(saved);
      state.value = SectionState.data(saved);
      if (saved.isGraded) list.remove(id);
      return GradeSaved(complete: saved.isGraded);
    } catch (e) {
      final f = ActionFailure.from(e, what: 'save these marks', keep: 'Your marks are kept.');
      failure.value = f;
      // 409: somebody graded this attempt meanwhile. Re-read it so the screen shows the graded (read-only) state; the server message stays.
      if (f.kind == ActionFailureKind.conflict) await _refreshAfterConflict();
      return GradeFailed(f);
    } finally {
      saving.value = false;
    }
  }
}
