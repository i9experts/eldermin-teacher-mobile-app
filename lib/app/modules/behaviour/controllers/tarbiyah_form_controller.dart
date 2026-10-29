import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../../core/models/behaviour/behaviour_models.dart';
import '../../../../core/models/classroom/student_models.dart';
import '../../../../core/services/behaviour_repository.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/utils/home_time.dart';
import '../../../../core/utils/timetable_week.dart' show dateOnly;
import '../../../common/action_failure.dart';
import '../../auth/controllers/auth_controller.dart';
import 'behaviour_student_controller.dart';

/// What the screen opens with: the student (already verified to be in one of MY classes by the caller), the school's programme, the periods this
/// student already has an assessment for, and, when editing, the assessment itself.
class TarbiyahFormArgs {
  final StudentSummary student;
  final CharacterSettings settings;
  final List<TarbiyahAssessment> existing;
  final TarbiyahAssessment? editing;
  const TarbiyahFormArgs({required this.student, this.settings = CharacterSettings.fallback, this.existing = const [], this.editing});
}

sealed class TarbiyahResult {
  const TarbiyahResult();
}

class TarbiyahSaved extends TarbiyahResult {
  final TarbiyahAssessment assessment;
  const TarbiyahSaved(this.assessment);
}

class TarbiyahInvalid extends TarbiyahResult {
  final Map<String, String> errors;
  const TarbiyahInvalid(this.errors);
}

class TarbiyahFailed extends TarbiyahResult {
  final ActionFailure failure;
  const TarbiyahFailed(this.failure);
}

class TarbiyahIgnored extends TarbiyahResult {
  const TarbiyahIgnored();
}

/// Create or edit a Tarbiyah assessment of ONE student of my classes (decision D3). The trait list and the rating scale come from the school's
/// character programme (`GET /behaviour/character-settings`); the server computes the overall score / rating and, for a teacher, stamps the author
/// and campus from the token. Rules the server also enforces: only students of my own classes (403), one assessment per student and period, only the
/// author (or a coordinator / admin) may edit. There is no "share with parent" switch yet: it waits for the backend `visibleToParent`.
class TarbiyahFormController extends GetxController {
  final TarbiyahFormArgs args;
  final BehaviourRepository? _repo;
  final AuthController? _auth;
  final PermissionService? _perms;
  final BehaviourStudentController? _student;
  final Clock clock;

  TarbiyahFormController({required this.args, BehaviourRepository? repository, AuthController? auth, PermissionService? permissions, BehaviourStudentController? studentList, Clock? clock})
      : _repo = repository,
        _auth = auth,
        _perms = permissions,
        _student = studentList,
        clock = clock ?? DateTime.now;

  BehaviourRepository get repo => _repo ?? Get.find<BehaviourRepository>();
  AuthController get auth => _auth ?? Get.find<AuthController>();
  PermissionService get perms => _perms ?? Get.find<PermissionService>();

  bool get isEditing => args.editing != null;
  StudentSummary get student => args.student;
  CharacterSettings get settings => args.settings;

  /// Traits offered, in the school's order (the built-in Tarbiyah traits when the programme has none).
  List<String> get traitKeys => (settings.traitLabels.isEmpty ? CharacterSettings.fallback.traitLabels : settings.traitLabels).keys.toList();
  int get scaleMin => settings.scaleMin;
  int get scaleMax => settings.scaleMax;
  List<int> get scaleChoices => [for (var i = scaleMin; i <= scaleMax; i++) i];

  DateTime get today => dateOnly(clock());

  final periodType = 'termly'.obs;
  final periodC = TextEditingController();
  late final Rx<DateTime> day = Rx<DateTime>(today);
  final scores = <String, int>{}.obs;
  final observationsC = TextEditingController();
  final strengthsC = TextEditingController();
  final improvementsC = TextEditingController();
  final saving = false.obs;
  final errors = <String, String>{}.obs;
  final failure = Rxn<ActionFailure>();

  late final String _initialSignature;

  bool get canWrite {
    auth.staffMe.value;
    return perms.canAccess('behaviour:manage');
  }

  /// Edit is for the author only (a teacher); the server answers 403 to anyone else.
  bool get mayEditThis {
    final e = args.editing;
    if (e == null) return true;
    return e.isMine(userId: auth.user.value?.id ?? '', userName: auth.user.value?.name ?? '');
  }

