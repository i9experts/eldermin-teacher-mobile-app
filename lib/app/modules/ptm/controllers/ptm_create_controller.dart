import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../../core/models/classroom/student_models.dart';
import '../../../../core/models/ptm/ptm_models.dart';
import '../../../../core/services/ptm_repository.dart';
import '../../../../core/services/students_repository.dart';
import '../../../../core/utils/home_time.dart';
import '../../../../core/utils/ptm_rules.dart';
import '../../../../core/utils/roster_scope.dart';
import '../../../common/action_failure.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../messages/controllers/class_roster_picker.dart';
import 'ptm_controller.dart';

sealed class PtmCreateResult {
  const PtmCreateResult();
}

class PtmCreated extends PtmCreateResult {
  final ParentMeeting meeting;
  const PtmCreated(this.meeting);
}

class PtmCreateInvalid extends PtmCreateResult {
  final Map<String, String> errors;
  const PtmCreateInvalid(this.errors);
}

class PtmCreateFailed extends PtmCreateResult {
  final ActionFailure failure;
  final String text;
  const PtmCreateFailed(this.failure, this.text);
}

class PtmCreateIgnored extends PtmCreateResult {
  const PtmCreateIgnored();
}

/// Create a meeting (`/ptm/new`): a teacher-initiated request for a student of MY classes. `POST /teaching/ptm` (ptm.controller.ts:43-47 ->
/// ptm.service.ts:69-122): `teacherId` is always my own `staffId` from `/staff-portal/me` (the server normalises it, 403 'You can only create
/// meetings for yourself' otherwise). `scheduledDate` goes as `YYYY-MM-DD` like the web (PTMTab.tsx:30-33) = stored at UTC midnight, the form
/// the Home agenda already expects. `academicYear` is REQUIRED by the schema (ptm-meeting.schema.ts:52): it is the student's own
/// `currentAcademicYear`, else the most common one of the roster; with none the form cannot be saved (we never invent a year).
class PtmCreateController extends GetxController {
  final PtmRepository? _repo;
  final StudentsRepository? _students;
  final AuthController? _auth;
  final Clock clock;
  PtmCreateController({PtmRepository? repository, StudentsRepository? students, AuthController? auth, Clock? clock})
      : _repo = repository,
        _students = students,
        _auth = auth,
        clock = clock ?? DateTime.now;

  PtmRepository get repo => _repo ?? Get.find<PtmRepository>();
  StudentsRepository get students => _students ?? Get.find<StudentsRepository>();
  AuthController get auth => _auth ?? Get.find<AuthController>();

  late final ClassRosterPicker picker = ClassRosterPicker(() => students, () => classes);

  final student = Rxn<StudentSummary>();
  final day = Rxn<DateTime>();
  final start = RxnString();
  final end = RxnString();
  final points = <TextEditingController>[TextEditingController()].obs;
  final saving = false.obs;
  final errors = <String, String>{}.obs;
  final failure = Rxn<ActionFailure>();
  bool _submitted = false;

  List<ClassRef> get classes {
    auth.staffMe.value;
    return teacherClassesOf(auth.staffMe.value?.teacherProfile);
  }

  @override
  void onInit() {
    super.onInit();
    picker.load();
  }

  @override
  void onClose() {
    for (final c in points) {
      c.dispose();
    }
    super.onClose();
  }

  void selectStudent(StudentSummary s) {
    student.value = s;
    errors.remove('student');
    errors.remove('year');
  }

  void clearStudent() => student.value = null;

  void setDay(DateTime d) {
    day.value = DateTime(d.year, d.month, d.day);
    errors.remove('day');
  }

  void setStart(String hm) {
    start.value = hm;
    errors.remove('start');
    // A sensible end: 30 minutes later, only when none was chosen yet.
    if (end.value == null) {
      final m = parseHm(hm);
      if (m != null && m + 30 < 24 * 60) end.value = formatHm(m + 30);
    }
  }

  void setEnd(String hm) {
    end.value = hm;
    errors.remove('end');
  }

  void addPoint() {
    if (points.length < kPtmMaxPoints) points.add(TextEditingController());
  }

  void removePoint(int i) {
    if (points.length <= 1) {
      points[0].clear();
      return;
    }
    points.removeAt(i).dispose();
  }

  /// The academic year that will be sent: the student's own, else the roster's most common; null = unknown.
  String? get academicYear {
    final s = student.value;
    if (s == null) return null;
    final own = (s.academicYear ?? '').trim();
    if (own.isNotEmpty) return own;
    for (final st in picker.rosters.values) {
      final y = academicYearOf(st.data ?? const <StudentSummary>[]);
      if (y != null) return y;
    }
    return null;
  }

  List<String> get pointTexts => [for (final c in points) if (c.text.trim().isNotEmpty) c.text.trim()];

  Map<String, String> validate() {
    final e = <String, String>{};
    final s = student.value;
    if (s == null) {
      e['student'] = 'Choose a student';
    } else if (!inAnyClass(s, classes)) {
      e['student'] = 'This student is not in one of your classes';
    } else if (academicYear == null) {
      e['year'] = "This student has no academic year on record, so a meeting can't be scheduled from the app. Ask the school office.";
    }
    final d = validatePtmDay(day.value, clock());
    if (d != null) e['day'] = d;
    e.addAll(validatePtmTimes(start.value, end.value));
    for (final p in pointTexts) {
      if (p.length > kPtmPointMax) {
        e['points'] = 'Each discussion point can be at most $kPtmPointMax characters';
        break;
      }
    }
    if (auth.staffId == null || auth.staffId!.isEmpty) e['teacher'] = 'Your profile is not loaded. Go back and try again.';
    return e;
  }

  Future<PtmCreateResult> submit() async {
    if (saving.value || _submitted) return const PtmCreateIgnored();
    final problems = validate();
    errors.assignAll(problems);
    if (problems.isNotEmpty) return PtmCreateInvalid(problems);
    saving.value = true;
    failure.value = null;
    try {
      final m = await repo.create(PtmCreateRequest(
        studentId: student.value!.id,
        teacherId: auth.staffId!,
        day: day.value!,
        startTime: start.value!,
        endTime: end.value!,
        academicYear: academicYear!,
        discussionPoints: pointTexts,
      ));
      _submitted = true;
      if (Get.isRegistered<PtmController>()) Get.find<PtmController>().upsert(m);
      return PtmCreated(m);
    } catch (e) {
      final f = ActionFailure.from(e, what: 'create this meeting');
      failure.value = f;
      return PtmCreateFailed(f, f.serverMessage.isNotEmpty ? f.serverMessage : f.message);
    } finally {
      saving.value = false;
    }
  }

  /// Unsaved-changes rule: anything chosen or typed.
  bool get isDirty => student.value != null || day.value != null || start.value != null || end.value != null || pointTexts.isNotEmpty;
}
