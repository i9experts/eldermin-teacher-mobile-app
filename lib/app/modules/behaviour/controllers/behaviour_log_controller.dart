import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../../core/models/behaviour/behaviour_models.dart';
import '../../../../core/models/classroom/student_models.dart';
import '../../../../core/services/behaviour_repository.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/services/students_repository.dart';
import '../../../../core/utils/home_time.dart';
import '../../../../core/utils/roster_scope.dart';
import '../../../../core/utils/timetable_week.dart' show dateOnly;
import '../../../common/action_failure.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/models/section_state.dart';
import 'behaviour_controller.dart';

sealed class LogResult {
  const LogResult();
}

class LogSaved extends LogResult {
  final BehaviourRecord record;
  const LogSaved(this.record);
}

class LogInvalid extends LogResult {
  final Map<String, String> errors;
  const LogInvalid(this.errors);
}

class LogFailed extends LogResult {
  final ActionFailure failure;
  const LogFailed(this.failure);
}

class LogIgnored extends LogResult {
  const LogIgnored();
}

/// Quick log of a merit / demerit / note (`/behaviour/new`), and (T1) the EDIT of a record I logged (same screen, [editing] set).
///
/// Edit mode: the student is fixed (never changed through an edit), the form opens with the record's values, `Save` sends
/// `PUT /behaviour/records/:id` ([BehaviourDraft.toUpdateJson]); `parentNotified` is not offered (parents are notified when a
/// record is CREATED only). The author rule is enforced by the server (403 otherwise) and, before that, by the caller (the Edit
/// button only shows on records that are mine).
///
/// The student picker only offers students of MY classes (class chips + search, rosters from `GET /students` per class, re-scoped
/// client-side), never the whole campus. Points: merit +1..10, demerit -1..-10, note 0 (behaviour.schema.ts:67 "+ for positive,
/// - for negative"; no server validation). Submit is refused while a save is in flight; a failed save keeps every field.
class BehaviourLogController extends GetxController {
  final BehaviourRepository? _repo;
  final StudentsRepository? _students;
  final AuthController? _auth;
  final PermissionService? _perms;
  final BehaviourController? _list;
  final Clock clock;
  final StudentSummary? initialStudent;

  /// Set = edit this record instead of creating one.
  final BehaviourRecord? editing;

  BehaviourLogController({
    BehaviourRepository? repository,
    StudentsRepository? students,
    AuthController? auth,
    PermissionService? permissions,
    BehaviourController? list,
    Clock? clock,
    this.initialStudent,
    this.editing,
  })  : _repo = repository,
        _students = students,
        _auth = auth,
        _perms = permissions,
        _list = list,
        clock = clock ?? DateTime.now;

  BehaviourRepository get repo => _repo ?? Get.find<BehaviourRepository>();
  StudentsRepository get students => _students ?? Get.find<StudentsRepository>();
  AuthController get auth => _auth ?? Get.find<AuthController>();
  PermissionService get perms => _perms ?? Get.find<PermissionService>();
  BehaviourController? get list => _list ?? (Get.isRegistered<BehaviourController>() ? Get.find<BehaviourController>() : null);

  /// Point magnitudes offered.
  static const List<int> pointChoices = [1, 2, 3, 5, 10];

  /// The points magnitude the form opens with (part of the pristine state, see [isDirty]).
  static const int defaultMagnitude = 5;

  DateTime get today => dateOnly(clock());

  final kind = BehaviourKind.merit.obs;
  final student = Rxn<StudentSummary>();
  final category = RxnString();
  final severity = 'medium'.obs;
  final magnitude = defaultMagnitude.obs;
  late final DateTime _openedOn = today;
  late final Rx<DateTime> day = Rx<DateTime>(_openedOn);
  final titleC = TextEditingController();
  final descriptionC = TextEditingController();
  final locationC = TextEditingController();
  /// '' = none (the web sends nothing).
  final consequence = ''.obs;
  final parentNotified = false.obs;
  final followUpRequired = false.obs;
  final saving = false.obs;
  final errors = <String, String>{}.obs;
  final failure = Rxn<ActionFailure>();

  // ── picker state ────────────────────────────────────────────
  final pickerClass = 0.obs;
  final pickerQuery = ''.obs;
  final rosters = <String, SectionState<List<StudentSummary>>>{}.obs;
  GradesSections? _known;
  bool _knownTried = false;
  final _tokens = <String, int>{};
  String? _autoTitle;

