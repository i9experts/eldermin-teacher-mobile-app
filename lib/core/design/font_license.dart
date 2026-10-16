import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Registers the Plus Jakarta Sans SIL OFL 1.1 text so it shows in the
/// system "licenses" page. Call once from `main()`.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Plus Jakarta Sans'], text);
  });
}
