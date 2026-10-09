import 'package:get/get.dart';
import '../../../../core/models/auth_me.dart';
import '../../../../core/services/avatar_picker.dart';
import '../../../../core/services/profile_repository.dart';
import '../../../../core/utils/avatar_rules.dart';
import '../../../common/action_failure.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/models/section_state.dart';

/// What happened to the last photo attempt (drives the banner under the avatar).
enum AvatarOutcome { none, uploaded, rejected, denied, unavailable, failed, forbidden }

/// Profile (`/profile`): read-only details from `GET /staff-portal/me` (kept fresh in [AuthController]) and `GET /auth/me`, plus the one thing the
/// backend lets a teacher change: the profile photo (`POST /auth/me/avatar`). No edit endpoint exists for anything else.
class ProfileController extends GetxController {
  final ProfileRepository? _repo;
  final AvatarPicker _picker;
  final AuthController? _auth;
  ProfileController({ProfileRepository? repository, AvatarPicker? picker, AuthController? auth})
      : _repo = repository,
        _picker = picker ?? const DeviceAvatarPicker(),
        _auth = auth;

  ProfileRepository get repo => _repo ?? Get.find<ProfileRepository>();
  AuthController get auth => _auth ?? Get.find<AuthController>();

  final account = Rx<SectionState<AuthMe>>(const SectionState.loading());
  final avatarBusy = false.obs;
  final outcome = AvatarOutcome.none.obs;
  final outcomeMessage = RxnString();
  final deniedSource = Rxn<AvatarSource>();
  final localPreviewPath = RxnString();

  /// 503 'storage is not configured' is a property of the server, not a hiccup: once seen, the photo buttons stay disabled for this visit (no retry
  /// hammering). Leaving and reopening the screen, or pull-to-refresh, lets the teacher try again.
  final uploadUnavailable = false.obs;

  @override
  void onReady() {
    super.onReady();
    load();
  }

  Future<void> load({bool userInitiated = false}) async {
    final previous = account.value;
    if (!previous.hasData) account.value = const SectionState.loading();
    // Both reads are independent; a failure of one never hides the other.
    final staff = auth.refreshProfile(force: true);
    try {
      final me = await repo.fetchAccount();
      account.value = SectionState.data(me);
    } catch (e) {
      final failed = SectionState<AuthMe>.fromError(e);
      account.value = previous.hasData && failed.status == SectionStatus.error && !userInitiated ? previous : failed;
    }
    await staff;
    if (userInitiated) uploadUnavailable.value = false;
  }

  Future<void> choosePhoto(AvatarSource source) async {
    if (avatarBusy.value || uploadUnavailable.value) return;
    avatarBusy.value = true;
    outcome.value = AvatarOutcome.none;
    outcomeMessage.value = null;
    deniedSource.value = null;
    try {
      final PickedAvatar? picked;
      try {
        picked = await _picker.pick(source);
      } on AvatarPickDenied catch (d) {
        outcome.value = AvatarOutcome.denied;
        deniedSource.value = d.source;
        outcomeMessage.value = d.source == AvatarSource.camera
            ? 'Eldermin Teacher is not allowed to use the camera. You can allow it in Settings, or choose a photo from your library.'
            : 'Eldermin Teacher is not allowed to read your photos. You can allow it in Settings.';
        return;
      } catch (_) {
        outcome.value = AvatarOutcome.failed;
        outcomeMessage.value = "Couldn't open the photo picker. Please try again.";
        return;
      }
      if (picked == null) return; // cancelled: nothing changes
      final problem = avatarProblem(fileName: picked.name, size: picked.size);
      if (problem != null) {
        outcome.value = AvatarOutcome.rejected;
        outcomeMessage.value = problem;
        return;
      }
      final mime = avatarMimeFor(picked.name)!;
      try {
        final url = await repo.uploadAvatar(path: picked.path, fileName: picked.name, mime: mime);
        auth.setAvatarUrl(url);
        localPreviewPath.value = picked.path;
        outcome.value = AvatarOutcome.uploaded;
        outcomeMessage.value = 'Your photo was updated.';
      } catch (e) {
        final f = ActionFailure.from(e, what: 'update your photo', keep: '', upload: true);
        switch (f.kind) {
          case ActionFailureKind.uploadUnavailable:
            uploadUnavailable.value = true;
            outcome.value = AvatarOutcome.unavailable;
            outcomeMessage.value = 'Photo upload is not available on this server right now. Please try again later.';
          case ActionFailureKind.forbidden:
            outcome.value = AvatarOutcome.forbidden;
            outcomeMessage.value = "You don't have access to change your photo.";
          case ActionFailureKind.validation:
            outcome.value = AvatarOutcome.rejected;
            outcomeMessage.value = f.message.isEmpty ? 'The server did not accept this photo.' : f.message;
          default:
            outcome.value = AvatarOutcome.failed;
            outcomeMessage.value = f.message;
        }
      }
    } finally {
      avatarBusy.value = false;
    }
  }
}
