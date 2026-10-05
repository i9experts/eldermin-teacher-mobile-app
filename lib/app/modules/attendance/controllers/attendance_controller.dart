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

enum SubmitFailureKind { offline, forbidden, conflict, validation, server, other }

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
        return SubmitFailure(SubmitFailureKind.forbidden, "You can't mark attendance for this class. ${e.message}");
      case 409:
        return SubmitFailure(SubmitFailureKind.conflict, 'This day was changed or is locked on the server. ${e.message}');
      case 400:
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

  final submitting = false.obs;
  final submitFailure = Rxn<SubmitFailure>();
  final lastSaved = Rxn<DateTime>();

  /// True after the user tried to submit with students unmarked (rows highlight).
  final showUnmarked = false.obs;

  int _token = 0;
  ClassRef? _cls;

  // ── access (UI gating only; the backend is the security layer) ─
  /// The class-teacher class from `/staff-portal/me` (null when not a class teacher or the class is missing).
  ClassRef? get myClass {
    auth.staffMe.value; // dependency for Obx
    for (final c in teacherClassesOf(auth.staffMe.value?.teacherProfile)) {
      if (c.isClassTeacherClass) return c;
    }
    return null;
  }

  bool get isClassTeacher {
    auth.staffMe.value;
    return auth.isClassTeacher;
  }

  /// Class teachers only. Needs `students:view` like the Home class card (no attendance permission exists).
  bool get allowed => isClassTeacher && myClass != null && perms.canAccess('students:view');

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

  bool get canSubmit => editable && !submitting.value && roster.value.hasData && allMarked && dirty;

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
    final cls = myClass;
    if (!allowed || cls == null) return;
    _cls = cls;
    final token = ++_token;
    roster.value = const SectionState.loading();
    try {
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

  Future<void> retry() => load();

  /// Pull-to-refresh: re-reads the profile (class-teacher changes), the roster and the day. The view
  /// asks the teacher first when there are unsaved marks, because this replaces them.
  Future<void> reload() => load(refreshProfile: true);

  Future<Map<String, AttendanceRecord>> _fetchDay(ClassRef cls, DateTime d, List<StudentSummary> list) async {
    final records = await attendance.fetchRange(grade: cls.grade, section: cls.section, firstDay: d, lastDay: d);
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

  // ── marking ──────────────────────────────────────────────────
  void setStatus(String studentId, AttendanceStatus status) {
    if (!editable || submitting.value) return;
    marks[studentId] = status;
    submitFailure.value = null;
  }

  /// Sets Present for every student that has NO status yet (never overwrites a choice).
  void markRemainingPresent() {
    if (!editable || submitting.value) return;
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
          ),
    ];
  }

  /// Submits the whole day. Guarded against double taps; refuses while any student is unmarked.
  Future<SubmitResult> submit() async {
    if (submitting.value) return const SubmitIgnored();
    if (!editable || !roster.value.hasData) return const SubmitIgnored();
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
      submitFailure.value = f; // marks are NOT touched
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
