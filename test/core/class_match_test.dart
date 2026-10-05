import 'package:eldermin_teacher_app/core/utils/class_match.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors eldermin-backend/src/common/utils/class-match.util.spec.ts case by case.
void main() {
  for (final v in ['Grade 3', 'grade-3', 'Class 3', 'G3', '3', ' 3 ', 'GRADE   3', 'Std 3', 'Standard 3', 'grade_3', 'Grade3', '03']) {
    test('treats "$v" as grade 3', () {
      expect(normalizeGradeName(v), '3');
      expect(sameGrade(v, 'Grade 3'), isTrue);
    });
  }

  test('does not collide unrelated grades', () {
    expect(sameGrade('Grade 1', 'Grade 11'), isFalse);
    expect(sameGrade('5', '15'), isFalse);
    expect(sameGrade('Nursery', 'KG-1'), isFalse);
    expect(sameGrade('Pre-Nursery', 'Nursery'), isFalse);
    expect(sameGrade('KG-1', 'KG-2'), isFalse);
    expect(sameGrade('KG-1', '1'), isFalse);
    expect(sameGrade('Grade 1', 'Grade 2'), isFalse);
  });

  test('keeps roman numerals and words unmapped', () {
    expect(sameGrade('III', '3'), isFalse);
    expect(sameGrade('One', '1'), isFalse);
    expect(sameGrade('Grade', '3'), isFalse);
    expect(normalizeGradeName('Nursery'), 'nursery');
    expect(sameGrade('nursery', ' NURSERY '), isTrue);
  });

  test('treats null/undefined/empty as empty', () {
    expect(normalizeGradeName(null), '');
    expect(normalizeGradeName('  '), '');
    expect(sameGrade(null, ''), isTrue);
    expect(sameGrade(null, '3'), isFalse);
    expect(sameSection(null, null), isTrue);
    expect(sameSection('', 'A'), isFalse);
  });

  test('handles non-string input', () {
    expect(sameGrade(5, 'Grade 5'), isTrue);
  });

  test('sections: trim, case, prefix', () {
    expect(sameSection(' a ', 'A'), isTrue);
    expect(sameSection('Section A', 'a'), isTrue);
    expect(sameSection('section  b', 'B'), isTrue);
    expect(sameSection('A', 'B'), isFalse);
    expect(sameSection('A', 'AA'), isFalse);
    expect(normalizeSectionName('Section'), 'section');
    expect(sameSection('Girls', 'Boys'), isFalse);
    expect(sameSection('Section 1', '1'), isTrue);
  });
}
