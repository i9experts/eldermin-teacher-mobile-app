import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../../../core/models/classroom/attendance_models.dart';
import '../../../../core/models/classroom/student_models.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/services/attendance_repository.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/services/students_repository.dart';
import '../../../../core/utils/home_time.dart';
import '../../../../core/utils/roster_scope.dart';
import '../../../../core/utils/timetable_week.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/controllers/home_dashboard_controller.dart';
import '../../home/models/section_state.dart';

/// Days back from today (inclusive) a class teacher may still mark / correct.
/// Chosen policy (NOT enforced by the backend, which accepts any date, even the
/// future: students.controller.ts:481-493 / students.service.ts:1810-1823; the web
/// has a free date picker): today plus the previous 7 days, never the future.
/// Reason: teachers do fix yesterday's slip, but a long open window invites
/// silent rewrites of the register. Set to 0 to make it "today only".
const int kAttendanceEditWindowDays = 7;

enum SubmitFailureKind { offline, forbidden, staleClass, notSchoolDay, conflict, validation, server, other }

/// The server's 400 prefix when the date is not a school day (students.service.ts: 'Cannot mark attendance: <reason>').
const String kNotSchoolDayPrefix = 'Cannot mark attendance:';

/// Banner text for a non-school day: the server reason verbatim.
String notSchoolDayText(String? reason) => 'No attendance today: ${reason == null || reason.isEmpty ? 'this is not a school day.' : reason}';

enum DayCheckKind { loading, valid, invalid, unknown }

/// Result of the school-day check for the (day, grade) on screen. Only [invalid] blocks marking.
class DayCheck {
  final DayCheckKind kind;
  final String? reason;
  const DayCheck._(this.kind, [this.reason]);
  static const loading = DayCheck._(DayCheckKind.loading);
  static const valid = DayCheck._(DayCheckKind.valid);
  static const unknown = DayCheck._(DayCheckKind.unknown);
  const DayCheck.invalid(String? reason) : this._(DayCheckKind.invalid, reason);
  bool get isInvalid => kind == DayCheckKind.invalid;
}

/// The backend's 403 when the token's class claims do not include the requested class (auth/scope.util.ts resolveClassSectionScope).
bool isClassScopeDenied(String message) => message.toLowerCase().contains('class teacher of your own assigned class');

class SubmitFailure {
  final SubmitFailureKind kind;
  final String message;
  const SubmitFailure(this.kind, this.message);

  /// Maps the real error shapes: `{statusCode, message, timestamp, path}` (sentry.filter.ts:43-48) -> a
  /// teacher-readable message. A null status code means no response at all (offline / timeout).
  factory SubmitFailure.from(Object e) {
    if (e is! ApiException) return const SubmitFailure(SubmitFailureKind.other, "Couldn't save attendance. Your marks are kept: try again.");
    final code = e.statusCode;
    switch (code) {
      case null:
        return SubmitFailure(SubmitFailureKind.offline, '${e.message} Your marks are kept: reconnect and tap Retry.');
      case 403:
        if (isClassScopeDenied(e.message)) return SubmitFailure(SubmitFailureKind.staleClass, kStaleClassMessage);
        return SubmitFailure(SubmitFailureKind.forbidden, "You can't mark attendance for this class. ${e.message}");
      case 409:
        return SubmitFailure(SubmitFailureKind.conflict, 'This day was changed or is locked on the server. ${e.message}');
      case 400:
        if (e.message.startsWith(kNotSchoolDayPrefix)) return SubmitFailure(SubmitFailureKind.notSchoolDay, e.message);
        return SubmitFailure(SubmitFailureKind.validation, 'The server rejected the attendance: ${e.message}');
      case 422:
        return SubmitFailure(SubmitFailureKind.validation, 'The server rejected the attendance: ${e.message}');
      default:
        if (code >= 500) {
          return const SubmitFailure(SubmitFailureKind.server, 'The server had a problem. Your marks are kept: try again.');
        }
        return SubmitFailure(SubmitFailureKind.other, e.message);
    }
  }
}

/// What the stale-sign-in banner says for [label] (a class assigned after the teacher signed in).
String staleClassText(String label) => 'Your sign-in predates your new class. Sign out and back in to mark $label.';

/// Generic form of [staleClassText] for the failure message (the screen shows the class-specific text).
const String kStaleClassMessage = 'Your sign-in predates your new class. Sign out and back in to mark it.';

/// Outcome of [AttendanceController.submit].
sealed class SubmitResult {
  const SubmitResult();
}

