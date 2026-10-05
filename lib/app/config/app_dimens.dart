/// Matches `AppRadius.md` in `core/theme/app_theme.dart` — kept as a
/// separate constant here (rather than importing that file) so the
/// components under `app/components/` don't reach into `core/theme` just
/// for one number.
class AppDimen {
  AppDimen._();

  static const double borderRadius = 13;
}
