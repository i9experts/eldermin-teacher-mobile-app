import 'dart:convert';
import 'dart:io';

import 'package:eldermin_teacher_app/core/models/classroom/attendance_models.dart';
import 'package:eldermin_teacher_app/core/models/classroom/student_360.dart';
import 'package:eldermin_teacher_app/core/models/classroom/student_models.dart';
import 'package:eldermin_teacher_app/core/models/staff_me.dart';
import 'package:eldermin_teacher_app/core/models/teacher_profile.dart';
import 'package:eldermin_teacher_app/core/utils/roster_scope.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> fx(String name) =>
    jsonDecode(File('test/fixtures/classroom/$name').readAsStringSync()) as Map<String, dynamic>;

/// Values present in the fixtures that a teacher-facing model must NEVER hold.
const poison = [
  'monthlyTuitionFee', '18500', '21000', // fees (list + 360 `fees` block)
  '0300-555', // guardian / student / emergency / doctor phones
  '00000-0000000', // CNIC / national id / B-form
  'example.test', // guardian email
  '250000', '180000', 'monthlyIncome', // guardian income
  'DUMMY ADDRESS', 'Dummytown', // address
  'POL-DUMMY', 'insurance', // medical insurance
  'RFID-DUMMY', 'Asthma', // rfid, conditions
];

