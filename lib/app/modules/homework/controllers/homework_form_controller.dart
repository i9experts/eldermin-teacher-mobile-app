import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../../core/models/classroom/student_models.dart';
import '../../../../core/models/homework/homework_models.dart';
import '../../../../core/models/json_helpers.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/services/attachment_picker.dart';
import '../../../../core/services/homework_repository.dart';
import '../../../../core/services/students_repository.dart';
import '../../../../core/utils/home_time.dart';
import '../../../../core/utils/roster_scope.dart';
import '../../../../core/utils/timetable_week.dart' show dateOnly;
import '../../../common/action_failure.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/models/section_state.dart';
import 'homework_controller.dart';

enum UploadStatus { uploading, done, failed }

/// One attachment of the form: a picked file being uploaded, or a key already on the assignment (edit).
class AttachmentItem {
  final String id;
  final String name;
  final String? path;
  final int size;
  final status = UploadStatus.uploading.obs;
  final progress = 0.0.obs;
  final error = RxnString();

  /// The server said uploads are not available at all (503, storage not configured): no Retry, only "Continue without attachment".
  final unavailable = false.obs;
  String? key;

  AttachmentItem({required this.id, required this.name, this.path, this.size = 0, this.key}) {
    if (key != null) status.value = UploadStatus.done;
  }
}

/// The class strings sent as `gradeLevel` / `sectionName`, and what the roster looks like.
class ClassWire {
  final String grade;
  final String section;
  final int students;

  /// Students whose stored grade/section spelling differs from the one sent: the server's roster snapshot matches the strings
  /// EXACTLY (teaching.service.ts:940-947), so these students would not receive the assignment.
  final int mismatched;
  const ClassWire({required this.grade, required this.section, required this.students, required this.mismatched});
}

