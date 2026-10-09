/// Client-side guards for a profile photo: type (jpg / jpeg / png / webp) and size (<= 10 MB, the backend's MAX_FILE_SIZE in upload.service.ts).
const int kAvatarMaxBytes = 10 * 1024 * 1024;

/// MIME type for an allowed file name, else null.
String? avatarMimeFor(String fileName) {
  final n = fileName.toLowerCase();
  if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.webp')) return 'image/webp';
  return null;
}

/// null = fine; otherwise the sentence to show.
String? avatarProblem({required String fileName, required int size}) {
  if (avatarMimeFor(fileName) == null) return 'Please choose a JPG, PNG or WebP photo.';
  if (size <= 0) return "This photo can't be read. Choose another one.";
  if (size > kAvatarMaxBytes) return 'This photo is too large (maximum 10 MB). Choose a smaller one.';
  return null;
}
