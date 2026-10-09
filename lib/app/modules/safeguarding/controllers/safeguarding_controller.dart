import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../../core/models/classroom/student_models.dart';
import '../../../../core/models/safeguarding/safeguarding_models.dart';
import '../../../../core/services/safeguarding_repository.dart';
import '../../../../core/services/students_repository.dart';
import '../../../../core/utils/home_time.dart' show Clock;
import '../../../../core/utils/roster_scope.dart';
import '../../../../core/utils/timetable_week.dart' show dateOnly;
import '../../../common/action_failure.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/models/section_state.dart';

sealed class ConcernResult {
  const ConcernResult();
}

class ConcernSent extends ConcernResult {
  final String? reference;
  const ConcernSent(this.reference);
}

class ConcernInvalid extends ConcernResult {
  final Map<String, String> errors;
  const ConcernInvalid(this.errors);
}

class ConcernFailed extends ConcernResult {
  final ActionFailure failure;
  const ConcernFailed(this.failure);
}

class ConcernIgnored extends ConcernResult {
  const ConcernIgnored();
}

/// Raise a concern (`/safeguarding`, WRITE ONLY). PRIVACY: what the teacher types lives only in this controller's text controllers and Rx fields.
/// It is never written to disk / SharedPreferences / logs / analytics, is cleared the moment the report is sent AND when the screen closes ([wipe],
/// [onClose]), and no list of cases exists anywhere in the app. The student picker only offers students of MY classes; "not about a specific
/// student" is allowed (studentId is optional in the schema).
class SafeguardingController extends GetxController {
  final SafeguardingRepository? _repo;
  final StudentsRepository? _students;
  final AuthController? _auth;
  final Clock clock;

  SafeguardingController({SafeguardingRepository? repository, StudentsRepository? students, AuthController? auth, Clock? clock})
      : _repo = repository,
        _students = students,
        _auth = auth,
        clock = clock ?? DateTime.now;

  SafeguardingRepository get repo => _repo ?? Get.find<SafeguardingRepository>();
  StudentsRepository get students => _students ?? Get.find<StudentsRepository>();
  AuthController get auth => _auth ?? Get.find<AuthController>();

  DateTime get today => dateOnly(clock());
  late final DateTime _openedOn = today;

  final titleC = TextEditingController();
  final descriptionC = TextEditingController();
  final actionsC = TextEditingController();
  final type = Rxn<ConcernType>();
  final severity = ConcernSeverity.medium.obs;
  late final Rx<DateTime> day = Rx<DateTime>(_openedOn);
  final student = Rxn<StudentSummary>();
  final errors = <String, String>{}.obs;
  final sending = false.obs;
  final failure = Rxn<ActionFailure>();

  /// Set when the report was sent: the screen switches to the "Report sent" view. Holds NOTHING of the concern (only the optional reference).
  final sent = false.obs;
  final reference = RxnString();

  // ── picker (my classes only) ────────────────────────────────
  final pickerClass = 0.obs;
  final pickerQuery = ''.obs;
  final rosters = <String, SectionState<List<StudentSummary>>>{}.obs;
  GradesSections? _known;
  bool _knownTried = false;
  final _tokens = <String, int>{};

  List<ClassRef> get classes {
    auth.staffMe.value;
    return teacherClassesOf(auth.staffMe.value?.teacherProfile);
  }

  ClassRef? get pickerCurrent {
    final cs = classes;
    if (cs.isEmpty) return null;
    return cs[pickerClass.value.clamp(0, cs.length - 1)];
  }

  SectionState<List<StudentSummary>> get pickerState {
    final c = pickerCurrent;
    if (c == null) return const SectionState.empty();
    return rosters[c.key] ?? const SectionState.loading();
  }

  List<StudentSummary> get pickerVisible {
    final all = pickerState.data ?? const <StudentSummary>[];
    final q = pickerQuery.value.trim().toLowerCase();
    if (q.isEmpty) return all;
    return [
      for (final s in all)
        if (s.fullName.toLowerCase().contains(q) || (s.preferredName ?? '').toLowerCase().contains(q) || (s.rollNumber ?? '') == q || (s.grNo ?? '').toLowerCase().contains(q)) s
    ];
  }

