// Parity of the app's built-in teacher matrix (PermissionSet.rolePermissions['teacher']) with the web's ROLE_PERMISSIONS[Teacher]
// (fixture: test/fixtures/permissions/web_teacher_permissions.json, header `source` = file:lines @ commit). Compared as SETS; ANY difference in
// either direction fails, except an entry of [knownGaps] with a written reason. Do not silently change the matrix to make this pass.
import 'dart:convert';
import 'dart:io';
import 'package:eldermin_teacher_app/core/models/permission_set.dart';
import 'package:flutter_test/flutter_test.dart';

/// permission -> why the app and the web differ ('app-only:' / 'web-only:' prefix). Expected EMPTY.
const Map<String, String> knownGaps = {};

void main() {
  final fixture = jsonDecode(File('test/fixtures/permissions/web_teacher_permissions.json').readAsStringSync()) as Map<String, dynamic>;
  final web = <String>{...(fixture['permissions'] as List).cast<String>()};
  final app = PermissionSet.rolePermissions['teacher']!;

  test('the fixture names its source file, lines and commit', () {
    expect(fixture['source'], matches(RegExp(r'^Eldermin-Frontend src/types/roles\.ts:\d+-\d+ @ origin/main [0-9a-f]{40}$')));
    expect(fixture['role'], 'teacher');
    expect((fixture['permissions'] as List).length, web.length, reason: 'no duplicate keys in the fixture');
  });

  test('app teacher matrix == web teacher ROLE_PERMISSIONS, as sets, in both directions (minus the explicit knownGaps)', () {
    final appOnly = app.difference(web).where((p) => !knownGaps.containsKey(p)).toList()..sort();
    final webOnly = web.difference(app).where((p) => !knownGaps.containsKey(p)).toList()..sort();
    expect(appOnly, isEmpty, reason: 'granted by the app but NOT by the web: $appOnly');
    expect(webOnly, isEmpty, reason: 'granted by the web but missing in the app: $webOnly');
  });

  test('knownGaps is empty and every entry would still be a real difference (no stale excuses)', () {
    expect(knownGaps, isEmpty);
    for (final k in knownGaps.keys) {
      expect(app.contains(k) != web.contains(k), isTrue, reason: '$k is no longer a difference');
    }
  });

  test('attendance:self is in the base teacher matrix (T3 merge) exactly once', () {
    expect(app, contains('attendance:self'));
    expect(web, contains('attendance:self'));
  });

  test('the app only lists roles it can sign in: exactly {teacher}', () {
    expect(PermissionSet.rolePermissions.keys.toSet(), {'teacher'});
  });
}
