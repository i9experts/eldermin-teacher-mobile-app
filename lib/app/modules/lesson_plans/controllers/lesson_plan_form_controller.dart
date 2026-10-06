import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../../core/models/academic/lesson_plan_models.dart';
import '../../../../core/services/lesson_plan_repository.dart';
import '../../../../core/utils/class_match.dart';
import '../../../../core/utils/home_time.dart';
import '../../../../core/utils/roster_scope.dart';
import '../../../../core/utils/timetable_week.dart' show dateOnly;
import '../../../common/action_failure.dart';
import '../../auth/controllers/auth_controller.dart';
import 'lesson_plans_controller.dart';

sealed class PlanResult {
  const PlanResult();
}

class PlanSaved extends PlanResult {
  final LessonPlanRecord plan;
  final bool submitted;
  const PlanSaved(this.plan, {this.submitted = false});
}

class PlanInvalid extends PlanResult {
  final Map<String, String> errors;
  const PlanInvalid(this.errors);
}

class PlanFailed extends PlanResult {
  final ActionFailure failure;
  const PlanFailed(this.failure);
}

class PlanNoChanges extends PlanResult {
  const PlanNoChanges();
}

class PlanIgnored extends PlanResult {
  const PlanIgnored();
}

/// `Get.arguments` of `/lesson-plans/new`: a plan to edit and / or a parsed draft that prefills the form.
class LessonPlanFormArgs {
  final LessonPlanRecord? editing;
  final LessonPlanDraft? draft;
  const LessonPlanFormArgs({this.editing, this.draft});
}

/// One learning-objective line (stable id so the list rebuilds correctly when lines are removed).
class ObjectiveField {
  final int id;
  final TextEditingController controller;
  ObjectiveField(this.id, [String text = '']) : controller = TextEditingController(text: text);
}

/// Create / edit a lesson plan (`/lesson-plans/new`; edit when [editing] is passed, prefilled when a parsed [draft] is passed).
///
/// State machine: fields + `saving`. Two outcomes on every form: "Save as draft" (create: status `draft`; edit: only the changed fields,
/// status untouched) and "Submit for approval" (create: status `submitted`; edit: changed fields + `status:'submitted'`, which is how a
/// rejected plan is resubmitted: there is no dedicated route, teaching.controller.ts:80-82). A save in flight ignores a second call
/// (double-submit); a failed save keeps every field so a retry (offline, 5xx, 403) sends the same thing again. NEVER submits by itself:
/// a parsed draft only fills the fields.
class LessonPlanFormController extends GetxController {
  final LessonPlanRepository? _repo;
  final AuthController? _auth;
  final LessonPlansController? _list;
  final Clock clock;
  final LessonPlanRecord? editing;
  final LessonPlanDraft? draft;

  LessonPlanFormController({
    LessonPlanRepository? repository,
    AuthController? auth,
    LessonPlansController? list,
    Clock? clock,
    this.editing,
    this.draft,
  })  : _repo = repository,
        _auth = auth,
        _list = list,
        clock = clock ?? DateTime.now;

  LessonPlanRepository get repo => _repo ?? Get.find<LessonPlanRepository>();
  AuthController get auth => _auth ?? Get.find<AuthController>();
  LessonPlansController? get list => _list ?? (Get.isRegistered<LessonPlansController>() ? Get.find<LessonPlansController>() : null);

  bool get isEditing => editing != null;
  DateTime get today => dateOnly(clock());

  final topicC = TextEditingController();
  final descriptionC = TextEditingController();
  final durationC = TextEditingController();
  final priorC = TextEditingController();
  final activitiesC = TextEditingController();
  final assessmentC = TextEditingController();
  final homeworkC = TextEditingController();
  final otherResourceC = TextEditingController();

  final objectives = <ObjectiveField>[].obs;
  final resources = <String>{}.obs;
  final methodology = RxnString();
  final classIndex = (-1).obs;
  final subject = RxnString();
  final planDay = Rxn<DateTime>();
  final saving = false.obs;
  final errors = <String, String>{}.obs;
  final submitFailure = Rxn<ActionFailure>();

  /// Shown above the form when it was prefilled from a parsed document.
  final prefilledFrom = RxnString();
  final prefillWarnings = <String>[].obs;
  final prefillHint = RxnString();
  int _objSeq = 0;