void main() {
  group('StudentSummary (whitelist)', () {
    final list = fx('students_list.json');
    final rows = (list['data'] as List).cast<Map<String, dynamic>>();

    test('fixture really contains the sensitive payload the app must ignore', () {
      final raw = jsonEncode(rows);
      for (final p in ['monthlyTuitionFee', '0300-555', '00000-0000000', 'monthlyIncome', 'example.test']) {
        expect(raw, contains(p), reason: 'fixture should carry $p');
      }
    });

    test('parses the whitelisted fields and holds nothing sensitive', () {
      final students = rows.map(StudentSummary.fromJson).toList();
      expect(students, hasLength(30));
      final first = students.first;
      expect(first.id, isNotEmpty);
      expect(first.fullName, contains('(DUMMY)'));
      expect(first.grade, isNotEmpty);
      final dump = students.map((s) => s.toDebugMap().toString()).join('\n');
      for (final p in poison) {
        expect(dump, isNot(contains(p)), reason: 'model must not hold "$p"');
      }
      // the exact set of fields is the whitelist
      expect(first.toDebugMap().keys.toSet(), {
        'id', 'studentId', 'firstName', 'lastName', 'preferredName', 'gender', 'photoUrl', 'grade', 'section',
        'rollNumber', 'grNo', 'status', 'academicYear'
      });
    });

    test('roll sort is numeric then name; initials and class label', () {
      const a = StudentSummary(id: 'a', firstName: 'Zed', lastName: 'Y', rollNumber: '10');
      const b = StudentSummary(id: 'b', firstName: 'Amy', lastName: 'X', rollNumber: '2');
      const c = StudentSummary(id: 'c', firstName: 'Bob', lastName: 'Z');
      final sorted = [a, c, b]..sort(StudentSummary.compareByRoll);
      expect(sorted.map((s) => s.id), ['b', 'a', 'c']);
      expect(a.initials, 'ZY');
      expect(const StudentSummary(id: 'x').initials, '?');
      expect(const StudentSummary(id: 'x', grade: 'Grade 5', section: 'A').classLabel, 'Grade 5 - A');
    });

    test('tolerates missing/odd values without throwing', () {
      final s = StudentSummary.fromJson({'_id': {'\$oid': 'x'}, 'firstName': null, 'currentRollNumber': 7});
      expect(s.rollNumber, '7');
      expect(s.status, 'active');
      final g = GradesSections.fromJson(fx('grades_sections.json'));
      expect(g.grades, containsAll(['5', 'Grade 5']));
    });
  });

  group('Student360 (whitelist)', () {
    final raw = fx('student_360.json');

    test('payload carries fees and guardian contact data (so the test is meaningful)', () {
      final s = jsonEncode(raw);
      expect(s, contains('"fees"'));
      expect(s, contains('0300-555'));
      expect(s, contains('monthlyIncome'));
    });

    test('parses teacher-relevant sections and drops everything else', () {
      final d = Student360.fromJson(raw);
      expect(d.student.fullName, isNotEmpty);
      expect(d.student.grade, 'Grade 5');
      // roll 3 has a duplicate father row in the fixture -> collapsed to 2 guardians
      expect(d.guardians.map((g) => g.relation), ['father', 'mother']);
      expect(d.guardians.first.isPrimary, isTrue);
      expect(d.attendance.totalDays, greaterThan(0));
      expect(d.attendance.percentage, greaterThan(0));
      expect(d.attendance.recent.length, lessThanOrEqualTo(30));
      expect(d.behaviour.recent, hasLength(3));
      expect(d.behaviour.recent.first.categoryLabel, 'helping');
      expect(d.behaviour.totalPoints, 3);
      expect(d.results, hasLength(2));
      expect(d.results.first.percentage, 80);
      final dump = d.debugDump();
      for (final p in poison) {
        expect(dump, isNot(contains(p)), reason: 'Student360 must not hold "$p"');
      }
    });

    test('allergies are parsed (safety flag) and nothing else of medical', () {
      final rows = (fx('students_list.json')['data'] as List).cast<Map<String, dynamic>>();
      final withAllergy = rows.firstWhere((r) => ((r['medical'] as Map)['allergies'] as List).isNotEmpty);
      final d = Student360.fromJson({'student': withAllergy});
      expect(d.allergies, ['Peanuts (DUMMY)']);
      expect(d.debugDump(), isNot(contains('Dr DUMMY')));
    });

    test('REDUCED payload (backend field hiding 2026-10-08): no guardian email, address, documents, hostel, full medical, transport detail still parses', () {
      final reduced = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
      final st = reduced['student'] as Map<String, dynamic>;
      for (final k in ['address', 'town', 'city', 'personalPhone', 'nationalId', 'bForm', 'documents', 'hostel', 'hostelRoom', 'transportRoute', 'transportRequired', 'emergencyContactName', 'emergencyContactPhone']) {
        st.remove(k);
      }
      st['medical'] = {'allergies': ['Peanuts (DUMMY)']}; // only the safety flag stays
      for (final g in (st['guardians'] as List).cast<Map<String, dynamic>>()) {
        g.remove('email');
        g.remove('phone');
        g.remove('address');
      }
      st['transport'] = {'routeName': 'Route 4 (DUMMY)'}; // route name only
      final d = Student360.fromJson(reduced);
      expect(d.student.fullName, isNotEmpty);
      expect(d.student.grade, 'Grade 5');
      expect(d.guardians, isNotEmpty);
      expect(d.guardiansKnown, isTrue);
      expect(d.allergies, ['Peanuts (DUMMY)']);
      expect(d.attendance.totalDays, greaterThan(0));
      expect(d.behaviour.recent, hasLength(3));
      expect(d.results, hasLength(2));
    });

    test('REDUCED payload without a guardians key: guardiansKnown is false (the screen hides the section), no allergies, no crash', () {
      final d = Student360.fromJson({
        'student': {'_id': 's1', 'firstName': 'Ayesha', 'lastName': 'Khan', 'dateOfBirth': '2015-03-02T00:00:00.000Z', 'currentGrade': 'Grade 5', 'currentSection': 'A'},
      });
      expect(d.guardiansKnown, isFalse);
      expect(d.guardians, isEmpty);
      expect(d.allergies, isEmpty);
      expect(d.student.fullName, 'Ayesha Khan');
    });

    test('empty / partial payloads do not throw', () {
      final d = Student360.fromJson({'student': {'_id': 'x'}});
      expect(d.guardians, isEmpty);
      expect(d.attendance.totalDays, 0);
      expect(d.results, isEmpty);
    });
  });

  group('teacher classes + roster scoping', () {
    TeacherProfile profile({bool ct = false, List<Map<String, Object?>> assignments = const []}) =>
        TeacherProfile.fromJson({
          'isClassTeacher': ct,
          'classTeacherOf': ct ? {'gradeName': 'Grade 5', 'sectionName': 'A', 'label': 'Grade 5 - A'} : null,
          'currentAssignments': assignments,
        });

    final students = (fx('students_list.json')['data'] as List).map((e) => StudentSummary.fromJson(e as Map<String, dynamic>)).toList();
    StudentSummary st(String id, String grade, String section, {String status = 'active', String roll = '1'}) =>
        StudentSummary(id: id, grade: grade, section: section, status: status, rollNumber: roll, firstName: id);

    test('class teacher + subject classes, class teacher first, deduped by normalised key, subjects merged', () {
      final classes = teacherClassesOf(profile(ct: true, assignments: [
        {'gradeLevel': '5', 'sectionName': 'a', 'subjectName': 'Maths'}, // same class as the class-teacher class
        {'gradeLevel': 'Grade 6', 'sectionName': 'B', 'subjectName': 'Science'},
        {'gradeLevel': 'Grade 6', 'sectionName': 'B', 'subjectName': 'Art'},
        {'gradeLevel': null, 'sectionName': 'C'}, // ignored
      ]));
      expect(classes.map((c) => c.label), ['Grade 5 - A', 'Grade 6 - B']);
      expect(classes.first.isClassTeacherClass, isTrue);
      expect(classes.first.subjects, ['Maths']);
      expect(classes[1].subjects, ['Science', 'Art']);
    });

    test('subject teacher without class-teacher flag uses assignments only; none => no classes', () {
      final c = teacherClassesOf(profile(assignments: [
        {'gradeLevel': 'Grade 5', 'sectionName': 'A', 'subjectName': 'Maths'}
      ]));
      expect(c, hasLength(1));
      expect(c.single.isClassTeacherClass, isFalse);
      expect(teacherClassesOf(profile()), isEmpty);
      expect(teacherClassesOf(null), isEmpty);
    });

    test('class teacher flag without a grade name yields no class (never guesses)', () {
      final p = TeacherProfile.fromJson({'isClassTeacher': true, 'classTeacherOf': {'gradeName': null}});
      expect(teacherClassesOf(p), isEmpty);
    });

    test('scopeRoster keeps tolerant matches ("5"/"a" == Grade 5 - A), drops other sections, inactive and duplicates', () {
      final cls = teacherClassesOf(profile(ct: true)).single;
      final scoped = scopeRoster(students, cls);
      expect(scoped, hasLength(30)); // 30 active in Grade 5 A incl. the two stored as "5"/"a"
      expect(scoped.where((s) => s.grade == '5'), hasLength(2));
      final mixed = [
        st('a', 'Grade 5', 'A', roll: '2'),
        st('b', 'Grade 5', 'B'), // other section
        st('c', 'Grade 6', 'A'), // other grade
        st('d', 'Grade 5', 'A', status: 'transferred'),
        st('a', 'Grade 5', 'A', roll: '2'), // duplicate id
        st('e', 'grade-5', ' a ', roll: '1'),
      ];
      expect(scopeRoster(mixed, cls).map((s) => s.id), ['e', 'a']);
      expect(scopeRoster(mixed, cls, activeOnly: false).map((s) => s.id), ['d', 'e', 'a']);
    });

    test('a class without a section means the whole grade (backend scope.util.ts:175)', () {
      final whole = ClassRef(grade: 'Grade 5');
      expect(scopeRoster([st('a', 'Grade 5', 'A'), st('b', 'Grade 5', 'B'), st('c', 'Grade 6', 'A')], whole).map((s) => s.id), ['a', 'b']);
    });

    test('inAnyClass guards a 360 deep link', () {
      final classes = teacherClassesOf(profile(ct: true));
      expect(inAnyClass(st('x', 'Grade 5', 'A'), classes), isTrue);
      expect(inAnyClass(st('x', 'Grade 5', 'B'), classes), isFalse);
      expect(inAnyClass(st('x', 'Grade 5', 'A'), const []), isFalse);
    });

    test('queryVariants: raw stored strings that normalise to the class, own strings as fallback', () {
      const cls = ClassRef(grade: 'Grade 5', section: 'A');
      final v = queryVariants(cls, GradesSections.fromJson(fx('grades_sections.json')));
      expect(v.grades.toSet(), {'Grade 5', '5'});
      expect(v.sections.toSet(), {'A', 'a'});
      final fb = queryVariants(cls, null);
      expect(fb.grades, ['Grade 5']);
      expect(fb.sections, ['A']);
      expect(queryVariants(const ClassRef(grade: 'Grade 5'), null).sections, isEmpty);
    });

    test('StaffMe fixtures feed the same code path (stub /me shape)', () {
      final me = StaffMe.fromJson(fx('staff_me_classteacher.json'));
      final classes = teacherClassesOf(me.teacherProfile);
      expect(classes.first.label, 'Grade 5 - A');
      expect(classes.map((c) => c.label), ['Grade 5 - A', 'Grade 6 - B']);
    });
  });

  group('attendance models', () {
    test('status enum wire values + labels (verified enum)', () {
      expect(AttendanceStatus.values.map((s) => s.wire), ['present', 'absent', 'late', 'excused', 'half_day']);
      expect(AttendanceStatus.excused.label, 'Leave');
      expect(AttendanceStatus.fromWire('half_day'), AttendanceStatus.halfDay);
      expect(AttendanceStatus.fromWire('holiday'), isNull);
      expect(AttendanceStatus.fromWire(null), isNull);
    });

    test('page + records parse; unknown status kept raw, never coerced', () {
      final page = AttendancePage.fromJson(fx('attendance_list.json'));
      expect(page.records, hasLength(40));
      expect(page.total, 840);
      expect(page.pages, 21);
      expect(page.records.first.status, isNotNull);
      final r = AttendanceRecord.fromJson({'studentId': 's', 'status': 'holiday', 'date': '2026-10-02T00:00:00.000Z'});
      expect(r.status, isNull);
      expect(r.rawStatus, 'holiday');
      expect(StatusCounts.fromStatuses([AttendanceStatus.present, null, AttendanceStatus.late]).other, 1);
    });

    test('summary endpoint is a bare array; the 360 map shape is tolerated', () {
      final c = StatusCounts.fromSummary(jsonDecode(File('test/fixtures/classroom/attendance_summary.json').readAsStringSync()));
      expect(c.total, greaterThan(0));
      final c2 = StatusCounts.fromSummary({'present': 3, 'half_day': 1, 'weird': 2});
      expect((c2.present, c2.halfDay, c2.other, c2.total), (3, 1, 2, 6));
      expect(StatusCounts.fromSummary(null).total, 0);
      expect(StatusCounts.fromSummary([{'_id': 'absent', 'count': 4}]).absent, 4);
    });
  });

  group('attendance dates are timezone-agnostic', () {
    test('wire date is noon UTC of the calendar day; window brackets it', () {
      expect(attendanceWireDate(DateTime(2026, 10, 5, 23, 59)), '2026-10-05T12:00:00.000Z');
      final w = attendanceWindow(DateTime(2026, 10, 5), DateTime(2026, 10, 5));
      expect(w.from, '2026-10-04T12:00:00.000Z');
      expect(w.to, '2026-10-05T12:00:00.000Z');
      final month = attendanceWindow(DateTime(2026, 3, 1), DateTime(2026, 3, 31));
      expect(month.from, '2026-02-28T12:00:00.000Z');
      final jan = attendanceWindow(DateTime(2026, 1, 1), DateTime(2026, 1, 31));
      expect(jan.from, '2025-12-31T12:00:00.000Z');
    });

    // Emulates the backend writer for a server whose local zone is UTC+offset:
    //   date = new Date(wire); date.setHours(0,0,0,0)
    DateTime serverStores(String wire, double offsetHours) {
      // a bare YYYY-MM-DD is UTC midnight for the server (JS `new Date('2026-10-05')`), never device-local
      final instant = DateTime.parse(wire.length == 10 ? '${wire}T00:00:00Z' : wire).toUtc();
      final local = instant.add(Duration(minutes: (offsetHours * 60).round())); // server wall clock
      final localMidnight = DateTime.utc(local.year, local.month, local.day); // setHours(0,0,0,0) on the wall clock
      return localMidnight.subtract(Duration(minutes: (offsetHours * 60).round()));
    }

    // UTC, Karachi (+5), Los Angeles (-7 PDT / -8 PST), Kolkata (+5:30), New York (-5), Tokyo (+9), Auckland NZDT (+13),
    // Kiritimati (+14), American Samoa (-11). Supported: server offsets in (-12h, +12h) and (+12h, +14h]; exactly +-12h sits on the window boundary (no inhabited zone).
    for (final off in [0.0, 5.0, -7.0, -8.0, -5.0, 5.5, -3.0, 9.0, -11.0, 11.0, 13.0, 14.0, 11.5, -11.5]) {
      test('server offset ${off}h: write lands on the same day, read window finds it, key maps back', () {
        for (final day in [DateTime(2026, 10, 5), DateTime(2026, 3, 1), DateTime(2026, 12, 31), DateTime(2026, 1, 1)]) {
          final stored = serverStores(attendanceWireDate(day), off);
          final w = attendanceWindow(day, day);
          expect(!stored.isBefore(DateTime.parse(w.from)) && !stored.isAfter(DateTime.parse(w.to)), isTrue,
              reason: 'day $day offset $off not inside window');
          expect(attendanceDayKey(stored), ymdOf(day));
          // the neighbouring days' records are NOT inside this day's window
          for (final nb in [day.subtract(const Duration(days: 1)), day.add(const Duration(days: 1))]) {
            final other = serverStores(attendanceWireDate(DateTime(nb.year, nb.month, nb.day)), off);
            final inside = !other.isBefore(DateTime.parse(w.from)) && !other.isAfter(DateTime.parse(w.to));
            expect(inside, isFalse, reason: 'neighbour leaked at offset $off');
          }
        }
      });
    }

    test('documented limit: a server at exactly UTC-12 maps the stored midnight to the next day', () {
      final stored = serverStores(attendanceWireDate(DateTime(2026, 10, 5)), -12);
      expect(attendanceDayKey(stored), '2026-10-06');
    });

    test('a plain YYYY-MM-DD write would land on the previous day on a server west of UTC (why noon is used)', () {
      final stored = serverStores('2026-10-05', -7); // UTC midnight = 17:00 on Oct 4 for a UTC-7 server
      expect(attendanceDayKey(stored), '2026-10-04');
    });

    test('record dayKey', () {
      final r = AttendanceRecord(studentId: 's', date: DateTime.utc(2026, 10, 4, 19)); // Karachi local midnight of Oct 5
      expect(r.dayKey, '2026-10-05');
      expect(const AttendanceRecord(studentId: 's').dayKey, isNull);
      expect(ymdOf(DateTime(2026, 1, 2)), '2026-01-02');
    });
  });
}
