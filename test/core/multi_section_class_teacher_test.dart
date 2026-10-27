import 'dart:convert';
import 'dart:io';

import 'package:eldermin_teacher_app/core/models/staff_me.dart';
import 'package:eldermin_teacher_app/core/models/teacher_profile.dart';
import 'package:eldermin_teacher_app/core/utils/jwt_claims.dart';
import 'package:eldermin_teacher_app/core/utils/roster_scope.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/auth_harness.dart' show fakeJwt, classTeacherJwt;

TeacherProfile profile(Map<String, Object?> extra) => TeacherProfile.fromJson({'isClassTeacher': true, ...extra});
const a = {'gradeId': 'g5', 'gradeName': 'Grade 5', 'sectionName': 'A', 'name': 'Grade 5 - A'};
const b = {'gradeId': 'g5', 'gradeName': 'Grade 5', 'sectionName': 'B', 'name': 'Grade 5 - B'};

void main() {
  group('TeacherProfile.classTeacherAssignments', () {
    test('parses the array (fixture), keeps classTeacherOf as the first', () {
      final fx = jsonDecode(File('test/fixtures/classroom/staff_me_two_sections.json').readAsStringSync()) as Map<String, dynamic>;
      final p = StaffMe.fromJson(fx).teacherProfile!;
      expect(p.classTeacherAssignments.map((x) => x.displayName), ['Grade 5 - A', 'Grade 5 - B']);
      expect(p.classTeacherOf!.displayName, 'Grade 5 - A');
      expect(TeacherProfile.fromJson(p.toJson()).classTeacherAssignments, hasLength(2));
    });

    test('falls back to [classTeacherOf] when the array is missing or empty', () {
      expect(profile({'classTeacherOf': a}).classTeacherAssignments.single.sectionName, 'A');
      expect(profile({'classTeacherOf': a, 'classTeacherAssignments': []}).classTeacherAssignments, hasLength(1));
    });

    test('empty when there is neither', () {
      expect(profile({}).classTeacherAssignments, isEmpty);
      expect(profile({'classTeacherOf': null, 'classTeacherAssignments': null}).classTeacherAssignments, isEmpty);
    });
  });

  group('teacherClassesOf / classTeacherClasses', () {
    test('two sections: one class-teacher ClassRef each, first first, subject classes merged, no duplicates', () {
      final p = profile({
        'classTeacherOf': a,
        'classTeacherAssignments': [a, b, a],
        'currentAssignments': [
          {'gradeLevel': '5', 'sectionName': 'b', 'subjectName': 'Maths'},
          {'gradeLevel': 'Grade 6', 'sectionName': 'A', 'subjectName': 'Art'},
        ],
      });
      final all = teacherClassesOf(p);
      expect(all.map((c) => c.label), ['Grade 5 - A', 'Grade 5 - B', 'Grade 6 - A']);
      expect(all.map((c) => c.isClassTeacherClass), [true, true, false]);
      expect(all[1].subjects, ['Maths']);
      expect(classTeacherClasses(p).map((c) => c.label), ['Grade 5 - A', 'Grade 5 - B']);
    });

    test('single class and no class-teacher role behave as before', () {
      expect(classTeacherClasses(profile({'classTeacherOf': a})).single.label, 'Grade 5 - A');
      final none = TeacherProfile.fromJson({'isClassTeacher': false, 'classTeacherOf': a, 'classTeacherAssignments': [a, b]});
      expect(classTeacherClasses(none), isEmpty);
      expect(teacherClassesOf(none), isEmpty);
      expect(classTeacherClasses(null), isEmpty);
    });

    test('a whole-grade assignment (no section) is a class with an empty section', () {
      final c = classTeacherClasses(profile({'classTeacherAssignments': [{'gradeName': 'Grade 2', 'sectionName': null}]})).single;
      expect((c.grade, c.section, c.label), ('Grade 2', '', 'Grade 2'));
    });
  });

  group('JwtClaims', () {
    test('new token: classTeacherAssignments', () {
      final c = JwtClaims.parse(classTeacherJwt([(grade: 'Grade 5', section: 'A'), (grade: 'Grade 5', section: 'B')]));
      expect(c.hasClassClaims, isTrue);
      expect(c.claimedClasses.map((x) => x.label), ['Grade 5 - A', 'Grade 5 - B']);
    });

    test('old token: singular claims', () {
      final c = JwtClaims.parse(fakeJwt({'classTeacherOfGradeName': 'Grade 5', 'classTeacherOfSectionName': 'A'}));
      expect(c.claimedClasses.single.label, 'Grade 5 - A');
    });

    test('no class claims, garbage, null, empty and non-object payloads give empty and never throw', () {
      for (final t in [fakeJwt({'sub': 'u'}), 'garbage', '', null, 'a.b.c', 'a.!!!.c', 'x.${base64Url.encode(utf8.encode('[1,2]'))}.y', 'onlyonepart']) {
        final c = JwtClaims.parse(t);
        expect(c.hasClassClaims, isFalse, reason: '$t');
        expect(c.missingFrom(classTeacherClasses(profile({'classTeacherAssignments': [a]}))), isEmpty);
      }
    });

    test('padding-safe: payloads whose base64 length needs 0, 1 and 2 pad characters', () {
      for (var n = 0; n < 4; n++) {
        final grade = 'G${'x' * n}';
        final c = JwtClaims.parse(fakeJwt({'classTeacherOfGradeName': grade}));
        expect(c.claimedClasses.single.grade, grade);
      }
    });

    test('missingFrom follows the backend rule: tolerant names, whole-grade claim covers every section', () {
      final claims = JwtClaims.parse(classTeacherJwt([(grade: '5', section: 'a'), (grade: 'Grade 6', section: '')]));
      final mine = classTeacherClasses(profile({'classTeacherAssignments': [a, b, {'gradeName': 'Grade 6', 'sectionName': 'C'}]}));
      expect(claims.missingFrom(mine).map((c) => c.label), ['Grade 5 - B']);
    });
  });
}