  List<ClassRef> get classes {
    auth.staffMe.value;
    return teacherClassesOf(auth.staffMe.value?.teacherProfile);
  }

  ClassRef? get selectedClass {
    final cs = classes;
    return classIndex.value >= 0 && classIndex.value < cs.length ? cs[classIndex.value] : null;
  }

  /// Subjects of the picked class (from my assignments), else everything I can teach.
  List<String> get subjects {
    final c = selectedClass;
    if (c != null && c.subjects.isNotEmpty) return c.subjects;
    return auth.staffMe.value?.teacherProfile?.subjectsCanTeach ?? const [];
  }

  String get classLabel => isEditing ? editing!.classLabel : (selectedClass?.label ?? '');
  String get subjectLabel => isEditing ? editing!.subject : (subject.value ?? '');

  @override
  void onInit() {
    super.onInit();
    final e = editing;
    if (e != null) {
      topicC.text = e.topic;
      descriptionC.text = e.description;
      durationC.text = e.durationMins?.toString() ?? '';
      priorC.text = e.priorKnowledge;
      activitiesC.text = e.activities;
      assessmentC.text = e.assessment;
      homeworkC.text = e.homework;
      methodology.value = e.teachingMethodology.isEmpty ? null : e.teachingMethodology;
      planDay.value = e.planDay;
      final known = e.resources.where(kLessonResources.contains);
      resources.addAll(known);
      otherResourceC.text = e.resources.where((r) => !kLessonResources.contains(r)).join('; ');
      objectives.addAll([for (final o in e.learningObjectives) ObjectiveField(_objSeq++, o)]);
    } else {
      final cs = classes;
      if (cs.length == 1) selectClass(0);
      final d = draft;
      if (d != null) _applyDraft(d);
    }
    if (objectives.isEmpty) objectives.add(ObjectiveField(_objSeq++));
  }

  void _applyDraft(LessonPlanDraft d) {
    topicC.text = d.topic;
    descriptionC.text = d.description;
    durationC.text = d.durationMins?.toString() ?? '';
    homeworkC.text = d.homework;
    methodology.value = d.methodology;
    resources.addAll(d.resources);
    otherResourceC.text = d.otherResource;
    objectives.addAll([for (final o in d.objectives) ObjectiveField(_objSeq++, o)]);
    prefilledFrom.value = d.sourceFileName ?? 'your document';
    prefillWarnings.assignAll(d.warnings);
    // The class and subject in a document are only a guess "as written": preselect ONLY when it matches one of MY classes exactly.
    final cs = classes;
    final g = d.gradeLevelGuess;
    if (g != null) {
      final hits = [for (var i = 0; i < cs.length; i++) if (sameGrade(cs[i].grade, g)) i];
      if (hits.length == 1) selectClass(hits.single);
    }
    final sg = d.subjectGuess;
    if (sg != null && selectedClass != null) {
      final m = subjects.where((s) => s.toLowerCase() == sg.trim().toLowerCase()).toList();
      if (m.length == 1) setSubject(m.single);
    }
    if ((g != null || sg != null) && (selectedClass == null || subject.value == null)) {
      prefillHint.value = 'The document says: ${[if (sg != null) sg, if (g != null) g].join(', ')}. Choose your class and subject.';
    }
  }

  @override
  void onClose() {
    for (final c in [topicC, descriptionC, durationC, priorC, activitiesC, assessmentC, homeworkC, otherResourceC]) {
      c.dispose();
    }
    for (final o in objectives) {
      o.controller.dispose();
    }
    super.onClose();
  }

  void selectClass(int i) {
    if (isEditing || i == classIndex.value) return;
    classIndex.value = i;
    errors.remove('class');
    final subs = subjects;
    if (subject.value == null || !subs.contains(subject.value)) subject.value = subs.length == 1 ? subs.first : null;
    if (subject.value != null) errors.remove('subject');
  }

  void setSubject(String s) {
    subject.value = s;
    errors.remove('subject');
  }

  void setMethodology(String? m) => methodology.value = methodology.value == m ? null : m;

  void toggleResource(String r) {
    if (!resources.remove(r)) resources.add(r);
  }

  void setPlanDay(DateTime d) {
    planDay.value = dateOnly(d);
    errors.remove('date');
  }

  void addObjective() => objectives.add(ObjectiveField(_objSeq++));

