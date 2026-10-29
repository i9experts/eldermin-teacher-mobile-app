// A1 item 8: release hygiene, enforced as tests so it cannot drift back.
import 'dart:io';
import 'package:eldermin_teacher_app/core/constants/api_constants.dart';
import 'package:flutter_test/flutter_test.dart';

Iterable<File> _dart(String dir) => Directory(dir).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

void main() {
  group('logging goes through one logger, behind kDebugMode', () {
    test('no print / debugPrint / developer.log anywhere in lib except lib/core/utils/app_log.dart', () {
      final offenders = <String>[];
      final call = RegExp(r'(^|[^\w.])(print|debugPrint)\s*\(|developer\.log\s*\(|import\s+.dart:developer');
      for (final f in _dart('lib')) {
        if (f.path.endsWith('lib/core/utils/app_log.dart')) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final code = lines[i].split('//').first;
          if (call.hasMatch(code)) offenders.add('${f.path}:${i + 1}');
        }
      }
      expect(offenders, isEmpty, reason: 'use AppLog.d(...)');
    });

    test('AppLog is the single place that prints, and only under kDebugMode', () {
      final s = File('lib/core/utils/app_log.dart').readAsStringSync();
      expect('debugPrint('.allMatches(s).length, 1);
      expect(s, contains('if (kDebugMode) debugPrint(message);'));
    });
  });

  group('nothing unfinished or local ships in lib/', () {
    test('no TODO / FIXME / HACK / XXX markers', () {
      final marker = RegExp(r'\b(TODO|FIXME|HACK|XXX)\b');
      final hits = [
        for (final f in _dart('lib'))
          for (final (i, l) in f.readAsLinesSync().indexed)
            if (marker.hasMatch(l)) '${f.path}:${i + 1}',
      ];
      expect(hits, isEmpty);
    });

    test('no local / cleartext URLs or hosts, no test credentials', () {
      final bad = RegExp(r'localhost|127\.0\.0\.1|10\.0\.2\.2|192\.168\.|ngrok|\.local\b|http://(?!www\.w3\.org)', caseSensitive: false);
      final creds = RegExp(r'''(password|passwd|secret|api[_-]?key)\s*[:=]\s*['"][^'"\s$/]{3,}['"]''', caseSensitive: false);
      final hits = <String>[];
      for (final f in _dart('lib')) {
        for (final (i, l) in f.readAsLinesSync().indexed) {
          final code = l.trim();
          if (code.startsWith('//')) continue;
          // the avatar URL scheme check in profile_repository.dart is a validation, not a host
          if (f.path.endsWith('profile_repository.dart') && code.contains("startsWith('http://')")) continue;
          if (bad.hasMatch(code) || creds.hasMatch(code)) hits.add('${f.path}:${i + 1}: $code');
        }
      }
      expect(hits, isEmpty);
    });

    test('the default API host is https and not local', () {
      expect(ApiConstants.baseUrl, startsWith('https://'));
      expect(ApiConstants.baseUrl, isNot(contains('localhost')));
    });

    test('the design gallery is registered only in debug builds', () {
      final s = File('lib/app/routes/app_pages.dart').readAsStringSync();
      expect(s, contains('designGalleryPages({bool enabled = kDebugMode})'));
    });
  });

  group('iOS', () {
    test('Info.plist: ITSAppUsesNonExemptEncryption = false', () {
      final s = File('ios/Runner/Info.plist').readAsStringSync();
      expect(RegExp(r'<key>ITSAppUsesNonExemptEncryption</key>\s*<false/>').hasMatch(s), isTrue);
    });

    test('PrivacyInfo.xcprivacy exists, declares no tracking, and is in the Runner target\'s Resources build phase', () {
      final p = File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();
      expect(RegExp(r'<key>NSPrivacyTracking</key>\s*<false/>').hasMatch(p), isTrue);
      expect(p, contains('NSPrivacyCollectedDataTypeName'));
      expect(p, contains('NSPrivacyCollectedDataTypeEmailAddress'));
      final proj = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
      final fileRef = RegExp(r'(\w{24}) /\* PrivacyInfo\.xcprivacy in Resources \*/ = \{isa = PBXBuildFile').firstMatch(proj);
      expect(fileRef, isNotNull, reason: 'PBXBuildFile for PrivacyInfo.xcprivacy');
      // the Resources phase that lists it belongs to the Runner target (not RunnerTests)
      final phases = RegExp(r'(\w{24}) /\* Resources \*/ = \{\s*isa = PBXResourcesBuildPhase;(.*?)\};', dotAll: true).allMatches(proj);
      final owner = phases.where((m) => m.group(2)!.contains('PrivacyInfo.xcprivacy in Resources')).toList();
      expect(owner, hasLength(1));
      final runnerTarget = RegExp(r'/\* Runner \*/ = \{\s*isa = PBXNativeTarget;(.*?)name = Runner;', dotAll: true).firstMatch(proj)!.group(1)!;
      expect(runnerTarget, contains(owner.single.group(1)!), reason: 'the Resources phase is the Runner target\'s');
    });

    test('no Firebase leftovers in the Xcode project or the Podfile.lock', () {
      expect(File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync(), isNot(contains('GoogleService-Info')));
      expect(File('ios/Podfile.lock').readAsStringSync().toLowerCase(), isNot(contains('firebase')));
    });
  });

  group('Android / dependencies', () {
    test('no Firebase / google-services anywhere in the build files or pubspec', () {
      for (final f in ['android/app/build.gradle.kts', 'android/settings.gradle.kts', 'pubspec.yaml', 'pubspec.lock']) {
        // comments may say "No Firebase"; only real lines count
        final code = File(f).readAsLinesSync().where((l) => !l.trim().startsWith('#') && !l.trim().startsWith('//')).join('\n');
        expect(code.toLowerCase(), isNot(contains('firebase')), reason: f);
        expect(code, isNot(contains('google-services')), reason: f);
      }
      expect(File('firebase.json').existsSync(), isFalse);
    });

    test('release signing never falls back to the debug key and fails without key.properties', () {
      final s = File('android/app/build.gradle.kts').readAsStringSync();
      expect(s, isNot(contains('signingConfigs.getByName("debug")')));
      expect(s, contains('throw GradleException'));
      expect(s, contains('android/key.properties is missing'));
    });

    test('cleartext traffic is allowed only by the debug manifest', () {
      expect(File('android/app/src/main/AndroidManifest.xml').readAsStringSync(), isNot(contains('usesCleartextTraffic')));
      expect(File('android/app/src/profile/AndroidManifest.xml').existsSync() ? File('android/app/src/profile/AndroidManifest.xml').readAsStringSync() : '', isNot(contains('usesCleartextTraffic="true"')));
    });
  });
}
