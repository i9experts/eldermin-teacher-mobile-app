class AppImages {
  static const String _baseImagePath = "assets/images/";
  static const String logoImage = '${_baseImagePath}eldermin_logo_full.jpg';
  static const String fullLogo = '${_baseImagePath}eldermin_logomark.png';

  /// No dedicated placeholder/avatar art has been supplied yet — both
  /// fall back to the real logomark asset rather than pointing at a
  /// file that doesn't exist on disk.
  static const String userImage = fullLogo;
  static const String placeHolderImage = fullLogo;
}
