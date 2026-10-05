import 'package:get/get.dart';
import '../../../../core/models/homework/homework_models.dart';
import '../../../../core/services/homework_repository.dart';
import '../../../common/action_failure.dart';
import '../../home/models/section_state.dart';
import 'homework_controller.dart';
import 'homework_detail_controller.dart';

enum SubmissionFilter { all, toGrade, graded, notHandedIn }

extension SubmissionFilterLabel on SubmissionFilter {
  String get label => switch (this) {
        SubmissionFilter.all => 'All',
        SubmissionFilter.toGrade => 'To grade',
        SubmissionFilter.graded => 'Graded',
        SubmissionFilter.notHandedIn => 'Not handed in',
      };
}

sealed class GradeOutcome {
  const GradeOutcome();
}

class GradeSaved extends GradeOutcome {
  final Submission submission;
  const GradeSaved(this.submission);
}

class GradeInvalid extends GradeOutcome {
  final String message;
  const GradeInvalid(this.message);
}

class GradeFailed extends GradeOutcome {
  final ActionFailure failure;
  const GradeFailed(this.failure);
}

class GradeIgnored extends GradeOutcome {
  const GradeIgnored();
}

/// Submissions of one assignment (`/homework/:id/submissions`) and grading (`.../:sid/grade`). The API returns the WHOLE roster snapshot
/// (`pending` / `missed` rows are students who have not handed anything in), so "not handed in" is available.
class SubmissionsController extends GetxController {
  final String assignmentId;
  final HomeworkRepository? _repo;
  final HomeworkController? _list;
  final UrlOpener _open;

  SubmissionsController({required this.assignmentId, HomeworkRepository? repository, HomeworkController? list, UrlOpener? opener})
      : _repo = repository,
        _list = list,
        _open = opener ?? defaultUrlOpener;

  HomeworkRepository get repo => _repo ?? Get.find<HomeworkRepository>();
  HomeworkController? get list => _list ?? (Get.isRegistered<HomeworkController>() ? Get.find<HomeworkController>() : null);

  final state = Rx<SectionState<SubmissionsResult>>(const SectionState.loading());
  final filter = SubmissionFilter.all.obs;

  /// Id of the submission being saved (double-submit guard).
  final savingId = RxnString();
  final openingKey = RxnString();
  int _token = 0;

  Assignment? get assignment => state.value.data?.assignment;
  List<Submission> get all => state.value.data?.submissions ?? const [];

  List<Submission> get visible {
    final f = filter.value;
    return [
      for (final s in all)
        if (switch (f) {
          SubmissionFilter.all => true,
          SubmissionFilter.toGrade => s.needsGrading,
          SubmissionFilter.graded => s.isGraded,
          SubmissionFilter.notHandedIn => s.notSubmitted,
        })
          s
    ];
  }

  int countFor(SubmissionFilter f) => switch (f) {
        SubmissionFilter.all => all.length,
        SubmissionFilter.toGrade => all.where((s) => s.needsGrading).length,
        SubmissionFilter.graded => all.where((s) => s.isGraded).length,
        SubmissionFilter.notHandedIn => all.where((s) => s.notSubmitted).length,
      };

  Submission? byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Only rows with work handed in can be graded (or re-graded) in the app. The server would also accept marks for a student who
  /// handed nothing in (teaching.service.ts:1004-1027 has no status check); the app does not offer it.
  bool canGrade(Submission s) => s.needsGrading || s.isGraded;

  @override
  void onReady() {
    super.onReady();
    load();
  }

  void setFilter(SubmissionFilter f) => filter.value = f;

  Future<void> load({bool force = false}) async {
    if (!force && state.value.hasData) return;
    final token = ++_token;
    if (!state.value.hasData) state.value = const SectionState.loading();
    try {
      final res = await repo.fetchSubmissions(assignmentId);
      if (token != _token) return;
      state.value = res.submissions.isEmpty && res.assignment.isDraft ? const SectionState.empty() : SectionState.data(res);
    } catch (e) {
      if (token != _token) return;
      state.value = SectionState<SubmissionsResult>.fromError(e);
    }
  }

  Future<void> reload() => load(force: true);

  /// Parses and checks marks like the server does: a number, 0 <= marks <= the submission's `maxGrade` (teaching.service.ts:1007-1009;
  /// DTO also caps at 1000, assignment.dto.ts:51). Returns null when valid.
  static String? validateMarks(String text, double max) {
    final t = text.trim();
    if (t.isEmpty) return 'Enter the marks';
    final v = double.tryParse(t);
    if (v == null || v.isNaN || v.isInfinite) return 'Marks must be a number';
    if (v < 0) return "Marks can't be below 0";
    if (v > max) return "Marks can't be more than ${max == max.roundToDouble() ? max.round() : max}";
    return null;
  }

  Future<GradeOutcome> grade(String submissionId, String marksText, String feedback) async {
    if (savingId.value != null) return const GradeIgnored();
    final s = byId(submissionId);
    if (s == null) return const GradeInvalid('This submission is no longer in the list.');
    if (!canGrade(s)) return const GradeInvalid('Nothing has been handed in yet, so there is nothing to grade.');
    final bad = validateMarks(marksText, s.maxGrade);
    if (bad != null) return GradeInvalid(bad);
    savingId.value = submissionId;
    try {
      final saved = await repo.grade(assignmentId, submissionId, grade: double.parse(marksText.trim()), feedback: feedback);
      _replace(saved);
      return GradeSaved(saved);
    } catch (e) {
      return GradeFailed(ActionFailure.from(e, what: 'save these marks', keep: 'Your marks are kept.'));
    } finally {
      savingId.value = null;
    }
  }

  void _replace(Submission saved) {
    final res = state.value.data;
    if (res == null) return;
    final rows = [for (final r in res.submissions) r.id == saved.id ? saved : r];
    final handedIn = rows.where((r) => r.needsGrading || r.isGraded).length;
    final a = res.assignment.copyWith(submissionsCount: handedIn);
    state.value = SectionState.data(SubmissionsResult(a, rows));
    final l = list;
    if (l != null && l.byId(a.id) != null) l.upsert(l.byId(a.id)!.copyWith(submissionsCount: handedIn));
  }

  Future<ActionFailure?> openAttachment(String key) async {
    if (openingKey.value != null) return null;
    openingKey.value = key;
    try {
      final url = await repo.signedUrl(key);
      final ok = await _open(Uri.parse(url));
      return ok ? null : const ActionFailure(ActionFailureKind.other, "Couldn't open this file on your device.");
    } catch (e) {
      return ActionFailure.from(e, what: 'open this file', keep: '');
    } finally {
      openingKey.value = null;
    }
  }
}
