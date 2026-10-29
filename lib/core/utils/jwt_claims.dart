import 'dart:convert';
import 'class_match.dart';
import 'roster_scope.dart';

/// The class-teacher claims of the access token, read WITHOUT verifying the signature (the server does that; the app only wants to know
/// what the server will see). Claim names: `classTeacherAssignments[] {gradeName, sectionName}` (auth.service.ts), else the legacy
/// singular `classTeacherOfGradeName` / `classTeacherOfSectionName` of an old token.
///
/// Never throws and never logs: garbage, a missing payload or a non-object payload all give [JwtClaims.empty].
class JwtClaims {
  final List<ClassRef> claimedClasses;
  const JwtClaims(this.claimedClasses);

  static const JwtClaims empty = JwtClaims([]);

  /// True when the token carries at least one class claim. With none, the backend does not restrict by class (fail-open).
  bool get hasClassClaims => claimedClasses.isNotEmpty;

  factory JwtClaims.parse(String? token) {
    try {
      final parts = (token ?? '').split('.');
      if (parts.length < 2) return empty;
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      if (payload is! Map) return empty;
      final out = <ClassRef>[];
      final list = payload['classTeacherAssignments'];
      if (list is List && list.isNotEmpty) {
        for (final a in list) {
          if (a is Map) _add(out, a['gradeName'], a['sectionName']);
        }
      } else {
        _add(out, payload['classTeacherOfGradeName'], payload['classTeacherOfSectionName']);
      }
      return JwtClaims(out);
    } catch (_) {
      return empty;
    }
  }

  static void _add(List<ClassRef> out, Object? grade, Object? section) {
    final g = grade is String ? grade.trim() : '';
    if (g.isEmpty) return;
    out.add(ClassRef(grade: g, section: section is String ? section.trim() : ''));
  }

  /// Does the token let the teacher act on [c]? Deliberately the backend's own rule, not ClassRef.key equality: eldermin-backend
  /// src/auth/scope.util.ts resolveClassSectionScope (~lines 201-229) matches `sameGrade(a, requested) && (!a.section || !requestedSection ||
  /// sameSection(a, requested))`. So: same grade, and the sections agree unless either side has none (a whole-grade claim covers every
  /// section of that grade; a whole-grade request matches any claim of that grade). Keep this in step with that file: if the backend
  /// rule changes, the stale prompt would otherwise warn when the server allows the call, or stay silent when it would 403.
  bool covers(ClassRef c) => claimedClasses.any((a) => sameGrade(a.grade, c.grade) && (a.section.isEmpty || c.section.isEmpty || sameSection(a.section, c.section)));

  /// [mine] classes the token does NOT cover. Empty when the token has no class claims at all (nothing is restricted then).
  List<ClassRef> missingFrom(Iterable<ClassRef> mine) => hasClassClaims ? [for (final c in mine) if (!covers(c)) c] : const [];
}
