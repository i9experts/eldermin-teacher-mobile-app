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

/// Is the section missing: null, '' or whitespace only (after the same normalisation as [sameSection])?
bool isBlankSection(Object? v) => normalizeSectionName(v).isEmpty;

/// THE one rule for "does an item (record / student) with section [itemSection] belong to a class with section [classSection]?"
/// (class_match + behaviour no-section fallback, B0.1 on the backend: `classIncludes` in behaviour-teacher-scope.ts):
///  * a class without a section covers every section of its grade;
///  * an item WITHOUT a section (missing / '' / whitespace) matches by class only, i.e. any class of its grade: the item cannot say
///    which section it is in, so it is not hidden from the teacher;
///  * otherwise the sections must be the same (tolerant).
/// Callers still compare the grade themselves ([sameGrade]).
bool sectionCovered(Object? classSection, Object? itemSection) =>
    isBlankSection(classSection) || isBlankSection(itemSection) || sameSection(classSection, itemSection);

final RegExp _doubledGrade = RegExp(r'\b(grade)\s+grade\b', caseSensitive: false);

/// Server text such as "unit test — Grade Grade 5 A" (the calendar's exam-row template prefixes "Grade" to a grade level that already
/// starts with it): the doubled word becomes one. ONLY the exact repetition "Grade Grade" is touched, so a name that legitimately starts
/// with "Grade" ("Grade 5", "Grade point average") is left alone.
String collapseDoubledGrade(String s) => s.replaceAllMapped(_doubledGrade, (m) => m.group(1)!);
