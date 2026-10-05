import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../models/homework/homework_models.dart';

/// One file chosen on the device.
class PickedAttachment {
  final String name;
  final String path;
  final int size;
  const PickedAttachment({required this.name, required this.path, required this.size});
}

/// Device file/photo chooser, behind an interface so controllers are testable.
///
/// Permissions: NONE are declared. `file_picker` uses the system document picker, `image_picker` the system photo picker
/// (PHPicker on iOS 14+, the Android photo picker): neither needs a runtime permission or an Info.plist usage string for
/// picking. The camera is deliberately not offered (it would need NSCameraUsageDescription / CAMERA).
abstract class AttachmentPicker {
  Future<List<PickedAttachment>> pickDocuments();
  Future<List<PickedAttachment>> pickPhotos();
}

class DeviceAttachmentPicker implements AttachmentPicker {
  const DeviceAttachmentPicker();

  @override
  Future<List<PickedAttachment>> pickDocuments() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: kAttachmentMimeByExt.keys.toList(),
    );
    if (res == null) return const [];
    return [
      for (final f in res.files)
        if (f.path != null) PickedAttachment(name: f.name, path: f.path!, size: f.size),
    ];
  }

  @override
  Future<List<PickedAttachment>> pickPhotos() async {
    final files = await ImagePicker().pickMultiImage();
    return [for (final x in files) PickedAttachment(name: x.name, path: x.path, size: await x.length())];
  }
}
