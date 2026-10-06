import 'dart:math' as math;
import 'package:get/get.dart';
import '../../../../core/models/assessments/assessment_models.dart';
import '../../../../core/models/classroom/student_models.dart';
import '../../../../core/services/assessment_repository.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/services/students_repository.dart';
import '../../../../core/utils/assessment_scope.dart';
import '../../../../core/utils/class_match.dart';
import '../../../../core/utils/roster_scope.dart';
import '../../../common/action_failure.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/models/section_state.dart';
import 'assessments_controller.dart';

/// One student line of the grid. Immutable: the controller replaces rows on every edit.
class MarkEntryRow {
  final StudentSummary student;

  /// As loaded from / last saved to the server (null = nothing entered yet).
  final MarkRecord? saved;
  final String text;
  final bool absent;
  final bool exempt;
  final String remarks;

  /// Read-only row: verified by a coordinator (the server does NOT lock it, assessment.service.ts:1239-1299) or written by the online quiz.
  final bool locked;
  final String? lockReason;

  /// A message the SERVER sent for this row (validation index), cleared when the row is edited.
  final String? serverError;

  const MarkEntryRow({required this.student, this.saved, this.text = '', this.absent = false, this.exempt = false, this.remarks = '', this.locked = false, this.lockReason, this.serverError});

  factory MarkEntryRow.fromSaved(StudentSummary s, MarkRecord? m) {
    final verified = m?.verified ?? false;
    final quiz = m?.fromOnlineQuiz ?? false;
    return MarkEntryRow(
      student: s,
      saved: m,
      text: m?.obtainedMarks != null && !(m?.isAbsent ?? false) && !(m?.isExempt ?? false) ? marksText(m!.obtainedMarks!) : '',
      absent: m?.isAbsent ?? false,
      exempt: m?.isExempt ?? false,
      remarks: m?.remarks ?? '',
      locked: verified || quiz,
      lockReason: verified ? 'Verified by your school: locked' : quiz ? 'Marked by the online quiz: locked' : null,
    );
  }

  MarkEntryRow copyWith({String? text, bool? absent, bool? exempt, String? remarks, Object? serverError = _keep}) => MarkEntryRow(
        student: student,
        saved: saved,
        text: text ?? this.text,
        absent: absent ?? this.absent,
        exempt: exempt ?? this.exempt,
        remarks: remarks ?? this.remarks,
        locked: locked,
        lockReason: lockReason,
        serverError: identical(serverError, _keep) ? this.serverError : serverError as String?,
      );

  MarkEntryRow savedAs(MarkRecord m) => MarkEntryRow.fromSaved(student, m);

  static const Object _keep = Object();
  static final RegExp _decimal = RegExp(r'^\d+([.,]\d{0,2})?$|^[.,]\d{1,2}$');

  String get _trimmed => text.trim();

  /// The typed number (null when blank or not a number).
  double? get value {
    if (_trimmed.isEmpty) return null;
    return double.tryParse(_trimmed.replaceAll(',', '.'));
  }

  bool get hasInput => _trimmed.isNotEmpty || absent || exempt;

  /// Changed since it was loaded / saved?
  bool get isDirty {
    final s = saved;
    if (s == null) return hasInput || remarks.trim().isNotEmpty;
    final savedText = s.obtainedMarks != null && !s.isAbsent && !s.isExempt ? marksText(s.obtainedMarks!) : '';
    final num1 = value, num0 = savedText.isEmpty ? null : s.obtainedMarks;
    final sameNumber = (num1 == null && num0 == null) || (num1 != null && num0 != null && (num1 - num0).abs() < 0.0001);
    return !(sameNumber && absent == s.isAbsent && exempt == s.isExempt && remarks.trim() == s.remarks.trim());
  }