class SubmitSaved extends SubmitResult {
  final StatusCounts counts;
  const SubmitSaved(this.counts);
}

class SubmitBlocked extends SubmitResult {
  final int notMarked;
  const SubmitBlocked(this.notMarked);
}

class SubmitFailed extends SubmitResult {
  final SubmitFailure failure;
  const SubmitFailed(this.failure);
}

class SubmitIgnored extends SubmitResult {
  const SubmitIgnored();
}

/// Daily attendance for the class teacher's own class.
///
/// State machine: [roster] (loading/data/empty/error/forbidden) + the server's existing records for
/// [day] + the teacher's local [marks]. Submit is only possible when EVERY active student has an explicit
/// status (the web silently saves unmarked students as 'absent': students.api / AttendanceTab.tsx:75; this
/// app never does). Failed submits keep [marks] untouched.
class AttendanceController extends GetxController {
  final StudentsRepository? _students;
  final AttendanceRepository? _attendance;
  final AuthController? _auth;
  final PermissionService? _perms;
  final Clock clock;

  AttendanceController({
    StudentsRepository? students,
    AttendanceRepository? attendance,
    AuthController? auth,
    PermissionService? permissions,
    Clock? clock,
  })  : _students = students,
        _attendance = attendance,
        _auth = auth,
        _perms = permissions,
        clock = clock ?? DateTime.now,
        day = Rx<DateTime>(dateOnly((clock ?? DateTime.now)()));

  StudentsRepository get students => _students ?? Get.find<StudentsRepository>();
  AttendanceRepository get attendance => _attendance ?? Get.find<AttendanceRepository>();
  AuthController get auth => _auth ?? Get.find<AuthController>();
  PermissionService get perms => _perms ?? Get.find<PermissionService>();

  // ── state ────────────────────────────────────────────────────
  /// The calendar day being marked (y/m/d only).
  final Rx<DateTime> day;
  final roster = Rx<SectionState<List<StudentSummary>>>(const SectionState.loading());

  /// Statuses currently on the server for [day] (students in the roster only).
  final savedMarks = <String, AttendanceStatus>{}.obs;

  /// What the teacher has set locally (starts equal to [savedMarks]).
  final marks = <String, AttendanceStatus>{}.obs;

  /// Raw status of a server record outside the enum (kept for a hint; such a student counts as NOT marked).
  final legacyStatus = <String, String>{}.obs;

  /// The school-wide mode (daily by default; read from `GET /teaching/attendance-settings` on every [load]).
  final mode = Rx<AttendanceMode>(AttendanceMode.daily);

  /// Subject names of the school (subject-wise mode only; the same list the web's subject picker shows).
  final subjects = <String>[].obs;

  /// The subject being marked (subject-wise mode only; defaults to the first subject, like the web). Null in a daily school.
  final selectedSubject = Rxn<String>();

  final submitting = false.obs;
  final submitFailure = Rxn<SubmitFailure>();
  final lastSaved = Rxn<DateTime>();

  /// True after the user tried to submit with students unmarked (rows highlight).
  final showUnmarked = false.obs;

  /// School-day check of the (day, selected class grade) on screen. Only `invalid` blocks marking; `unknown` (check failed) never does.
  final dayStatus = Rx<DayCheck>(DayCheck.loading);
  final _dayCache = <String, DayCheck>{};

  int _token = 0;
  ClassRef? _cls;

  // ── access (UI gating only; the backend is the security layer) ─
  /// Every class-teacher class from `/staff-portal/me` (first assignment first). Empty when not a class teacher.
  List<ClassRef> get classes {
    auth.staffMe.value; // dependency for Obx
    return classTeacherClasses(auth.staffMe.value?.teacherProfile);
  }

  /// The class being marked: the session's last choice ([AuthController.attendanceClassKey]) when it is still one of [classes],
  /// else the first. Updated by [selectClass]. Null when there is no class.
  final selectedClass = Rxn<ClassRef>();

  ClassRef? _resolveSelected() {
    final all = classes;
    if (all.isEmpty) return selectedClass.value = null;
    final key = auth.attendanceClassKey.value ?? selectedClass.value?.key;
    final pick = all.firstWhere((c) => c.key == key, orElse: () => all.first);
    // assign only on a real change: listeners (the history screen) reload on every assignment
    if (selectedClass.value?.key != pick.key) selectedClass.value = pick;
    return pick;
  }

