/// App-side port of the backend's tolerant grade/section comparison:
/// `eldermin-backend/src/common/utils/class-match.util.ts` (same rules, same
/// test cases: see test/core/class_match_test.dart, mirroring
/// class-match.util.spec.ts).
///
/// Normalisation (case-insensitive, trimmed, whitespace collapsed):
///  * grade: strip a leading grade/class/standard/std/g ONLY when followed
///    (after optional space, '-', '_', '.') by a digit; pure numbers lose
///    leading zeros. Roman numerals and number words are NOT mapped;
///    'Nursery' / 'KG-1' stay distinct. Whole-string equality only.
///  * section: also strips a leading 'section ' / 'sec ' prefix.
///  * null / '' normalise to ''.
String _collapse(Object? v) =>
    v == null ? '' : v.toString().trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

final RegExp _gradePrefix = RegExp(r'^(?:grade|class|standard|std|g)[\s\-_.]*(?=\d)');
final RegExp _sectionPrefix = RegExp(r'^(?:section|sec)[\s\-_.:]+(?=\S)');
final RegExp _digitsOnly = RegExp(r'^\d+$');

String normalizeGradeName(Object? v) {
  var s = _collapse(v).replaceFirst(_gradePrefix, '');
  if (_digitsOnly.hasMatch(s)) s = int.parse(s).toString();
  return s;
}

String normalizeSectionName(Object? v) => _collapse(v).replaceFirst(_sectionPrefix, '');

bool sameGrade(Object? a, Object? b) => normalizeGradeName(a) == normalizeGradeName(b);

bool sameSection(Object? a, Object? b) => normalizeSectionName(a) == normalizeSectionName(b);
