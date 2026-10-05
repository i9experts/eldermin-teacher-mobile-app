import '../models/classroom/student_models.dart';
import '../models/teacher_profile.dart';
import 'class_match.dart';

/// One class (grade + optional section) this teacher is responsible for.
///
/// Sources, all from `GET /staff-portal/me` (never the JWT):
///  * `teacherProfile.classTeacherOf.gradeName/sectionName` (class teacher)
///  * `teacherProfile.currentAssignments[].gradeLevel/sectionName` (subject classes)
class ClassRef {
  final String grade;
  /// '' = whole grade (assignment without a section: backend scope.util.ts:175
  /// treats an absent section as "no section restriction").
  final String section;
  final bool isClassTeacherClass;
  final List<String> subjects;

  const ClassRef({required this.grade, this.section = '', this.isClassTeacherClass = false, this.subjects = const []});

  /// Normalised identity: 'Grade 5' + 'A' == '5' + 'a'.
  String get key => '${normalizeGradeName(grade)}|${normalizeSectionName(section)}';

  String get label => section.isEmpty ? grade : '$grade - $section';

  /// Does [s] belong to this class under the backend's tolerant matching?
  bool contains(StudentSummary s) => sameGrade(s.grade, grade) && (section.isEmpty || sameSection(s.section, section));

  ClassRef _withSubject(String? subject, {bool classTeacher = false}) => ClassRef(
        grade: grade,
        section: section,
        isClassTeacherClass: isClassTeacherClass || classTeacher,
        subjects: subject == null || subject.isEmpty || subjects.contains(subject) ? subjects : [...subjects, subject],
      );
}

/// The teacher's classes: the class-teacher class first, then every distinct
/// assignment (deduplicated by normalised grade+section, subjects merged).
/// Assignments without a grade are ignored. Empty when the teacher has no
/// class at all (the Students screen then says so instead of listing anyone).
List<ClassRef> teacherClassesOf(TeacherProfile? profile) {
  if (profile == null) return const [];
  final byKey = <String, ClassRef>{};
  final ct = profile.classTeacherOf;
  if (profile.isClassTeacher && ct != null && (ct.gradeName ?? '').trim().isNotEmpty) {
    final c = ClassRef(grade: ct.gradeName!.trim(), section: (ct.sectionName ?? '').trim(), isClassTeacherClass: true);
    byKey[c.key] = c;
  }
  for (final a in profile.currentAssignments) {
    final g = (a.gradeLevel ?? '').trim();
    if (g.isEmpty) continue;
    final c = ClassRef(grade: g, section: (a.sectionName ?? '').trim());
    final existing = byKey[c.key];
    byKey[c.key] = existing == null ? c._withSubject(a.subjectName) : existing._withSubject(a.subjectName);
  }
  return byKey.values.toList();
}

/// Keeps only students of [cls] (tolerant match) and, by default, only active ones.
/// Sorted by roll number then name. Defence in depth: the server returns every
/// campus student for a grade filter, never trust it to be class-scoped.
List<StudentSummary> scopeRoster(Iterable<StudentSummary> all, ClassRef cls, {bool activeOnly = true}) {
  final seen = <String>{};
  final out = [
    for (final s in all)
      if (s.id.isNotEmpty && cls.contains(s) && (!activeOnly || s.isActive) && seen.add(s.id)) s
  ]..sort(StudentSummary.compareByRoll);
  return out;
}

/// Is this student in ANY of [classes]? (Used to refuse opening a Student 360
/// for someone outside the teacher's classes.)
bool inAnyClass(StudentSummary s, Iterable<ClassRef> classes) => classes.any((c) => c.contains(s));

/// The raw grade/section strings stored on students that normalise to [cls]:
/// what to put in the `grade=`/`section=` filters, because the server matches
/// them EXACTLY (`$in`, students.service.ts:520-521). Falls back to the class's
/// own strings when the list is unavailable or nothing matches.
({List<String> grades, List<String> sections}) queryVariants(ClassRef cls, GradesSections? known) {
  List<String> pick(List<String> raw, bool Function(String) match, String own) {
    final hits = {if (own.isNotEmpty) own, ...raw.where(match)};
    return hits.toList();
  }

  final grades = pick(known?.grades ?? const [], (g) => sameGrade(g, cls.grade), cls.grade);
  final sections = cls.section.isEmpty
      ? <String>[]
      : pick(known?.sections ?? const [], (s) => sameSection(s, cls.section), cls.section);
  return (grades: grades, sections: sections);
}
