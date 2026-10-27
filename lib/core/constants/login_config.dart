/// The optional "school code" on the sign-in screen is switched off until the backend login resolves the tenant from the slug
/// (today `POST /auth/login` adds `schoolSlug: <slug>` to the User query, but no User document stores a `schoolSlug`, so ANY code
/// returns 401 "Invalid credentials"; a blank code works for everyone - eldermin-backend src/modules/auth/auth.service.ts:135-140).
///
/// While [kShowSchoolCode] is false the app: renders no school-code field, never sends `slug` on login, never prefills or remembers a
/// code, and clears any code stored by an older install on start. Flip it to true (and nothing else) to restore the previous behaviour
/// once the backend fix lands. Deep links (`eldermin-teacher://login?token=&slug=`) are unaffected: they authenticate with the token and
/// use the slug only for the in-memory institution, never for a login request.
const bool kShowSchoolCode = false;

/// Test seam (compile-time constants cannot change at runtime): tests set this to exercise the re-enabled path, and reset it to null.
class LoginConfig {
  LoginConfig._();

  static bool? showSchoolCodeOverride;

  static bool get showSchoolCode => showSchoolCodeOverride ?? kShowSchoolCode;
}
