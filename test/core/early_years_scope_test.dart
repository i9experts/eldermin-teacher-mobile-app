import 'package:eldermin_teacher_app/core/models/early_years/ece_models.dart';
import 'package:eldermin_teacher_app/core/utils/early_years_scope.dart';
import 'package:eldermin_teacher_app/core/utils/roster_scope.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/fake_early_years_repository.dart' show child;

void main() {
  const nurseryA = ClassRef(grade: 'Nursery', section: 'A');
  const kg1 = ClassRef(grade: 'KG-1');

  group('childInClass (UI-only scoping)', () {
    test('same grade and section, tolerant of case and the "Grade " prefix', () {
      expect(childInClass(nurseryA, child(1)), isTrue);
      expect(childInClass(nurseryA, child(1, section: 'a')), isTrue);
      expect(childInClass(const ClassRef(grade: 'Grade 5', section: 'A'), child(1, grade: '5')), isTrue);
    });

    test('another section or grade is not in the class', () {
      expect(childInClass(nurseryA, child(1, section: 'B')), isFalse);
      expect(childInClass(nurseryA, child(1, grade: 'KG-1')), isFalse);
    });

    test('a class without a section is the whole grade', () {
      expect(childInClass(kg1, child(1, grade: 'KG-1', section: 'B')), isTrue);
      expect(childInClass(kg1, child(1, grade: 'KG-1', section: '')), isTrue);
    });

    test('Nursery and KG-1 stay distinct', () {
      expect(childInClass(kg1, child(1, grade: 'Nursery')), isFalse);
      expect(childInClass(nurseryA, child(1, grade: 'KG-1', section: 'A')), isFalse);
    });

    test('a child with no grade matches nothing', () {
      expect(childInAnyClass([nurseryA, kg1], const EceChild(id: 'x', grade: '', section: '')), isFalse);
    });
  });

  group('myEarlyYearsChildren', () {
    final everyone = [
      child(1, first: 'Zed'),
      child(2, first: 'Amy', section: 'B'),
      child(3, first: 'Bob', grade: 'KG-1', section: 'C'),
      child(4, first: 'Cat', grade: 'KG-2'),
      const EceChild(id: '', firstName: 'No', lastName: 'Id', grade: 'Nursery', section: 'A'),
    ];

    test('keeps only my classes, sorted by name, and drops rows without an id', () {
      final mine = myEarlyYearsChildren(everyone, const [nurseryA, kg1]);
      expect(mine.map((k) => k.id), ['c3', 'c1']);
    });

    test('no class at all: nothing, never the whole school', () {
      expect(myEarlyYearsChildren(everyone, const []), isEmpty);
    });

    test('no child in my classes: nothing', () {
      expect(myEarlyYearsChildren(everyone, const [ClassRef(grade: 'Grade 9', section: 'Z')]), isEmpty);
    });
  });
}
