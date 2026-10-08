import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../../core/models/classroom/student_models.dart';
import '../../../../core/models/home/messaging.dart';
import '../../../../core/models/messaging/chat_models.dart';
import '../../../../core/services/messaging_repository.dart';
import '../../../../core/services/students_repository.dart';
import '../../../../core/utils/roster_scope.dart';
import '../../../common/action_failure.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/controllers/home_badges_controller.dart';
import '../../home/models/section_state.dart';
import 'class_roster_picker.dart';

sealed class StartResult {
  const StartResult();
}

class StartCreated extends StartResult {
  final MessageThread thread;
  const StartCreated(this.thread);
}

class StartInvalid extends StartResult {
  final Map<String, String> errors;
  const StartInvalid(this.errors);
}

class StartFailed extends StartResult {
  final ActionFailure failure;
  const StartFailed(this.failure);
}

class StartIgnored extends StartResult {
  const StartIgnored();
}

/// Start a conversation with a guardian (`/messages/new`): student of MY classes -> guardian (names only, from
/// `GET /staff-portal/students/:studentId/guardians`) -> subject + first message -> `POST /staff-portal/threads`.
///
/// The server answers 403 'You do not teach this student.' / 'That person is not a registered guardian of this student.'; its text is shown
/// as is. Submit is refused while a request is in flight; a failure keeps every field.
class NewThreadController extends GetxController {
  final MessagingRepository? _repo;
  final StudentsRepository? _students;
  final AuthController? _auth;
  final HomeBadgesController? _badges;
  final StudentSummary? initialStudent;

  NewThreadController({
    MessagingRepository? repository,
    StudentsRepository? students,
    AuthController? auth,
    HomeBadgesController? badges,
    this.initialStudent,
  })  : _repo = repository,
        _students = students,
        _auth = auth,
        _badges = badges;

  MessagingRepository get repo => _repo ?? Get.find<MessagingRepository>();
  StudentsRepository get students => _students ?? Get.find<StudentsRepository>();
  AuthController get auth => _auth ?? Get.find<AuthController>();
  HomeBadgesController? get badges => _badges ?? (Get.isRegistered<HomeBadgesController>() ? Get.find<HomeBadgesController>() : null);

  late final ClassRosterPicker picker = ClassRosterPicker(() => students, () => classes);

  final student = Rxn<StudentSummary>();
  final guardians = Rx<SectionState<List<GuardianName>>>(const SectionState.loading());
  final guardian = Rxn<GuardianName>();
  final subjectC = TextEditingController();
  final messageC = TextEditingController();
  final saving = false.obs;
  final errors = <String, String>{}.obs;
  final failure = Rxn<ActionFailure>();
  int _guardiansToken = 0;

  List<ClassRef> get classes {
    auth.staffMe.value;
    return teacherClassesOf(auth.staffMe.value?.teacherProfile);
  }

  @override
  void onInit() {
    super.onInit();
    final s = initialStudent;
    // A student outside my classes is never preselected (the server would answer 403 anyway).
    if (s != null && inAnyClass(s, classes)) {
      selectStudent(s);
    } else {
      picker.load();
    }
  }

  @override
  void onClose() {
    subjectC.dispose();
    messageC.dispose();
    super.onClose();
  }

  Future<void> selectStudent(StudentSummary s) async {
    student.value = s;
    guardian.value = null;
    errors.remove('student');
    errors.remove('guardian');
    await loadGuardians();
  }

  Future<void> loadGuardians() async {
    final s = student.value;
    if (s == null) return;
    final token = ++_guardiansToken;
    guardians.value = const SectionState.loading();
    try {
      final list = await repo.fetchGuardians(s.id);
      if (token != _guardiansToken) return;
      if (list.isEmpty) {
        guardians.value = const SectionState.empty();
      } else {
        guardians.value = SectionState.data(list);
        if (list.length == 1) guardian.value = list.first; // nothing to choose
      }
    } catch (e) {
      if (token != _guardiansToken) return;
      guardians.value = SectionState<List<GuardianName>>.fromError(e);
    }
  }

  void selectGuardian(GuardianName g) {
    guardian.value = g;
    errors.remove('guardian');
  }

  void clearStudent() {
    student.value = null;
    guardian.value = null;
    guardians.value = const SectionState.loading();
    _guardiansToken++;
  }

  Map<String, String> validate() {
    final e = <String, String>{};
    final s = student.value;
    if (s == null) {
      e['student'] = 'Choose a student';
    } else if (!inAnyClass(s, classes)) {
      e['student'] = 'This student is not in one of your classes';
    }
    if (guardian.value == null) e['guardian'] = 'Choose a guardian';
    final subject = subjectC.text.trim();
    if (subject.isEmpty) {
      e['subject'] = 'Enter a subject';
    } else if (subject.length > NewThreadRequest.subjectMax) {
      e['subject'] = 'The subject can be at most ${NewThreadRequest.subjectMax} characters';
    }
    final msg = messageC.text.trim();
    if (msg.isEmpty) {
      e['message'] = 'Write your message';
    } else if (msg.length > NewThreadRequest.messageMax) {
      e['message'] = 'The message can be at most ${NewThreadRequest.messageMax} characters';
    }
    return e;
  }

  Future<StartResult> submit() async {
    if (saving.value) return const StartIgnored();
    final problems = validate();
    errors.assignAll(problems);
    if (problems.isNotEmpty) return StartInvalid(problems);
    saving.value = true;
    failure.value = null;
    try {
      final t = await repo.createThread(NewThreadRequest(
        studentId: student.value!.id,
        guardianUserId: guardian.value!.userId,
        subject: subjectC.text,
        firstMessage: messageC.text,
      ));
      badges?.addOpenThread(t);
      badges?.refreshThreads();
      return StartCreated(t);
    } catch (e) {
      final f = ActionFailure.from(e, what: 'start this conversation');
      failure.value = f;
      return StartFailed(f);
    } finally {
      saving.value = false;
    }
  }

  /// Unsaved-changes rule: anything typed, or a student other than the preselected one, or a chosen guardian when none was implied.
  bool get isDirty =>
      subjectC.text.isNotEmpty ||
      messageC.text.isNotEmpty ||
      (student.value?.id != initialStudent?.id) ||
      (guardian.value != null && (guardians.value.data?.length ?? 0) > 1);
}
