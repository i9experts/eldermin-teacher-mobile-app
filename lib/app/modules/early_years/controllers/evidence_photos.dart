import 'package:get/get.dart';
import '../../../../core/models/early_years/ece_models.dart';
import '../../../../core/services/attachment_picker.dart';
import '../../../../core/services/early_years_repository.dart';
import '../../../common/action_failure.dart';
import 'ey_submit.dart';

enum EyPhotoStatus { uploading, done, failed }

class EyPhoto {
  final String id;
  final String name;
  final String path;
  final EyPhotoStatus status;
  final double progress;
  final EceUploaded? uploaded;
  final String? error;
  const EyPhoto({required this.id, required this.name, required this.path, this.status = EyPhotoStatus.uploading, this.progress = 0, this.uploaded, this.error});

  EyPhoto copyWith({EyPhotoStatus? status, double? progress, EceUploaded? uploaded, String? error}) => EyPhoto(
        id: id,
        name: name,
        path: path,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        uploaded: uploaded ?? this.uploaded,
        error: error,
      );
}

/// The photos of one create form: picked with the system photo picker (no camera, no permissions), uploaded one by one to the `ece-evidence`
/// folder, and turned into `evidence` rows only once uploaded. Photos only in v1 (the server's upload route takes no video or audio).
class EvidencePhotos {
  final EarlyYearsRepository repo;
  final AttachmentPicker picker;
  EvidencePhotos({required this.repo, AttachmentPicker? picker}) : picker = picker ?? const DeviceAttachmentPicker();

  static const int maxPhotos = 6;
  static const int maxBytes = 10 * 1024 * 1024;
  static const Set<String> allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  final photos = <EyPhoto>[].obs;

  /// A short message about the last pick (too many, too big, wrong type); null when fine.
  final notice = RxnString();

  /// True once the server said uploads are not available at all (storage not configured): retrying cannot help.
  final unavailable = false.obs;
  int _seq = 0;

  bool get busy => photos.any((p) => p.status == EyPhotoStatus.uploading);
  bool get hasFailed => photos.any((p) => p.status == EyPhotoStatus.failed);
  bool get hasAny => photos.isNotEmpty;

  /// `evidence` rows of the photos that finished uploading.
  List<EceEvidence> get evidence => [
        for (final p in photos)
          if (p.status == EyPhotoStatus.done && p.uploaded != null) EceEvidence(type: 'photo', url: p.uploaded!.url),
      ];

  static String _ext(String name) {
    final i = name.lastIndexOf('.');
    return i < 0 ? '' : name.substring(i + 1).toLowerCase();
  }

  Future<void> pick() async {
    notice.value = null;
    final List<PickedAttachment> picked;
    try {
      picked = await picker.pickPhotos();
    } catch (_) {
      notice.value = "Couldn't open your photos. Please try again.";
      return;
    }
    final toUpload = <EyPhoto>[];
    for (final f in picked) {
      if (photos.length + toUpload.length >= maxPhotos) {
        notice.value = 'You can add up to $maxPhotos photos.';
        break;
      }
      if (!allowedExtensions.contains(_ext(f.name))) {
        notice.value = 'Only JPG, PNG or WebP photos can be added.';
        continue;
      }
      if (f.size > maxBytes) {
        notice.value = '${f.name} is larger than 10 MB, so it was not added.';
        continue;
      }
      toUpload.add(EyPhoto(id: 'ph${++_seq}', name: f.name, path: f.path));
    }
    photos.addAll(toUpload);
    for (final p in toUpload) {
      await _upload(p.id);
    }
  }

  Future<void> retry(String id) => _upload(id);

  void remove(String id) {
    photos.removeWhere((p) => p.id == id);
    if (!photos.any((p) => p.status == EyPhotoStatus.failed)) unavailable.value = false;
  }

  void _set(String id, EyPhoto Function(EyPhoto) f) {
    final i = photos.indexWhere((p) => p.id == id);
    if (i >= 0) photos[i] = f(photos[i]);
  }

  Future<void> _upload(String id) async {
    final p = photos.firstWhereOrNull((x) => x.id == id);
    if (p == null) return;
    _set(id, (x) => x.copyWith(status: EyPhotoStatus.uploading, progress: 0));
    try {
      final up = await repo.uploadEvidence(
        path: p.path,
        fileName: p.name,
        onProgress: (sent, total) => _set(id, (x) => x.copyWith(progress: total <= 0 ? 0 : sent / total)),
      );
      _set(id, (x) => x.copyWith(status: EyPhotoStatus.done, progress: 1, uploaded: up));
    } catch (e) {
      final f = eyFailure(e, what: 'upload this photo', upload: true);
      if (f.kind == ActionFailureKind.uploadUnavailable) unavailable.value = true;
      _set(id, (x) => x.copyWith(status: EyPhotoStatus.failed, error: f.message));
    }
  }
}
