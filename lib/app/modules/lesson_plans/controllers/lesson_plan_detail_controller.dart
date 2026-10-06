import 'package:get/get.dart';
import '../../../../core/models/academic/lesson_plan_models.dart';
import '../../../../core/services/lesson_plan_repository.dart';
import '../../../common/action_failure.dart';
import '../../home/models/section_state.dart';
import 'lesson_plan_form_controller.dart';
import 'lesson_plans_controller.dart';

/// One lesson plan (`/lesson-plans/:id`). There is no `GET /teaching/lesson-plans/:id`: the plan comes from my list (loaded on demand when
/// the screen is opened from a Home link). Submitting is `PATCH {status:'submitted'}` with NOTHING else in the body (raw `$set`).
class LessonPlanDetailController extends GetxController {
  final String id;
  final LessonPlansController? _list;
  final LessonPlanRepository? _repo;

  LessonPlanDetailController({required this.id, LessonPlansController? list, LessonPlanRepository? repository})
      : _list = list,
        _repo = repository;

  LessonPlansController get list => _list ?? Get.find<LessonPlansController>();
  LessonPlanRepository get repo => _repo ?? Get.find<LessonPlanRepository>();

  final state = Rx<SectionState<LessonPlanRecord>>(const SectionState.loading());
  final submitting = false.obs;
  final actionFailure = Rxn<ActionFailure>();

  @override
  void onReady() {
    super.onReady();
    load();
  }

  Future<void> load({bool force = false}) async {
    if (force) {
      await list.load(force: true);
    } else {
      await list.ensureLoaded();
    }
    _sync();
  }

  void _sync() {
    final ls = list.state.value;
    if (ls.status == SectionStatus.forbidden) {
      state.value = const SectionState.forbidden();
      return;
    }
    final p = list.byId(id);
    if (p != null) {
      state.value = SectionState.data(p);
    } else if (ls.status == SectionStatus.error || ls.isLoading) {
      state.value = SectionState.error(ls.message ?? "Couldn't load this lesson plan.");
    } else {
      state.value = const SectionState.error("This lesson plan isn't in your list. It may belong to someone else or have been removed.");
    }
  }

  LessonPlanRecord? get plan => state.value.data;

  /// Re-reads the plan from the list after an edit.
  void refreshFromList() => _sync();

  Future<PlanResult> submitForApproval() async {
    final p = plan;
    if (p == null || !p.canSubmit) return const PlanIgnored();
    if (submitting.value) return const PlanIgnored();
    submitting.value = true;
    actionFailure.value = null;
    try {
      final saved = await repo.update(p.id, {'status': LessonPlanStatus.submitted.wire});
      list.upsert(saved);
      state.value = SectionState.data(saved);
      return PlanSaved(saved, submitted: saved.status == LessonPlanStatus.submitted);
    } catch (e) {
      final f = ActionFailure.from(e, what: 'submit this lesson plan', keep: 'Nothing was changed.');
      actionFailure.value = f;
      return PlanFailed(f);
    } finally {
      submitting.value = false;
    }
  }
}