  void removeObjective(int id) {
    if (objectives.length <= 1) {
      objectives.first.controller.clear();
      return;
    }
    final i = objectives.indexWhere((o) => o.id == id);
    if (i < 0) return;
    final removed = objectives.removeAt(i);
    removed.controller.dispose();
  }

  /// The resources as sent: the ticked known ones (stable order) + the free-text ones (`;`-separated).
  List<String> get resourceList => [
        ...kLessonResources.where(resources.contains),
        ...otherResourceC.text.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty),
      ];

  /// Field errors keyed `class|subject|topic|date|duration`; empty = valid.
  Map<String, String> validate() {
    final e = <String, String>{};
    if (!isEditing) {
      if (selectedClass == null) e['class'] = 'Choose a class';
      if (subject.value == null || subject.value!.isEmpty) e['subject'] = 'Choose a subject';
    }
    if (topicC.text.trim().isEmpty) e['topic'] = 'Enter the topic';
    if (planDay.value == null) e['date'] = 'Choose the lesson date';
    final dur = durationC.text.trim();
    if (dur.isNotEmpty) {
      final n = int.tryParse(dur);
      if (n == null || n < 10 || n > 180) e['duration'] = 'Enter 10 to 180 minutes';
    }
    return e;
  }

  LessonPlanInput? _input() {
    final day = planDay.value;
    if (day == null) return null;
    final c = selectedClass;
    final dur = durationC.text.trim();
    return LessonPlanInput(
      subject: editing?.subject ?? subject.value ?? '',
      gradeLevel: editing?.gradeLevel ?? c?.grade ?? '',
      sectionName: editing?.sectionName ?? c?.section ?? '',
      topic: topicC.text,
      description: descriptionC.text,
      planDay: day,
      durationMins: dur.isEmpty ? null : int.tryParse(dur),
      methodology: methodology.value ?? '',
      objectives: [for (final o in objectives) o.controller.text],
      resources: resourceList,
      priorKnowledge: priorC.text,
      activities: activitiesC.text,
      assessment: assessmentC.text,
      homework: homeworkC.text,
    );
  }

  /// Saves as a draft ([forApproval] false) or submits it for approval (true).
  Future<PlanResult> submit({required bool forApproval}) async {
    if (saving.value) return const PlanIgnored();
    final problems = validate();
    final staffId = auth.staffId;
    if (staffId == null || staffId.isEmpty) problems['topic'] = problems['topic'] ?? "Your teacher profile isn't loaded yet. Go back and pull down to refresh.";
    errors.assignAll(problems);
    if (problems.isNotEmpty) return PlanInvalid(problems);
    final input = _input();
    if (input == null) return PlanInvalid(errors);
    saving.value = true;
    submitFailure.value = null;
    try {
      final LessonPlanRecord saved;
      if (isEditing) {
        final patch = input.toPatchJson(editing!, status: forApproval ? LessonPlanStatus.submitted : null);
        if (patch.isEmpty) return const PlanNoChanges();
        saved = await repo.update(editing!.id, patch);
      } else {
        final body = input.toCreateJson(
          teacherId: staffId!,
          teacherName: auth.staffMe.value?.user.name ?? '',
          status: forApproval ? LessonPlanStatus.submitted : LessonPlanStatus.draft,
        );
        saved = await repo.create(body);
      }
      list?.upsert(saved);
      return PlanSaved(saved, submitted: forApproval && saved.status == LessonPlanStatus.submitted);
    } catch (e) {
      final f = ActionFailure.from(e, what: isEditing ? 'save this lesson plan' : 'create this lesson plan');
      submitFailure.value = f;
      return PlanFailed(f);
    } finally {
      saving.value = false;
    }
  }

  /// Anything typed that would be lost on back.
  bool get isDirty {
    if (isEditing) {
      final input = _input();
      return input != null && input.toPatchJson(editing!).isNotEmpty;
    }
    return topicC.text.trim().isNotEmpty ||
        descriptionC.text.trim().isNotEmpty ||
        homeworkC.text.trim().isNotEmpty ||
        activitiesC.text.trim().isNotEmpty ||
        assessmentC.text.trim().isNotEmpty ||
        objectives.any((o) => o.controller.text.trim().isNotEmpty) ||
        prefilledFrom.value != null;
  }
}