  bool get canLog {
    auth.staffMe.value;
    return perms.canAccess('behaviour:manage');
  }

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

  /// The picker list: the current class's roster narrowed by the search text (name, preferred name, exact roll number, GR no).
  List<StudentSummary> get pickerVisible {
    final all = pickerState.data ?? const <StudentSummary>[];
    final q = pickerQuery.value.trim().toLowerCase();
    if (q.isEmpty) return all;
    return [
      for (final s in all)
        if (s.fullName.toLowerCase().contains(q) || (s.preferredName ?? '').toLowerCase().contains(q) || (s.rollNumber ?? '') == q || (s.grNo ?? '').toLowerCase().contains(q)) s
    ];
  }

  List<String> get categories => kBehaviourCategories[kind.value]!;

  int get points => switch (kind.value) {
        BehaviourKind.merit => magnitude.value,
        BehaviourKind.demerit => -magnitude.value,
        BehaviourKind.note => 0,
      };

  bool get isEditing => editing != null;

  /// The point magnitudes shown: the standard chips, plus the record's own magnitude in edit mode when it is not one of them.
  List<int> get magnitudeChoices {
    final m = editing?.points.abs();
    return [...pointChoices, if (m != null && m > 0 && !pointChoices.contains(m)) m]..sort();
  }

  String _original = '';

  @override
  void onInit() {
    super.onInit();
    final e = editing;
    if (e != null) {
      _prefill(e);
      _original = _snapshot();
      return; // edit: no picker, the student is fixed
    }
    final s = initialStudent;
    if (s != null && inAnyClass(s, classes, includeUnsectioned: true)) student.value = s; // a student outside my classes is never preselected
    loadPickerClass();
  }

  void _prefill(BehaviourRecord e) {
    kind.value = e.kind ?? BehaviourKind.note;
    category.value = e.category.isEmpty ? null : e.category;
    severity.value = kSeverities.contains(e.severity) ? e.severity : 'medium';
    magnitude.value = e.points == 0 ? defaultMagnitude : e.points.abs();
    day.value = e.day == null ? _openedOn : dateOnly(e.day!);
    titleC.text = e.title;
    descriptionC.text = e.description;
    locationC.text = e.location;
    consequence.value = e.consequence;
    followUpRequired.value = e.followUpRequired;
    parentNotified.value = e.parentNotified;
    student.value = StudentSummary(id: e.studentId, firstName: e.studentName, grade: e.grade, section: e.section);
  }

  @override
  void onClose() {
    titleC.dispose();
    descriptionC.dispose();
    locationC.dispose();
    super.onClose();
  }

  void setKind(BehaviourKind k) {
    if (k == kind.value) return;
    kind.value = k;
    category.value = null;
    errors.remove('category');
    if (_autoTitle != null && titleC.text == _autoTitle) titleC.clear();
    _autoTitle = null;
    if (k == BehaviourKind.demerit) severity.value = 'medium';
  }

  void setConsequence(String c) => consequence.value = consequence.value == c ? '' : c; // tap again = none
  void setParentNotified(bool v) => parentNotified.value = v;
  void setFollowUp(bool v) => followUpRequired.value = v;

  /// Picks a category and (when the title is still empty or the auto-filled one) fills the title with its label.
  void setCategory(String c) {
    category.value = c;
    errors.remove('category');
    if (titleC.text.trim().isEmpty || titleC.text == _autoTitle) {
      _autoTitle = categoryLabel(c);
      titleC.text = _autoTitle!;
      errors.remove('title');
    }
  }

  void setSeverity(String s) => severity.value = s;
  void setMagnitude(int m) => magnitude.value = m;

  void setDay(DateTime d) {
    final x = dateOnly(d);
    day.value = x.isAfter(today) ? today : x;
  }

  void selectStudent(StudentSummary s) {
    student.value = s;
    errors.remove('student');
  }

  void selectPickerClass(int i) {
    if (i == pickerClass.value) return;
    pickerClass.value = i;
    pickerQuery.value = '';
    loadPickerClass();
  }