  void selectPickerClass(int i) {
    if (i == pickerClass.value) return;
    pickerClass.value = i;
    pickerQuery.value = '';
    loadPickerClass();
  }

  Future<void> loadPickerClass({bool force = false}) async {
    final c = pickerCurrent;
    if (c == null) return;
    final existing = rosters[c.key];
    if (!force && existing != null && (existing.hasData || existing.status == SectionStatus.empty)) return;
    final token = (_tokens[c.key] ?? 0) + 1;
    _tokens[c.key] = token;
    rosters[c.key] = const SectionState.loading();
    try {
      if (!_knownTried) {
        _knownTried = true;
        try {
          _known = await students.fetchGradesSections();
        } catch (_) {
          _known = null;
        }
      }
      final list = await students.fetchClassRoster(c, known: _known);
      if (_tokens[c.key] != token) return;
      rosters[c.key] = list.isEmpty ? const SectionState.empty() : SectionState.data(list);
    } catch (e) {
      if (_tokens[c.key] != token) return;
      rosters[c.key] = SectionState<List<StudentSummary>>.fromError(e);
    }
  }

  void selectStudent(StudentSummary s) {
    student.value = s;
    errors.remove('student');
  }

  void clearStudent() {
    student.value = null;
    errors.remove('student');
  }

  void setType(ConcernType t) {
    type.value = t;
    errors.remove('type');
  }

  void setSeverity(ConcernSeverity s) => severity.value = s;

  void setDay(DateTime d) {
    final x = dateOnly(d);
    day.value = x.isAfter(today) ? today : x;
  }

  /// Field errors keyed `title|type|description|student`; empty = valid.
  Map<String, String> validate() {
    final e = <String, String>{};
    if (type.value == null) e['type'] = 'Choose what kind of concern this is';
    if (titleC.text.trim().isEmpty) e['title'] = 'Add a short summary';
    if (descriptionC.text.trim().isEmpty) e['description'] = 'Describe what you saw or heard';
    final s = student.value;
    if (s != null && !inAnyClass(s, classes)) e['student'] = 'This student is not in one of your classes';
    return e;
  }

  SafeguardingReport? get report {
    final t = type.value;
    if (t == null) return null;
    return SafeguardingReport(title: titleC.text, description: descriptionC.text, type: t, severity: severity.value, day: day.value, actionsTaken: actionsC.text, student: student.value);
  }

  /// Dirty as soon as anything the teacher entered differs from the pristine form (typed text, even spaces; a kind; another severity / day; a student).
  bool get isDirty =>
      titleC.text.isNotEmpty || descriptionC.text.isNotEmpty || actionsC.text.isNotEmpty || type.value != null || student.value != null || severity.value != ConcernSeverity.medium || day.value != _openedOn;

  /// Validates, then sends ONCE. A second call while a send is in flight (double tap) is ignored. On success everything typed is wiped at once. On
  /// failure the form is kept exactly as it was.
  Future<ConcernResult> submit() async {
    if (sending.value || sent.value) return const ConcernIgnored();
    final problems = validate();
    errors.assignAll(problems);
    final r = report;
    if (problems.isNotEmpty || r == null) return ConcernInvalid(problems);
    sending.value = true;
    failure.value = null;
    try {
      final receipt = await repo.submit(r);
      reference.value = receipt.reference;
      wipe();
      sent.value = true;
      return ConcernSent(receipt.reference);
    } catch (e) {
      final f = ActionFailure.from(e, what: 'send this concern', keep: 'What you wrote is still here.');
      failure.value = f;
      return ConcernFailed(f);
    } finally {
      sending.value = false;
    }
  }

  /// Drops every piece of the concern from memory.
  void wipe() {
    titleC.clear();
    descriptionC.clear();
    actionsC.clear();
    type.value = null;
    severity.value = ConcernSeverity.medium;
    student.value = null;
    errors.clear();
    failure.value = null;
    pickerQuery.value = '';
    rosters.clear();
  }

  @override
  void onClose() {
    wipe();
    titleC.dispose();
    descriptionC.dispose();
    actionsC.dispose();
    super.onClose();
  }
}