  /// The class being marked (kept under its old name for the views): [selectedClass], resolved against the current profile.
  ClassRef? get myClass {
    classes; // dependency for Obx
    selectedClass.value;
    auth.attendanceClassKey.value;
    final all = classes;
    if (all.isEmpty) return null;
    final key = auth.attendanceClassKey.value ?? selectedClass.value?.key;
    return all.firstWhere((c) => c.key == key, orElse: () => all.first);
  }

  /// The picker shows only for a teacher with more than one class.
  bool get hasPicker => classes.length > 1;

  /// The token behind this session does not cover the selected class: marking it would 403 until the teacher signs in again.
  bool get classStale {
    final c = myClass;
    return c != null && auth.isClassStale(c);
  }

  bool get isClassTeacher {
    auth.staffMe.value;
    return auth.isClassTeacher;
  }

  /// Class teachers only. Same rule as the Attendance module entry (permission `teaching:view` for the `attendance` sub-module; the web's
  /// Teaching > Attendance tab). NOT `students:view`: a custom role can grant `teaching:attendance:*` without any `students:*` key.
  bool get allowed => isClassTeacher && myClass != null && perms.canAccess('teaching:view', subModuleKey: 'attendance');

  // ── derived ──────────────────────────────────────────────────
  DateTime get today => dateOnly(clock());

  bool canEditDay(DateTime d) {
    final t = today;
    final x = dateOnly(d);
    return !x.isAfter(t) && !x.isBefore(addDays(t, -kAttendanceEditWindowDays));
  }

  bool get editable => canEditDay(day.value);
  DateTime get earliestEditable => addDays(today, -kAttendanceEditWindowDays);

  List<StudentSummary> get students_ => roster.value.data ?? const [];

  List<StudentSummary> get unmarked => [for (final s in students_) if (!marks.containsKey(s.id)) s];
  int get markedCount => students_.length - unmarked.length;
  StatusCounts get counts => StatusCounts.fromStatuses(marks.values);
  bool get allMarked => students_.isNotEmpty && unmarked.isEmpty;
  bool get hasServerRecords => savedMarks.isNotEmpty;
  bool get dirty => !mapEquals(marks, savedMarks);

  bool get isSubjectWise => mode.value == AttendanceMode.subjectWise;

  /// Subject-wise school with no subject chosen (none exist yet): nothing can be saved, as on the web.
  bool get needsSubject => isSubjectWise && selectedSubject.value == null;

  bool get dayInvalid => dayStatus.value.isInvalid;

  /// Marks can be set: an editable day that the school calendar has not closed.
  bool get markable => editable && !dayInvalid;

  bool get canSubmit => editable && !classStale && !dayInvalid && !submitting.value && roster.value.hasData && allMarked && dirty && !needsSubject;

  String? get academicYear => academicYearOf(students_);

  // ── loading ──────────────────────────────────────────────────
  @override
  void onReady() {
    super.onReady();
    if (allowed) load();
  }

  /// Loads the roster and the day's existing records.
  Future<void> load({bool refreshProfile = false}) async {
    if (refreshProfile) await auth.refreshProfile(force: true);
    final cls = _resolveSelected();
    if (!allowed || cls == null) return;
    _cls = cls;
    final token = ++_token;
    roster.value = const SectionState.loading();
    unawaited(_runDayCheck());
    try {
      // The mode decides what is sent and read: a failure here is an error state with Retry (never a guess).
      final m = await attendance.fetchMode();
      if (token != _token) return;
      await _applyMode(m);
      if (token != _token) return;
      GradesSections? known;
      try {
        known = await students.fetchGradesSections();
      } catch (_) {
        known = null; // optional: the class's own strings are used
      }
      final list = await students.fetchClassRoster(cls, known: known);
      if (token != _token) return;
      final existing = await _fetchDay(cls, day.value, list);
      if (token != _token) return;
      _applyServer(existing);
      roster.value = list.isEmpty ? const SectionState.empty() : SectionState.data(list);
    } catch (e) {
      if (token != _token) return;
      roster.value = SectionState<List<StudentSummary>>.fromError(e);
    }
  }

  Future<void> retry() {
    _dayCache.clear();
    return load();
  }

  /// Switches to [c] (one of [classes]) and reloads its roster and day. Returns false (and does nothing) when there are unsaved marks and
  /// [discard] is false: the view asks the teacher first (same contract as [openDay]).
  Future<bool> selectClass(ClassRef c, {bool discard = false}) async {
    final target = classes.where((x) => x.key == c.key).firstOrNull;
    if (target == null) return false;
    if (target.key == myClass?.key && !discard) return true;
    if (dirty && !discard) return false;
    auth.attendanceClassKey.value = target.key;
    selectedClass.value = target;
    await load();
    return true;
  }