  Future<void> loadPickerClass({bool force = false}) async {
    final c = pickerCurrent;
    if (c == null || !canLog) return;
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
      final list = await students.fetchClassRoster(c, known: _known, includeUnsectioned: true);
      if (_tokens[c.key] != token) return;
      rosters[c.key] = list.isEmpty ? const SectionState.empty() : SectionState.data(list);
    } catch (e) {
      if (_tokens[c.key] != token) return;
      rosters[c.key] = SectionState<List<StudentSummary>>.fromError(e);
    }
  }

  /// Field errors keyed `student|category|title|description`; empty = valid. (A bad body is a bare HTTP 500 on the server, so the
  /// app checks everything the mongoose schema requires.)
  Map<String, String> validate() {
    final e = <String, String>{};
    if (student.value == null) e['student'] = 'Choose a student';
    if (category.value == null) e['category'] = 'Choose a category';
    if (titleC.text.trim().isEmpty) e['title'] = 'Enter a title';
    if (descriptionC.text.trim().isEmpty) e['description'] = 'Describe what happened';
    final s = student.value;
    if (s != null && !isEditing) {
      if (s.grade.trim().isEmpty) {
        e['student'] = "This student has no grade on record, so the entry can't be saved";
      } else if (!inAnyClass(s, classes, includeUnsectioned: true)) {
        e['student'] = 'This student is not in one of your classes';
      }
    }
    return e;
  }

  BehaviourDraft? get draft {
    final s = student.value;
    final c = category.value;
    if (s == null || c == null) return null;
    return BehaviourDraft(
      student: s,
      kind: kind.value,
      category: c,
      title: titleC.text,
      description: descriptionC.text,
      severity: kind.value == BehaviourKind.demerit ? severity.value : 'low',
      points: points,
      day: day.value,
      reporterName: auth.user.value?.name ?? '',
      reporterId: auth.user.value?.id ?? '',
      consequence: consequence.value,
      location: locationC.text,
      parentNotified: parentNotified.value,
      followUpRequired: followUpRequired.value,
    );
  }

  Future<LogResult> submit() async {
    if (saving.value) return const LogIgnored();
    final problems = validate();
    final d = draft;
    final me = auth.user.value;
    if (me == null || me.id.isEmpty || me.name.isEmpty) problems['student'] = problems['student'] ?? "Your profile isn't loaded yet. Pull down on the previous screen to refresh.";
    errors.assignAll(problems);
    if (problems.isNotEmpty || d == null) return LogInvalid(problems);
    saving.value = true;
    failure.value = null;
    try {
      final BehaviourRecord saved;
      if (isEditing) {
        saved = await repo.update(editing!.id, d.toUpdateJson());
        list?.replaceRecord(saved);
      } else {
        saved = await repo.create(d.toJson());
        list?.addRecord(saved);
      }
      return LogSaved(saved);
    } catch (e) {
      final f = ActionFailure.from(e, what: 'save this entry');
      failure.value = f;
      return LogFailed(f);
    } finally {
      saving.value = false;
    }
  }

  /// One string of everything the form holds, to compare against the pristine / opened state.
  String _snapshot() => [
        kind.value.wire, student.value?.id ?? '', category.value ?? '', severity.value, magnitude.value, day.value.toIso8601String(),
        titleC.text, descriptionC.text, locationC.text, consequence.value, parentNotified.value, followUpRequired.value,
      ].join('\u0001');

  /// Unsaved-changes rule: the form is dirty as soon as ANY field differs from its pristine state. Pristine = kind merit, student = the
  /// preselected one (or none), no category, severity medium, points magnitude 5 (the defaults), day = today (as opened), title,
  /// description and location EMPTY, no consequence, parents not notified, no follow-up. So title only, description only, a picked student
  /// (other than the preselected one), a picked category, another kind / severity / points value, another day, a consequence, a
  /// location or a switch all count; typed text counts even when it is only spaces (the teacher did type); the picker's class chip
  /// and search box do not (they are navigation, not entry data). Back then shows 'Discard this entry?'. In edit mode the pristine state
  /// is the record as opened.
  bool get isDirty {
    if (isEditing) return _snapshot() != _original;
    return titleC.text.isNotEmpty ||
        descriptionC.text.isNotEmpty ||
        locationC.text.isNotEmpty ||
        category.value != null ||
        student.value?.id != initialStudent?.id ||
        kind.value != BehaviourKind.merit ||
        severity.value != 'medium' ||
        magnitude.value != defaultMagnitude ||
        day.value != _openedOn ||
        consequence.value.isNotEmpty ||
        parentNotified.value ||
        followUpRequired.value;
  }
}
