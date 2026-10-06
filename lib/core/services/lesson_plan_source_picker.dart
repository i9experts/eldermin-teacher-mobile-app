import 'package:file_picker/file_picker.dart';
import 'attachment_picker.dart' show PickedAttachment;

/// File types `parse-upload` accepts (teaching.service.ts:225-247). `.doc` and `.pdf` are rejected by the server with a helpful 400,
/// so they are not offered in the picker.
const List<String> kLessonPlanSourceExtensions = ['docx', 'xlsx', 'xls', 'csv', 'txt'];

/// 10 MB multer limit of `parse-upload` (teaching.controller.ts:74).
const int kLessonPlanSourceMaxBytes = 10 * 1024 * 1024;

bool isLessonPlanSourceName(String name) {
  final dot = name.lastIndexOf('.');
  return dot >= 0 && kLessonPlanSourceExtensions.contains(name.substring(dot + 1).toLowerCase());
}

/// Chooses the document to parse, behind an interface so controllers are testable (native pickers cannot be driven in tests).
/// No runtime permission is needed (system document picker).
abstract class LessonPlanSourcePicker {
  Future<PickedAttachment?> pick();
}

class DeviceLessonPlanSourcePicker implements LessonPlanSourcePicker {
  const DeviceLessonPlanSourcePicker();

  @override
  Future<PickedAttachment?> pick() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: kLessonPlanSourceExtensions);
    final f = res?.files.firstOrNull;
    if (f == null || f.path == null) return null;
    return PickedAttachment(name: f.name, path: f.path!, size: f.size);
  }
}