/// The strings stored on the students themselves (majority), because `materializeSubmissions` matches `currentGrade` /
/// `currentSection` exactly (teaching.service.ts:942-947). Falls back to the strings from `/staff-portal/me` when the roster is empty.
ClassWire classWireOf(List<StudentSummary> roster, ClassRef cls) {
  if (roster.isEmpty) return ClassWire(grade: cls.grade, section: cls.section, students: 0, mismatched: 0);
  final counts = <(String, String), int>{};
  for (final s in roster) {
    final k = (s.grade, cls.section.isEmpty ? '' : s.section);
    counts[k] = (counts[k] ?? 0) + 1;
  }
  final best = (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first;
  return ClassWire(grade: best.key.$1, section: best.key.$2, students: roster.length, mismatched: roster.length - best.value);
}

sealed class FormResult {
  const FormResult();
}

class FormSaved extends FormResult {
  final Assignment assignment;
  final bool assigned;
  const FormSaved(this.assignment, {this.assigned = false});
}

class FormInvalid extends FormResult {
  final Map<String, String> errors;
  const FormInvalid(this.errors);
}

class FormFailed extends FormResult {
  final ActionFailure failure;
  const FormFailed(this.failure);
}

class FormNoChanges extends FormResult {
  const FormNoChanges();
}

class FormIgnored extends FormResult {
  const FormIgnored();
}

/// Create / edit a homework assignment (`/homework/new`; edit when [editing] is passed through `Get.arguments`).
///
/// State machine: fields + attachments (each upload: uploading -> done | failed, retry/remove) + `saving`. Submit is refused while an
/// upload is running or has failed, and while a save is in flight (double-submit). A failed save keeps every field and attachment.
class HomeworkFormController extends GetxController {
  final HomeworkRepository? _repo;
  final StudentsRepository? _students;
  final AuthController? _auth;
  final AttachmentPicker? _picker;
  final HomeworkController? _list;
  final Clock clock;
  final Assignment? editing;

  HomeworkFormController({
    HomeworkRepository? repository,
    StudentsRepository? students,
    AuthController? auth,
    AttachmentPicker? picker,
    HomeworkController? list,
    Clock? clock,
    this.editing,
  })  : _repo = repository,
        _students = students,
        _auth = auth,
        _picker = picker,
        _list = list,
        clock = clock ?? DateTime.now;

  /// The device picker, unless a test/walkthrough registered another [AttachmentPicker] in GetX (native pickers cannot be driven in
  /// an integration test).
  AttachmentPicker get picker => _picker ?? (Get.isRegistered<AttachmentPicker>() ? Get.find<AttachmentPicker>() : const DeviceAttachmentPicker());

  HomeworkRepository get repo => _repo ?? Get.find<HomeworkRepository>();
  StudentsRepository get students => _students ?? Get.find<StudentsRepository>();
  AuthController get auth => _auth ?? Get.find<AuthController>();
  HomeworkController? get list => _list ?? (Get.isRegistered<HomeworkController>() ? Get.find<HomeworkController>() : null);

  /// Caps the app puts on attachments (the server has none besides 10 MB per file): 5 per assignment.
  static const int maxAttachments = 5;

  bool get isEditing => editing != null;
  DateTime get today => dateOnly(clock());

  final titleC = TextEditingController();
  final descriptionC = TextEditingController();
  final instructionsC = TextEditingController();
  final totalC = TextEditingController(text: '100');
  final passingC = TextEditingController(text: '50');

  final type = AssignmentType.homework.obs;
  final subject = RxnString();
  final classIndex = (-1).obs;
  late final Rx<DateTime> assignedDay = Rx<DateTime>(today);
  final dueDay = Rxn<DateTime>();
  final attachments = <AttachmentItem>[].obs;
  final saving = false.obs;
  final errors = <String, String>{}.obs;
  final submitFailure = Rxn<ActionFailure>();
  final pickNotice = RxnString();
  final roster = Rx<SectionState<ClassWire>>(const SectionState.empty());
  int _attachSeq = 0;
  int _rosterToken = 0;
  GradesSections? _known;
  bool _knownTried = false;

  List<ClassRef> get classes {
    auth.staffMe.value;
    return teacherClassesOf(auth.staffMe.value?.teacherProfile);
  }

  ClassRef? get selectedClass {
    final cs = classes;
    return classIndex.value >= 0 && classIndex.value < cs.length ? cs[classIndex.value] : null;
  }

  /// Subjects offered: the ones assigned for that class in `currentAssignments`, else everything the teacher can teach.
  List<String> get subjects {
    final c = selectedClass;
    if (c != null && c.subjects.isNotEmpty) return c.subjects;
    return auth.staffMe.value?.teacherProfile?.subjectsCanTeach ?? const [];
  }

  /// Class label for display (create: the picked class; edit: the stored strings).
  String get classLabel => isEditing ? editing!.classLabel : (selectedClass?.label ?? '');

  bool get hasUploading => attachments.any((a) => a.status.value == UploadStatus.uploading);
  bool get hasFailedUpload => attachments.any((a) => a.status.value == UploadStatus.failed);

  @override
  void onInit() {
    super.onInit();
    final e = editing;
    if (e != null) {
      titleC.text = e.title;
      descriptionC.text = e.description;
      instructionsC.text = e.instructions;
      totalC.text = _fmt(e.totalMarks);
      passingC.text = _fmt(e.passingMarks);
      type.value = e.type ?? AssignmentType.homework;
      subject.value = e.subject;
      assignedDay.value = storedCalendarDay(e.assignedDate) ?? today;
      dueDay.value = e.dueDay;
      for (final k in e.attachmentKeys) {
        attachments.add(AttachmentItem(id: 'k${_attachSeq++}', name: attachmentLabel(k, attachments.length), key: k));
      }
    } else {
      final cs = classes;
      if (cs.length == 1) selectClass(0);
    }
  }

  @override
  void onClose() {
    titleC.dispose();
    descriptionC.dispose();
    instructionsC.dispose();
    totalC.dispose();
    passingC.dispose();
    super.onClose();
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.round().toString() : v.toString();

  void selectClass(int i) {
    if (isEditing || i == classIndex.value) return;
    classIndex.value = i;
    errors.remove('class');
    final subs = subjects;
    if (subject.value == null || !subs.contains(subject.value)) subject.value = subs.length == 1 ? subs.first : null;
    if (subject.value != null) errors.remove('subject');
    _loadRoster();
  }

  void setSubject(String s) {
    subject.value = s;
    errors.remove('subject');
  }

  void setType(AssignmentType t) => type.value = t;

  void setDueDay(DateTime d) {
    dueDay.value = dateOnly(d);
    errors.remove('due');
  }

  Future<void> _loadRoster() async {
    final c = selectedClass;
    if (c == null) return;
    final token = ++_rosterToken;
    roster.value = const SectionState.loading();
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
      if (token != _rosterToken) return;
      roster.value = SectionState.data(classWireOf(list, c));
    } catch (e) {
      if (token != _rosterToken) return;
      roster.value = SectionState<ClassWire>.fromError(e);
    }
  }

  Future<void> retryRoster() => _loadRoster();

  // ── attachments ──────────────────────────────────────────────

  Future<void> pickDocuments() => _pick(picker.pickDocuments);
  Future<void> pickPhotos() => _pick(picker.pickPhotos);

  Future<void> _pick(Future<List<PickedAttachment>> Function() chooser) async {
    List<PickedAttachment> files;
    try {
      files = await chooser();
    } catch (_) {
      pickNotice.value = "Couldn't open your files. Please try again.";
      return;
    }
    await addPicked(files);
  }

  /// Validates and starts uploading [files]. Rejected files (type, size, count) are reported in [pickNotice] and not added.
  Future<void> addPicked(List<PickedAttachment> files) async {
    final rejected = <String>[];
    final started = <Future<void>>[];
    for (final f in files) {
      if (attachmentMimeFor(f.name) == null) {
        rejected.add("${f.name}: this file type can't be attached (PDF, JPG, PNG, WEBP, DOC or DOCX)");
        continue;
      }
      if (f.size > kMaxUploadBytes) {
        rejected.add('${f.name}: larger than 10 MB');
        continue;
      }
      if (attachments.length >= maxAttachments) {
        rejected.add('${f.name}: at most $maxAttachments attachments');
        continue;
      }
      final item = AttachmentItem(id: 'u${_attachSeq++}', name: f.name, path: f.path, size: f.size);
      attachments.add(item);
      started.add(_upload(item));
    }
    pickNotice.value = rejected.isEmpty ? null : rejected.join('\n');
    await Future.wait(started);
  }

  Future<void> _upload(AttachmentItem it) async {
    final path = it.path;
    if (path == null) return;
    it.status.value = UploadStatus.uploading;
    it.progress.value = 0;
    it.error.value = null;
    it.unavailable.value = false;
    try {
      final up = await repo.upload(
        path: path,
        fileName: it.name,
        onProgress: (sent, total) => it.progress.value = total > 0 ? sent / total : 0,
      );
      it.key = up.key;
      it.progress.value = 1;
      it.status.value = UploadStatus.done;
      errors.remove('attachments');
    } catch (e) {
      final f = ActionFailure.from(e, what: 'upload ${it.name}', keep: 'The file is kept.', upload: true);
      it.error.value = f.message;
      it.unavailable.value = f.kind == ActionFailureKind.uploadUnavailable;
      it.status.value = UploadStatus.failed;
    }
  }

  Future<void> retryUpload(String id) async {
    final it = attachments.firstWhereOrNull((a) => a.id == id);
    if (it == null || it.status.value != UploadStatus.failed || it.unavailable.value) return; // uploads are unavailable: retrying would only hammer the server
    await _upload(it);
  }

  void removeAttachment(String id) {
    attachments.removeWhere((a) => a.id == id);
    pickNotice.value = null;
    // the stale 'Retry or remove the attachment that failed' / 'Wait for the uploads' hint no longer applies once nothing blocks
    if (!hasUploading && !hasFailedUpload) errors.remove('attachments');
  }

  // ── validation + submit ──────────────────────────────────────

  /// Field errors keyed `title|class|subject|due|total|passing|attachments`; empty = valid.
  Map<String, String> validate() {
    final e = <String, String>{};
    if (titleC.text.trim().isEmpty) e['title'] = 'Enter a title';
    if (!isEditing) {
      if (selectedClass == null) e['class'] = 'Choose a class';
      if (subject.value == null || subject.value!.isEmpty) e['subject'] = 'Choose a subject';
    }
    final due = dueDay.value;
    if (due == null) {
      e['due'] = 'Choose a due date';
    } else if (!isEditing && due.isBefore(today)) {
      e['due'] = "The due date can't be in the past";
    }
    final total = double.tryParse(totalC.text.trim());
    if (total == null || total <= 0) {
      e['total'] = 'Enter the total marks (more than 0)';
    } else if (total > 1000) {
      e['total'] = 'Total marks can be at most 1000'; // GradeSubmissionDto: grade @Max(1000) (assignment.dto.ts:51)
    }
    final pass = double.tryParse(passingC.text.trim());
    if (pass == null || pass < 0) {
      e['passing'] = 'Enter the passing marks (0 or more)';
    } else if (total != null && total > 0 && pass > total) {
      e['passing'] = "Passing marks can't be more than the total";
    }
    if (hasUploading) {
      e['attachments'] = 'Wait for the uploads to finish';
    } else if (hasFailedUpload) {
      e['attachments'] = 'Retry or remove the attachment that failed';
    }
    return e;
  }

  AssignmentInput? _input(ClassWire? wire) {
    final due = dueDay.value;
    if (due == null) return null;
    final cls = selectedClass;
    final e = editing;
    return AssignmentInput(
      title: titleC.text,
      description: descriptionC.text,
      subject: e?.subject ?? subject.value ?? '',
      gradeLevel: e?.gradeLevel ?? wire?.grade ?? cls?.grade ?? '',
      sectionName: e?.sectionName ?? wire?.section ?? cls?.section ?? '',
      type: type.value,
      assignedDay: assignedDay.value,
      dueDay: due,
      totalMarks: double.tryParse(totalC.text.trim()) ?? 100,
      passingMarks: double.tryParse(passingC.text.trim()) ?? 50,
      instructions: instructionsC.text,
      attachmentKeys: [for (final a in attachments) if (a.key != null) a.key!],
    );
  }

  /// Saves as a draft ([assign] false) or assigns it to the class (true; notifies the guardians of the class: teaching.service.ts:949-979).
  Future<FormResult> submit({required bool assign}) async {
    if (saving.value) return const FormIgnored();
    final problems = validate();
    final staffId = auth.staffId;
    if (staffId == null || staffId.isEmpty) problems['title'] = problems['title'] ?? "Your teacher profile isn't loaded yet. Pull down on the previous screen to refresh.";
    if (!isEditing && roster.value.isLoading) problems['class'] = 'Still loading the class list. One moment.';
    errors.assignAll(problems);
    if (problems.isNotEmpty) return FormInvalid(problems);
    final wire = roster.value.data;
    final input = _input(wire);
    if (input == null) return FormInvalid(errors);
    saving.value = true;
    submitFailure.value = null;
    try {
      final Assignment saved;
      if (isEditing) {
        final patch = input.toPatchJson(editing!, assign: assign);
        if (patch.isEmpty) return const FormNoChanges();
        saved = await repo.update(editing!.id, patch);
      } else {
        saved = await repo.create(input, teacherId: staffId!, assign: assign);
      }
      list?.upsert(saved);
      return FormSaved(saved, assigned: assign && saved.status == 'assigned');
    } catch (e) {
      final f = ActionFailure.from(e, what: isEditing ? 'save this homework' : 'create this homework');
      submitFailure.value = f;
      return FormFailed(f);
    } finally {
      saving.value = false;
    }
  }

  /// Anything typed or attached that would be lost on back.
  bool get isDirty {
    if (isEditing) {
      final input = _input(null);
      return input != null && input.toPatchJson(editing!).isNotEmpty;
    }
    return titleC.text.trim().isNotEmpty ||
        descriptionC.text.trim().isNotEmpty ||
        instructionsC.text.trim().isNotEmpty ||
        attachments.isNotEmpty;
  }

  /// Does a [ApiException] mean "stop, this account may not do this"?
  static bool isForbidden(Object e) => e is ApiException && e.statusCode == 403;
}