  /// Client-side validation (the server checks only `>= 0` and types, assessment.dto.ts:150-159, NOT the total).
  String? validate(double total) {
    if (locked) return null;
    if (!isDirty) return null;
    if (absent || exempt) return null;
    if (_trimmed.isEmpty) {
      if (saved?.hasEntry ?? false) return "A saved mark can't be cleared. Enter a mark or mark absent / exempt.";
      if (remarks.trim().isNotEmpty) return 'Enter marks or mark absent / exempt.';
      return null;
    }
    if (!_decimal.hasMatch(_trimmed)) return _trimmed.contains(RegExp(r'[.,]\d{3,}')) ? 'Use at most 2 decimals.' : 'Enter a number.';
    final v = value;
    if (v == null) return 'Enter a number.';
    if (v < 0) return "Marks can't be negative.";
    if (v > total) return "Can't be more than ${marksText(total)}.";
    if (remarks.trim().length > 200) return 'Remarks are too long (200 characters at most).';
    return null;
  }

  /// A mark ALREADY on the server that breaks the rule the server does not enforce (above the total): shown, never silently fixed.
  String? warning(double total) {
    final v = saved?.obtainedMarks;
    if (v != null && !(saved?.isAbsent ?? false) && !(saved?.isExempt ?? false) && v > total) return 'Saved mark ${marksText(v)} is above the total (${marksText(total)}). Please correct it.';
    return null;
  }

  MarkWrite toWrite() => MarkWrite(
        studentId: student.id,
        studentName: student.fullName,
        rollNumber: student.rollNumber ?? '',
        section: student.section,
        obtainedMarks: absent || exempt ? null : value,
        isAbsent: absent,
        isExempt: exempt,
        remarks: remarks.trim(),
      );
}

/// The numbers shown before saving (over the WHOLE sheet, entered or saved).
class MarksSummary {
  final int students;
  final int entered;
  final int absent;
  final int exempt;
  final int notEntered;
  final double? average;
  final double? lowest;
  final double? highest;
  final int belowPass;
  final double total;
  const MarksSummary({required this.students, required this.entered, required this.absent, required this.exempt, required this.notEntered, this.average, this.lowest, this.highest, this.belowPass = 0, this.total = 0});

  double? get averagePercent => average == null || total <= 0 ? null : average! / total * 100;
}

sealed class MarksSaveResult {
  const MarksSaveResult();
}

class MarksSaved extends MarksSaveResult {
  final int count;
  const MarksSaved(this.count);
}

class MarksSaveFailed extends MarksSaveResult {
  final ActionFailure failure;
  const MarksSaveFailed(this.failure);
}

class MarksSaveIgnored extends MarksSaveResult {
  const MarksSaveIgnored();
}

class MarksNothingToSave extends MarksSaveResult {
  const MarksNothingToSave();
}

class MarksInvalid extends MarksSaveResult {
  final int count;
  const MarksInvalid(this.count);
}

/// Marks entry for ONE subject of ONE assessment (`/assessments/:id/marks?subject=&section=`).
///
/// Loads the roster of my class (reusing the 5a roster scoping: pages of 200, tolerant grade/section match, active students only) and the
/// existing marks (`GET /assessments/marks/list`, all pages), lets me enter `obtainedMarks` / absent / exempt / remarks per student and saves with
/// `POST /assessments/marks/bulk` (ONE endpoint, no draft / submit distinction in the DTO: assessment.dto.ts:161-171, so one "Save").
///
/// INTEGRITY the server does NOT provide (assessment.service.ts:1239-1299; hardening backlog Critical #5) and the app therefore enforces:
///  * 0 <= marks <= totalMarks per student (the server accepts any number >= 0);
///  * rows with `verified: true` are read-only and never sent (the server would overwrite them and keep them "verified");
///  * rows written by the online quiz are read-only; online-quiz subjects, results-published, cancelled and not-yet-started assessments
///    are read-only as a whole ([MarksAccess]); a subject I do not teach is view-only;
///  * only CHANGED rows are sent (a minimal overwrite surface), never a blind full-sheet write.
/// Still open on the server: no ownership / class check, no per-row version (last write wins), no way to clear a saved mark.
class MarksEntryController extends GetxController {
  final String assessmentId;
  final String subject;
  final String? initialSection;
  final AssessmentRepository? _repo;
  final StudentsRepository? _students;
  final AuthController? _auth;
  final PermissionService? _perms;

