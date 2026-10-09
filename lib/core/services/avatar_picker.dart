import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

enum AvatarSource { gallery, camera }

class PickedAvatar {
  final String path;
  final String name;
  final int size;
  const PickedAvatar({required this.path, required this.name, required this.size});
}

/// The user said no to the photo library / camera (or it is restricted). [permanent]: the system will not ask again (Settings only).
class AvatarPickDenied implements Exception {
  final AvatarSource source;
  final bool permanent;
  const AvatarPickDenied(this.source, {this.permanent = true});
}

/// Device photo chooser for the profile photo, behind an interface so the controller is testable.
///
/// Permissions: `image_picker` uses the system photo picker (PHPicker on iOS 14+, the Android photo picker): no runtime permission for the
/// gallery. The camera needs the iOS usage string (`NSCameraUsageDescription`); on Android `ACTION_IMAGE_CAPTURE` is an intent to the camera
/// app, so no CAMERA permission is declared. A denial surfaces as a [PlatformException] (`camera_access_denied`, `photo_access_denied`), turned into
/// [AvatarPickDenied] here. The picked image is re-encoded by the plugin (max 1024 px, quality 85), which also turns iOS HEIC into JPEG.
abstract class AvatarPicker {
  Future<PickedAvatar?> pick(AvatarSource source);
}

/// The picker the app uses by default. A test seam (like `ExternalLinks.launcher`): the simulator walkthrough swaps in a fake that returns a generated
/// image, because the system photo picker cannot be driven from an integration test. Production code never reassigns it.
class AvatarPickers {
  AvatarPickers._();
  static AvatarPicker current = const DeviceAvatarPicker();
}

class DeviceAvatarPicker implements AvatarPicker {
  const DeviceAvatarPicker();

  @override
  Future<PickedAvatar?> pick(AvatarSource source) async {
    try {
      final x = await ImagePicker().pickImage(
        source: source == AvatarSource.camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.front,
      );
      if (x == null) return null; // cancelled
      return PickedAvatar(path: x.path, name: x.name, size: await x.length());
    } on PlatformException catch (e) {
      if (e.code == 'camera_access_denied' || e.code == 'photo_access_denied' || e.code == 'camera_access_restricted' || e.code == 'photo_access_restricted') {
        throw AvatarPickDenied(source);
      }
      rethrow;
    }
  }
}
