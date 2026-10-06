import 'package:get/get.dart';
import '../../../../core/models/assessments/assessment_models.dart';
import '../../../../core/services/assessment_repository.dart';
import '../../../../core/utils/assessment_scope.dart';
import '../../../../core/utils/roster_scope.dart';
import '../../../common/action_failure.dart';
import '../../home/models/section_state.dart';
import 'assessments_controller.dart';

sealed class RemarksResult {
  const RemarksResult();
}

class RemarksSaved extends RemarksResult {
  const RemarksSaved();
}

class RemarksInvalid extends RemarksResult {
  final String message;
  const RemarksInvalid(this.message);
}

class RemarksFailed extends RemarksResult {
  final ActionFailure failure;
  const RemarksFailed(this.failure);
}

class RemarksIgnored extends RemarksResult {
  const RemarksIgnored();
}

/// Class-teacher remarks on report cards (`/assessments/report-remarks?assessmentId=`).
///
/// Which cards: `GET /assessments/report-cards?assessmentId=` is schoolSlug-only (assessment.service.ts:1695-1711), so the app keeps only the
/// cards of MY class-teacher class. Only `classTeacherRemarks` is ever written (`PATCH report-cards/:id/remarks`, UpdateReportCardRemarksDto,
/// assessment.dto.ts:196-199); `principalRemarks` is shown read-only and never sent. PUBLISHED cards are read-only in the app (the server
/// would accept the edit). NOT built: generate, publish.
class ReportRemarksController extends GetxController {
  static const int maxLength = 500;

  final AssessmentRepository? _repo;
  final AssessmentsController? _list;
  final String? initialAssessmentId;

  ReportRemarksController({AssessmentRepository? repository, AssessmentsController? list, this.initialAssessmentId})
      : _repo = repository,
        _list = list;

  AssessmentRepository get repo => _repo ?? Get.find<AssessmentRepository>();
  AssessmentsController get list => _list ?? Get.find<AssessmentsController>();

  /// Assessments whose report cards exist (generated) for a class I am the class teacher of.
  final candidates = <Assessment>[].obs;
  final selectedId = RxnString();
  final state = Rx<SectionState<List<ReportCard>>>(const SectionState.loading());
  final truncated = false.obs;

  /// Card ids with a save in flight.
  final saving = <String>{}.obs;
  int _token = 0;

  bool get isClassTeacher => list.isClassTeacher;
  Assessment? get selected {
    final id = selectedId.value;
    for (final a in candidates) {
      if (a.id == id) return a;
    }
    return null;
  }

  List<ClassRef> get _myClassTeacherClasses {
    final a = selected;
    return a == null ? const [] : myClassTeacherClassesFor(a, list.myClasses);
  }

  List<ReportCard> get cards => state.value.data ?? const [];

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
    if (ls.status == SectionStatus.error) {
      state.value = SectionState.error(ls.message ?? "Couldn't load your assessments.");
      return;
    }
    candidates.value = [for (final a in list.items) if (a.gradeCardsGenerated && myClassTeacherClassesFor(a, list.myClasses).isNotEmpty) a];
    if (candidates.isEmpty) {
      state.value = const SectionState.empty();
      return;
    }
    final want = selectedId.value ?? initialAssessmentId;
    selectedId.value = candidates.any((a) => a.id == want) ? want : candidates.first.id;
    await _loadCards();
  }

  Future<void> select(String id) async {
    if (id == selectedId.value) return;
    selectedId.value = id;
    await _loadCards();
  }

  Future<void> _loadCards() async {
    final a = selected;
    if (a == null) return;
    final token = ++_token;
    state.value = const SectionState.loading();
    try {
      final all = await repo.reportCards(a.id);
      if (token != _token) return;
      truncated.value = all.truncated;
      final classes = _myClassTeacherClasses;
      final mine = [for (final c in all.items) if (classes.any((cls) => isCardOfClass(c, cls))) c]
        ..sort((x, y) => (x.classPosition ?? 1 << 30).compareTo(y.classPosition ?? 1 << 30));
      state.value = mine.isEmpty ? const SectionState.empty() : SectionState.data(mine);
    } catch (e) {
      if (token != _token) return;
      state.value = SectionState<List<ReportCard>>.fromError(e);
    }
  }

  Future<void> reload() => load(force: true);

  bool canEdit(ReportCard c) => !c.published && isClassTeacher;

  /// Saves [text] as the class-teacher remarks of [card]. Blank text is allowed (clears the remarks). One request per card at a time.
  Future<RemarksResult> saveRemarks(ReportCard card, String text) async {
    if (!canEdit(card) || saving.contains(card.id)) return const RemarksIgnored();
    final t = text.trim();
    if (t.length > maxLength) return const RemarksInvalid('Remarks can be up to $maxLength characters.');
    saving.add(card.id);
    try {
      final saved = await repo.saveRemarks(card.id, t);
      final next = [for (final c in cards) c.id == card.id ? c.withClassTeacherRemarks(saved.classTeacherRemarks) : c];
      state.value = SectionState.data(next);
      return const RemarksSaved();
    } catch (e) {
      return RemarksFailed(ActionFailure.from(e, what: 'save these remarks', keep: 'Your text is kept.'));
    } finally {
      saving.remove(card.id);
    }
  }
}
