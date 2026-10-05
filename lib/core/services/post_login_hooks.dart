import '../models/staff_me.dart';

/// Extension point that runs once after a successful sign-in (password or
/// deep-link) with the resolved staff profile.
///
/// INTENTIONALLY A NO-OP in Phase 3 (owner decision D): v1 has no push in
/// the client, so this must NOT request notification permission and must
/// NOT register a device token (`POST /staff-portal/device-token`). A later
/// phase that adds push should do both here - and unregister on logout.
class PostLoginHooks {
  PostLoginHooks._();

  static Future<void> run(StaffMe profile) async {
    // Deliberately empty. See class docs.
  }
}