  @override
  void onInit() {
    super.onInit();
    final e = args.editing;
    if (e != null) {
      periodType.value = kTarbiyahPeriodTypes.contains(e.periodType) ? e.periodType : 'termly';
      periodC.text = e.period;
      day.value = e.day ?? today;
      for (final t in e.traits) {
        final s = t.score.round();
        if (s >= scaleMin && s <= scaleMax) scores[t.key] = s;
      }
      observationsC.text = e.teacherObservations;
      strengthsC.text = e.areasOfStrength.join('\n');
      improvementsC.text = e.areasForImprovement.join('\n');
    }
    _initialSignature = _signature();
  }

  @override
  void onClose() {
    periodC.dispose();
    observationsC.dispose();
    strengthsC.dispose();
    improvementsC.dispose();
    super.onClose();
  }

  String _signature() => [
        periodType.value,
        periodC.text.trim(),
        day.value.toIso8601String(),
        [for (final k in traitKeys) '$k=${scores[k] ?? ''}'].join(','),
        observationsC.text.trim(),
        linesOf(strengthsC.text).join('|'),
        linesOf(improvementsC.text).join('|'),
      ].join('#');

  bool get isDirty => _signature() != _initialSignature;

  void setPeriodType(String t) {
    if (!kTarbiyahPeriodTypes.contains(t)) return;
    periodType.value = t;
    errors.remove('period');
  }

  void setDay(DateTime d) {
    day.value = dateOnly(d);
    errors.remove('day');
  }

  /// Tapping the selected score again clears the trait (a trait left unscored is not sent).
  void setScore(String key, int score) {
    if (score < scaleMin || score > scaleMax) return;
    if (scores[key] == score) {
      scores.remove(key);
    } else {
      scores[key] = score;
    }
    errors.remove('traits');
  }

  /// What the server will store as the average, for a live preview only (the server's own figure is the one kept).
  double? get previewAverage => scores.isEmpty ? null : scores.values.reduce((a, b) => a + b) / scores.length;

  /// A period this student already has an assessment for (the server allows one per student and period; a duplicate is a server error).
  bool _periodTaken(String period) {
    final p = period.trim().toLowerCase();
    return args.existing.any((a) => a.id != args.editing?.id && a.period.trim().toLowerCase() == p);
  }

  Map<String, String> validate() {
    final e = <String, String>{};
    final period = periodC.text.trim();
    if (period.isEmpty) {
      e['period'] = 'Enter the period, for example "Term 1 2025-26".';
    } else if (period.length > 100) {
      e['period'] = 'The period is too long (100 characters at most).';
    } else if (_periodTaken(period)) {
      e['period'] = 'This student already has an assessment for "$period". Open it and choose Edit instead.';
    }
    if (day.value.isAfter(today)) e['day'] = "The date can't be in the future.";
    if (scores.isEmpty) e['traits'] = 'Score at least one trait.';
    if (observationsC.text.trim().length > 2000) e['observations'] = 'Observations are too long (2000 characters at most).';
    return e;
  }

  TarbiyahDraft toDraft() => TarbiyahDraft(
        periodType: periodType.value,
        period: periodC.text,
        day: day.value,
        // in the school's trait order; only scored traits are sent
        scores: {for (final k in traitKeys) if (scores[k] != null) k: scores[k]!},
        observations: observationsC.text,
        strengths: linesOf(strengthsC.text),
        improvements: linesOf(improvementsC.text),
      );

  Future<TarbiyahResult> submit() async {
    if (saving.value) return const TarbiyahIgnored();
    if (!canWrite || !mayEditThis) return const TarbiyahIgnored();
    failure.value = null;
    final bad = validate();
    errors.assignAll(bad);
    if (bad.isNotEmpty) return TarbiyahInvalid(bad);
    saving.value = true;
    try {
      final d = toDraft();
      final saved = isEditing
          ? await repo.updateTarbiyah(args.editing!.id, d.toUpdateJson())
          : await repo.createTarbiyah(d.toCreateJson(studentId: student.id, studentName: student.fullName, grade: student.grade, section: student.section));
      _student?.upsertTarbiyah(saved);
      return TarbiyahSaved(saved);
    } catch (e) {
      final f = ActionFailure.from(e, what: isEditing ? 'save this assessment' : 'create this assessment');
      failure.value = f;
      return TarbiyahFailed(f);
    } finally {
      saving.value = false;
    }
  }
}