  MarksEntryController({required this.assessmentId, required this.subject, this.initialSection, AssessmentRepository? repository, StudentsRepository? students, AuthController? auth, PermissionService? permissions})
      : _repo = repository,
        _students = students,
        _auth = auth,
        _perms = permissions;

  AssessmentRepository get repo => _repo ?? Get.find<AssessmentRepository>();
  StudentsRepository get students => _students ?? Get.find<StudentsRepository>();
  AuthController get auth => _auth ?? Get.find<AuthController>();
  PermissionService get perms => _perms ?? Get.find<PermissionService>();

  final state = Rx<SectionState<List<MarkEntryRow>>>(const SectionState.loading());
  final assessment = Rxn<Assessment>();
  final access = MarksAccess.editable.obs;

  /// Classes I can open this sheet for (an all-sections assessment taught in several sections has several).
  final classes = <ClassRef>[].obs;
  final selected = 0.obs;

  /// The Save button was pressed once: errors are shown on every invalid row from now on.
  final showErrors = false.obs;
  final saving = false.obs;
  final saveFailure = Rxn<ActionFailure>();
  final marksTruncated = false.obs;
  final lastSavedCount = 0.obs;

  /// Bumped on every edit (cheap trigger for the summary / footer).
  final revision = 0.obs;
  int _token = 0;

  List<MarkEntryRow> get rows => state.value.data ?? const [];
  ClassRef? get currentClass => classes.isEmpty ? null : classes[selected.value.clamp(0, classes.length - 1)];
  AssessmentSubject? get subjectConfig => assessment.value?.subjectNamed(subject);
  double get total => subjectConfig?.totalMarks ?? 0;
  double get passing => subjectConfig?.passingMarks ?? 0;
  bool get canView {
    auth.staffMe.value;
    return perms.canAccess('assessments:view');
  }

  bool get editable => access.value.canEdit;
  int get lockedCount => rows.where((r) => r.locked).length;
  bool get allLocked => rows.isNotEmpty && rows.every((r) => r.locked);

  /// There is something to type into.
  bool get canEnter => editable && rows.any((r) => !r.locked);

  Iterable<MarkEntryRow> get dirtyRows => rows.where((r) => !r.locked && r.isDirty);
  bool get hasUnsavedChanges => dirtyRows.isNotEmpty;
  int get dirtyCount => dirtyRows.length;