  /// Pull-to-refresh: re-reads the profile (class-teacher changes), the roster and the day. The view
  /// asks the teacher first when there are unsaved marks, because this replaces them.
  Future<void> reload() {
    _dayCache.clear();
    return load(refreshProfile: true);
  }

  String? get _checkGrade => (_cls ?? myClass)?.grade;
  String _checkKey(DateTime d, String? grade) => '${ymdOf(d)}|${grade ?? ''}';

  /// Asks the server whether [day] is a school day for the selected class's grade. Read-only days are not checked.
  /// A response for a (day, grade) that is no longer on screen is dropped. [force] bypasses the cache and keeps the
  /// current status on screen until the answer arrives (the "Check again" action).
  Future<void> _runDayCheck({bool force = false}) async {
    final grade = _checkGrade;
    final d = day.value;
    if (grade == null || !canEditDay(d)) {
      dayStatus.value = DayCheck.unknown;
      return;
    }
    final key = _checkKey(d, grade);
    if (force) _dayCache.remove(key);
    final cached = _dayCache[key];
    if (cached != null) {
      dayStatus.value = cached;
      return;
    }
    if (!force) dayStatus.value = DayCheck.loading;
    DayCheck result;
    try {
      final s = await attendance.checkDay(day: d, grade: grade);
      result = s.unknown ? DayCheck.unknown : (s.valid ? DayCheck.valid : DayCheck.invalid(s.reason));
    } catch (_) {
      result = DayCheck.unknown;
    }
    if (_checkKey(day.value, _checkGrade) != key) return; // the day or class changed meanwhile
    if (result.kind != DayCheckKind.unknown) _dayCache[key] = result;
    dayStatus.value = result;
  }

  /// "Check again": re-runs the school-day check for the current day and class (the admin may have fixed the calendar).
  Future<void> recheckDay() => _runDayCheck(force: true);

  /// Stores the mode; in subject-wise mode loads the subject list and keeps (or defaults to the first) subject.
  Future<void> _applyMode(AttendanceMode m) async {
    mode.value = m;
    if (m == AttendanceMode.subjectWise) {
      final names = await attendance.fetchSubjectNames();
      subjects.assignAll(names);
      final cur = selectedSubject.value;
      selectedSubject.value = (cur != null && names.contains(cur)) ? cur : (names.isEmpty ? null : names.first);
    } else {
      subjects.clear();
      selectedSubject.value = null;
    }
  }

  Future<Map<String, AttendanceRecord>> _fetchDay(ClassRef cls, DateTime d, List<StudentSummary> list) async {
    if (needsSubject) return {}; // subject-wise with no subject yet: there is no record to read
    final records = await attendance.fetchRange(
      grade: cls.grade,
      section: cls.section,
      firstDay: d,
      lastDay: d,
      subject: isSubjectWise ? selectedSubject.value : null,
    );
    final ids = {for (final s in list) s.id};
    final key = ymdOf(d);
    final out = <String, AttendanceRecord>{};
    for (final r in records) {
      if (r.dayKey == key && ids.contains(r.studentId)) out[r.studentId] = r;
    }
    return out;
  }

  void _applyServer(Map<String, AttendanceRecord> existing) {
    savedMarks.clear();
    legacyStatus.clear();
    for (final r in existing.values) {
      final s = r.status;
      if (s != null) {
        savedMarks[r.studentId] = s;
      } else if (r.rawStatus != null) {
        legacyStatus[r.studentId] = r.rawStatus!;
      }
    }
    marks
      ..clear()
      ..addAll(savedMarks);
    submitFailure.value = null;
    showUnmarked.value = false;
  }

  /// Switches to [d]. Returns false (and does nothing) when there are unsaved changes and
  /// [discard] is false: the view asks the teacher first.
  Future<bool> openDay(DateTime d, {bool discard = false}) async {
    final target = dateOnly(d);
    if (dirty && !discard) return false;
    if (sameDate(target, day.value) && roster.value.hasData && !discard) return true;
    day.value = target;
    final cls = _cls ?? myClass;
    if (cls == null || !roster.value.hasData) {
      await load();
      return true;
    }
    unawaited(_runDayCheck());
    final token = ++_token;
    final list = students_;
    // keep the roster on screen; swap only the statuses
    marks.clear();
    savedMarks.clear();
    try {
      final existing = await _fetchDay(cls, target, list);
      if (token != _token) return true;
      _applyServer(existing);
    } catch (e) {
      if (token != _token) return true;
      roster.value = SectionState<List<StudentSummary>>.fromError(e);
    }
    return true;
  }

