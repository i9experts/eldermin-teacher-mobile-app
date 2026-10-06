import 'package:get/get.dart';
import '../../../../core/models/academic/lesson_plan_models.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/services/attachment_picker.dart' show PickedAttachment;
import '../../../../core/services/lesson_plan_repository.dart';
import '../../../../core/services/lesson_plan_source_picker.dart';
import '../../../common/action_failure.dart';

enum UploadPhase { idle, reading, failed }

/// Why a parse failed, in teacher words. [manual] = the document could not be turned into a draft at all ("fill it in yourself").
class ParseFailure {
  final String message;

  /// The server could not (or would not) read the file: offer "Fill it in manually". False for connectivity problems (retry).
  final bool manual;
  const ParseFailure(this.message, {required this.manual});
}

/// "Upload & parse" (`/lesson-plans/upload`): picks a Word / Excel / text file (<= 10 MB) or takes a Google Doc link, asks the backend to
/// extract an AI-assisted DRAFT (`POST /teaching/lesson-plans/parse-upload`, teaching.service.ts:294-379) and hands it to the create form for
/// REVIEW. Nothing is ever saved or submitted from here. The backend needs an Anthropic key: when it has none (500 'AI assistance is not
/// configured on this server.') or the model answers garbage (502), the screen says so calmly and offers the manual form.
class LessonPlanUploadController extends GetxController {
  final LessonPlanRepository? _repo;
  final LessonPlanSourcePicker? _picker;

  LessonPlanUploadController({LessonPlanRepository? repository, LessonPlanSourcePicker? picker})
      : _repo = repository,
        _picker = picker;

  LessonPlanRepository get repo => _repo ?? Get.find<LessonPlanRepository>();
  LessonPlanSourcePicker get picker => _picker ?? (Get.isRegistered<LessonPlanSourcePicker>() ? Get.find<LessonPlanSourcePicker>() : const DeviceLessonPlanSourcePicker());

  final phase = UploadPhase.idle.obs;
  final picked = Rxn<PickedAttachment>();
  final link = ''.obs;
  final pickNotice = RxnString();
  final failure = Rxn<ParseFailure>();
  final progress = 0.0.obs;

  bool get canParse => phase.value != UploadPhase.reading && (picked.value != null || link.value.trim().isNotEmpty);

  Future<void> pickFile() async {
    PickedAttachment? f;
    try {
      f = await picker.pick();
    } catch (_) {
      pickNotice.value = "Couldn't open your files. Please try again.";
      return;
    }
    if (f == null) return;
    setPicked(f);
  }

  /// Validates [f] like the server does (type, 10 MB) so an obviously wrong file never leaves the phone.
  void setPicked(PickedAttachment f) {
    if (!isLessonPlanSourceName(f.name)) {
      pickNotice.value = "${f.name}: only Word (.docx), Excel (.xlsx, .xls), .csv or .txt files can be read. For a PDF or an old .doc, save it as .docx first, or paste a Google Doc link.";
      return;
    }
    if (f.size > kLessonPlanSourceMaxBytes) {
      pickNotice.value = '${f.name}: larger than 10 MB';
      return;
    }
    pickNotice.value = null;
    picked.value = f;
    link.value = '';
    failure.value = null;
  }

  void setLink(String v) {
    link.value = v;
    if (v.trim().isNotEmpty) picked.value = null;
    failure.value = null;
  }

  void clearFile() {
    picked.value = null;
    failure.value = null;
  }

  /// Asks the server to read the document. Returns the draft to review, or null (see [failure]).
  Future<LessonPlanDraft?> parse() async {
    if (!canParse) return null;
    phase.value = UploadPhase.reading;
    failure.value = null;
    progress.value = 0;
    final f = picked.value;
    try {
      final d = await repo.parseUpload(
        path: f?.path,
        fileName: f?.name,
        sourceUrl: f == null ? link.value : null,
        onProgress: (sent, total) => progress.value = total > 0 ? sent / total : 0,
      );
      phase.value = UploadPhase.idle;
      if (d.isEmpty) {
        failure.value = const ParseFailure("We couldn't find any lesson plan details in this document. You can fill the plan in yourself.", manual: true);
        phase.value = UploadPhase.failed;
        return null;
      }
      return d;
    } catch (e) {
      failure.value = _explain(e);
      phase.value = UploadPhase.failed;
      return null;
    }
  }

  static ParseFailure _explain(Object e) {
    if (e is! ApiException) return const ParseFailure("Couldn't read this file. You can fill the plan in yourself.", manual: true);
    switch (e.statusCode) {
      case null:
        return ParseFailure('${e.message} Your file is kept: try again when you are connected.', manual: false);
      case 400:
      case 413:
        // The server's own 400 texts are specific and actionable (PDF not supported, not a Google link, no readable text, ...).
        return ParseFailure(e.message, manual: false);
      case 403:
        return ParseFailure(ActionFailure.from(e, what: 'read this document').message, manual: false);
      default:
        // 500 'AI assistance is not configured on this server.', 502 'Could not understand this document's structure ...' or anything else.
        return const ParseFailure("Couldn't read this file automatically. You can fill the plan in yourself.", manual: true);
    }
  }
}
