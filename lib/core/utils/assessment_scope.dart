import '../models/assessments/assessment_models.dart';
import 'class_match.dart';
import 'roster_scope.dart';

/// Which assessments / quiz attempts are MINE. The server has no teacher scoping for any of them (campus or school only: assessment.service.ts
/// :994-1021, :1468-1473, audit B2 #8), so the app scopes client-side with the same tolerant grade/section matcher the roster uses
/// ([class_match.dart], port of the backend's class-match.util.ts). Defence in depth only: this is UI-gating, not security.

bool _sameName(String a, String b) => a.trim().toLowerCase() == b.trim().toLowerCase();

/// Does class [c] (grade + optional section; '' = whole grade) fall under a grade + section pair where '' section = every section?
bool classMatches(ClassRef c, String grade, String section) =>
    sameGrade(c.grade, grade) && (section.isEmpty || c.section.isEmpty || sameSection(c.section, section));

bool _teaches(ClassRef c, String subject) => c.subjects.any((s) => _sameName(s, subject));

/// My classes that fall under assessment [a] (an all-sections assessment matches every section of the grade I am in).
List<ClassRef> myClassesFor(Assessment a, Iterable<ClassRef> classes) => [for (final c in classes) if (classMatches(c, a.grade, a.section)) c];

/// Subjects of [a] that I teach in at least one of its classes.
List<String> mySubjectsOf(Assessment a, Iterable<ClassRef> classes) {
  final mine = myClassesFor(a, classes);
  return [for (final s in a.subjects) if (mine.any((c) => _teaches(c, s.subject))) s.subject];
}

/// The classes in which I teach [subject] under [a]; for each, the roster class to load: the assessment's own section when it has one,
/// otherwise my class's (an all-sections assessment is entered per class).
List<ClassRef> rosterClassesFor(Assessment a, String subject, Iterable<ClassRef> classes) => [
      for (final c in myClassesFor(a, classes))
        if (_teaches(c, subject))
          ClassRef(grade: c.grade, section: a.section.isNotEmpty ? a.section : c.section, isClassTeacherClass: c.isClassTeacherClass, subjects: c.subjects),
    ];

/// An assessment is relevant to me when I teach one of its subjects in one of its classes, or I am the class teacher of one of its classes
/// (then I see it read-only, and can write remarks).
bool isMyAssessment(Assessment a, Iterable<ClassRef> classes) {
  if (a.status == AssessmentStatus.draft) return false; // an admin's work in progress
  final mine = myClassesFor(a, classes);
  if (mine.isEmpty) return false;
  return mine.any((c) => c.isClassTeacherClass) || mySubjectsOf(a, classes).isNotEmpty;
}

List<Assessment> myAssessments(Iterable<Assessment> all, Iterable<ClassRef> classes) => [for (final a in all) if (isMyAssessment(a, classes)) a];

/// Class-teacher classes that fall under [a] (for report-card remarks).
List<ClassRef> myClassTeacherClassesFor(Assessment a, Iterable<ClassRef> classes) => [for (final c in myClassesFor(a, classes)) if (c.isClassTeacherClass) c];

/// Quiz-attempt visibility rule (owner decision 2026-10-07), evaluated per attempt over my classes (UNION of both roles):
///  * a CLASS TEACHER sees ALL subjects' attempts of THEIR OWN class ([ClassRef.isClassTeacherClass], from /staff-portal/me classTeacherOf);
///  * a SUBJECT teacher sees only attempts of the subjects they teach in a class they teach (currentAssignments).
/// So class teacher of 5-A who also teaches English in 6-B sees every subject in 5-A plus English in 6-B. Grade / section use the same
/// tolerant matcher as the roster; subject names compare case-insensitively. A teacher with no classes sees nothing.
bool isMyAttempt(QuizAttempt t, Iterable<ClassRef> classes) =>
    classes.any((c) => classMatches(c, t.grade, t.section) && (c.isClassTeacherClass || _teaches(c, t.subject)));

/// The distinct subjects of [attempts] (case-insensitive, first spelling kept, sorted) for the subject filter chips.
List<String> attemptSubjects(Iterable<QuizAttempt> attempts) {
  final seen = <String, String>{};
  for (final a in attempts) {
    final name = a.subject.trim();
    if (name.isNotEmpty) seen.putIfAbsent(name.toLowerCase(), () => name);
  }
  return seen.values.toList()..sort((x, y) => x.toLowerCase().compareTo(y.toLowerCase()));
}

/// A report card belongs to my class-teacher class (grade + section both match; a card without a section matches a whole-grade class only).
bool isCardOfClass(ReportCard card, ClassRef cls) => sameGrade(card.grade, cls.grade) && (cls.section.isEmpty || sameSection(card.section, cls.section));