  /// Subject-wise mode: switches the subject being marked and reads that subject's records of the day. Returns false (and does
  /// nothing) when there are unsaved marks and [discard] is false: the view asks the teacher first.
  Future<bool> selectSubject(String name, {bool discard = false}) async {
    if (!isSubjectWise || !subjects.contains(name)) return false;
    if (name == selectedSubject.value && !discard) return true;
    if (dirty && !discard) return false;
    selectedSubject.value = name;
    final cls = _cls ?? myClass;
    if (cls == null || !roster.value.hasData) {
      await load();
      return true;
    }
    final token = ++_token;
    marks.clear();
    savedMarks.clear();
    try {
      final existing = await _fetchDay(cls, day.value, students_);
      if (token != _token) return true;
      _applyServer(existing);
    } catch (e) {
      if (token != _token) return true;
      roster.value = SectionState<List<StudentSummary>>.fromError(e);
    }
    return true;
  }

  // ── marking ──────────────────────────────────────────────────
  void setStatus(String studentId, AttendanceStatus status) {
    if (!markable || submitting.value) return;
    marks[studentId] = status;
    submitFailure.value = null;
  }

  /// Sets Present for every student that has NO status yet (never overwrites a choice).
  void markRemainingPresent() {
    if (!markable || submitting.value) return;
    for (final s in unmarked) {
      marks[s.id] = AttendanceStatus.present;
    }
    submitFailure.value = null;
  }

  // ── submit ───────────────────────────────────────────────────
  /// Builds the records exactly as sent: one per roster student, grade/section = the class teacher's
  /// own class strings from `/staff-portal/me` (as the web does, AttendanceTab.tsx:70-71), so the
  /// class-scoped list endpoint (which forces the token's strings, scope.util.ts:178) finds them again.
  List<AttendanceWrite> buildWrites() {
    final cls = _cls ?? myClass!;
    return [
      for (final s in students_)
        if (marks[s.id] != null)
          AttendanceWrite(
            studentId: s.id,
            studentName: s.fullName,
            grade: cls.grade,
            section: cls.section,
            day: day.value,
            status: marks[s.id]!,
            // exactly what the web sends in a subject-wise school; nothing at all in a daily school
            subject: isSubjectWise ? selectedSubject.value : null,
          ),
    ];
  }

  /// Submits the whole day. Guarded against double taps; refuses while any student is unmarked.
  Future<SubmitResult> submit() async {
    if (submitting.value) return const SubmitIgnored();
    if (!editable || !roster.value.hasData || needsSubject || classStale || dayInvalid) return const SubmitIgnored();
    final missing = unmarked.length;
    if (missing > 0) {
      showUnmarked.value = true;
      return SubmitBlocked(missing);
    }
    submitting.value = true;
    submitFailure.value = null;
    final snapshot = Map<String, AttendanceStatus>.of(marks);
    try {
      await attendance.submit(buildWrites(), academicYear: academicYear);
      savedMarks
        ..clear()
        ..addAll(snapshot);
      lastSaved.value = clock();
      showUnmarked.value = false;
      _refreshHome();
      return SubmitSaved(StatusCounts.fromStatuses(snapshot.values));
    } catch (e) {
      final f = SubmitFailure.from(e);
      if (f.kind == SubmitFailureKind.staleClass && _cls != null) auth.markClassDenied(_cls!);
      if (f.kind == SubmitFailureKind.notSchoolDay && _cls != null) {
        // the calendar closed this (day, grade): remember it and let the school-day banner (with "Check again") explain
        final reason = f.message.substring(kNotSchoolDayPrefix.length).trim();
        final closed = DayCheck.invalid(reason.isEmpty ? null : reason);
        _dayCache[_checkKey(day.value, _cls!.grade)] = closed;
        dayStatus.value = closed;
      }
      // marks are NOT touched; the stale-class and not-a-school-day refusals are shown by their own banners instead of a generic error
      submitFailure.value = (f.kind == SubmitFailureKind.staleClass || f.kind == SubmitFailureKind.notSchoolDay) ? null : f;
      return SubmitFailed(f);
    } finally {
      submitting.value = false;
    }
  }

  void _refreshHome() {
    if (Get.isRegistered<HomeDashboardController>()) {
      Get.find<HomeDashboardController>().loadClassCard();
    }
  }
}