  String? errorOf(MarkEntryRow r) => r.serverError ?? r.validate(total);
  List<MarkEntryRow> get invalidRows => dirtyRows.where((r) => errorOf(r) != null).toList();

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
    final token = ++_token;
    if (!state.value.hasData) state.value = const SectionState.loading();
    try {
      final a = assessment.value != null && !force ? assessment.value! : await repo.assessment(assessmentId);
      if (token != _token) return;
      assessment.value = a;
      final cfg = a.subjectNamed(subject);
      if (cfg == null) {
        state.value = const SectionState.error("This subject isn't part of this assessment.");
        return;
      }
      final myCls = teacherClassesOf(auth.staffMe.value?.teacherProfile);
      var cl = rosterClassesFor(a, subject, myCls);
      final teaches = cl.isNotEmpty;
      if (!teaches) {
        // not my subject: the class teacher of the class may view the sheet (read-only)
        cl = [for (final c in myClassTeacherClassesFor(a, myCls)) ClassRef(grade: c.grade, section: a.section.isNotEmpty ? a.section : c.section, isClassTeacherClass: true, subjects: c.subjects)];
      }
      if (cl.isEmpty) {
        state.value = const SectionState.error("This assessment isn't one of yours.");
        return;
      }
      access.value = marksAccessFor(a, cfg, iTeachIt: teaches);
      classes.value = cl;
      if (initialSection != null && !force && selected.value == 0) {
        final i = cl.indexWhere((c) => sameSection(c.section, initialSection));
        if (i > 0) selected.value = i;
      }
      await _loadClass(token);
    } catch (e) {
      if (token != _token) return;
      state.value = SectionState<List<MarkEntryRow>>.fromError(e);
    }
  }

  Future<void> _loadClass(int token) async {
    final cls = currentClass!;
    GradesSections? known;
    try {
      known = await students.fetchGradesSections();
    } catch (_) {}
    final results = await Future.wait<Object>([students.fetchClassRoster(cls, known: known), repo.marks(assessmentId, subject)]);
    if (token != _token) return;
    final roster = results[0] as List<StudentSummary>;
    final marks = results[1] as AllPages<MarkRecord>;
    marksTruncated.value = marks.truncated;
    final byStudent = {for (final m in marks.items) m.studentId: m};
    final out = [for (final s in roster) MarkEntryRow.fromSaved(s, byStudent[s.id])];
    saveFailure.value = null;
    showErrors.value = false;
    revision.value++;
    state.value = out.isEmpty ? const SectionState.empty() : SectionState.data(out);
  }

  Future<void> reload() async {
    await auth.refreshProfile(force: true);
    await load(force: true);
  }

  /// Switches the class of an all-sections assessment. The caller confirms first when [hasUnsavedChanges].
  Future<void> selectClass(int i) async {
    if (i == selected.value || i < 0 || i >= classes.length) return;
    selected.value = i;
    state.value = const SectionState.loading();
    final token = ++_token;
    try {
      await _loadClass(token);
    } catch (e) {
      if (token != _token) return;
      state.value = SectionState<List<MarkEntryRow>>.fromError(e);
    }
  }

  // ── editing ─────────────────────────────────────────────────

  void _edit(String studentId, MarkEntryRow Function(MarkEntryRow) f) {
    if (!editable || saving.value) return;
    final list = [...rows];
    final i = list.indexWhere((r) => r.student.id == studentId);
    if (i < 0 || list[i].locked) return;
    list[i] = f(list[i]);
    state.value = SectionState.data(list);
    revision.value++;
    saveFailure.value = null;
  }

  /// Typing a number clears absent / exempt (a student cannot be both marked and absent).
  void setMarks(String studentId, String text) => _edit(studentId, (r) => r.copyWith(text: text, absent: false, exempt: false, serverError: null));

  void setAbsent(String studentId, bool v) => _edit(studentId, (r) => v ? r.copyWith(absent: true, exempt: false, text: '', serverError: null) : r.copyWith(absent: false, serverError: null));

  void setExempt(String studentId, bool v) => _edit(studentId, (r) => v ? r.copyWith(exempt: true, absent: false, text: '', serverError: null) : r.copyWith(exempt: false, serverError: null));

  void setRemarks(String studentId, String text) => _edit(studentId, (r) => r.copyWith(remarks: text, serverError: null));

  // ── summary ─────────────────────────────────────────────────

  /// Over the whole sheet: a number counts when it is valid; absent / exempt count separately; the rest are "not entered".
  MarksSummary summary() {
    var entered = 0, absent = 0, exempt = 0, below = 0;
    double sum = 0;
    double? lo, hi;
    for (final r in rows) {
      if (r.absent) {
        absent++;
      } else if (r.exempt) {
        exempt++;
      } else if (r.value != null && r.value! >= 0 && r.value! <= total) {
        final v = r.value!;
        entered++;
        sum += v;
        lo = lo == null ? v : math.min(lo, v);
        hi = hi == null ? v : math.max(hi, v);
        if (v < passing) below++;
      }
    }
    return MarksSummary(
      students: rows.length,
      entered: entered,
      absent: absent,
      exempt: exempt,
      notEntered: rows.length - entered - absent - exempt,
      average: entered == 0 ? null : sum / entered,
      lowest: lo,
      highest: hi,
      belowPass: below,
      total: total,
    );
  }

  // ── saving ──────────────────────────────────────────────────

  /// Step 1 of saving: validates. Returns [MarksInvalid] (errors now visible on the rows), [MarksNothingToSave], or null when the
  /// summary can be shown and [save] called.
  MarksSaveResult? review() {
    if (saving.value) return const MarksSaveIgnored();
    showErrors.value = true;
    revision.value++;
    if (!hasUnsavedChanges) return const MarksNothingToSave();
    final bad = invalidRows;
    if (bad.isNotEmpty) return MarksInvalid(bad.length);
    return null;
  }

  /// Step 2: `POST /assessments/marks/bulk` with the changed rows only. Double taps are ignored while a request is in flight. A failure keeps
  /// every typed value; [save] again resends the same rows (an upsert per student: resending is safe).
  Future<MarksSaveResult> save() async {
    if (saving.value) return const MarksSaveIgnored();
    final a = assessment.value;
    if (a == null || !editable) return const MarksNothingToSave();
    showErrors.value = true;
    final bad = invalidRows;
    if (bad.isNotEmpty) return MarksInvalid(bad.length);
    final sending = dirtyRows.toList();
    if (sending.isEmpty) return const MarksNothingToSave();
    saving.value = true;
    saveFailure.value = null;
    try {
      await repo.saveMarks(
        assessmentId: a.id,
        subject: subject,
        grade: a.grade,
        marks: [for (final r in sending) r.toWrite()],
        academicYear: a.academicYear,
      );
    } catch (e) {
      final f = ActionFailure.from(e, what: 'save these marks', keep: 'Your marks are kept.');
      saveFailure.value = f;
      _attachServerRowError(f, sending);
      saving.value = false;
      return MarksSaveFailed(f);
    }
    // success: mark the sent rows as saved, then re-read the server's copy (best effort)
    final sentIds = {for (final r in sending) r.student.id};
    state.value = SectionState.data([
      for (final r in rows)
        if (sentIds.contains(r.student.id))
          r.savedAs(MarkRecord(
            studentId: r.student.id,
            studentName: r.student.fullName,
            rollNumber: r.student.rollNumber ?? '',
            subject: subject,
            totalMarks: total,
            obtainedMarks: r.absent || r.exempt ? null : r.value,
            isAbsent: r.absent,
            isExempt: r.exempt,
            remarks: r.remarks.trim(),
          ))
        else
          r
    ]);
    lastSavedCount.value = sending.length;
    revision.value++;
    showErrors.value = false;
    saving.value = false;
    try {
      final fresh = await repo.marks(assessmentId, subject);
      final by = {for (final m in fresh.items) m.studentId: m};
      state.value = SectionState.data([for (final r in rows) by.containsKey(r.student.id) ? r.savedAs(by[r.student.id]!) : r]);
      revision.value++;
    } catch (_) {}
    return MarksSaved(sending.length);
  }

  /// "marks.3.obtainedMarks must not be less than 0" -> row 3 of what was sent (the server returns the FIRST message only, filters/sentry.filter.ts:43-48).
  void _attachServerRowError(ActionFailure f, List<MarkEntryRow> sent) {
    if (f.kind != ActionFailureKind.validation) return;
    final m = RegExp(r'marks\.(\d+)\.').firstMatch(f.message);
    if (m == null) return;
    final i = int.tryParse(m.group(1)!);
    if (i == null || i < 0 || i >= sent.length) return;
    final id = sent[i].student.id;
    state.value = SectionState.data([for (final r in rows) r.student.id == id ? r.copyWith(serverError: f.message) : r]);
  }

  /// Throws away every unsaved edit.
  Future<void> discardChanges() => load(force: true);
}
