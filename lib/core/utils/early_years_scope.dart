import '../models/early_years/ece_models.dart';
import 'class_match.dart';
import 'roster_scope.dart';

// UI-ONLY SCOPING. `GET /ece/children` returns every Early Years child of the school (all campuses, all classes) and the profile, observation and
// portfolio routes answer for any child id: the backend does not check the teacher's class. These helpers only decide what THIS app shows, so a
// teacher sees the children of their own classes. They are a usability scope, not a security boundary: never rely on them to hide data, and never
// keep or log the unfiltered list.

/// Does [child] belong to [cls] under the same tolerant grade/section matching the backend uses for classes ('Grade 5' == '5', 'a' == 'A')?
/// A class without a section means the whole grade (scope.util.ts treats an absent section as "no section restriction").
bool childInClass(ClassRef cls, EceChild child) => sameGrade(child.grade, cls.grade) && (cls.section.isEmpty || sameSection(child.section, cls.section));

bool childInAnyClass(Iterable<ClassRef> classes, EceChild child) => classes.any((c) => childInClass(c, child));

/// The children of [all] that belong to one of the teacher's [classes], by name. Empty when the teacher has no class.
List<EceChild> myEarlyYearsChildren(Iterable<EceChild> all, List<ClassRef> classes) {
  if (classes.isEmpty) return const [];
  final out = [
    for (final c in all)
      if (c.id.isNotEmpty && childInAnyClass(classes, c)) c,
  ];
  out.sort((a, b) {
    final byName = a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
    return byName != 0 ? byName : a.id.compareTo(b.id);
  });
  return out;
}
