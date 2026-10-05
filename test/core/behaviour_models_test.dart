import 'dart:convert';
import 'dart:io';
import 'package:eldermin_teacher_app/core/models/behaviour/behaviour_models.dart';
import 'package:eldermin_teacher_app/core/models/classroom/student_models.dart';
import 'package:eldermin_teacher_app/core/utils/roster_scope.dart';
import 'package:flutter_test/flutter_test.dart';

dynamic fx(String n) => jsonDecode(File('test/fixtures/phase5b/$n.json').readAsStringSync());

void main() {
  final page = BehaviourPage.fromJson(fx('behaviour_records') as Map<String, dynamic>);

  group('BehaviourRecord parsing (stub-derived, mirrors behaviour.schema.ts)', () {
    test('page meta tolerates string page/limit and parses records', () {
      expect(page.records, hasLength(8));
      expect(page.total, 8);
      final r = page.records.firstWhere((r) => r.category == 'helping_others');
      expect(r.kind, BehaviourKind.merit);
      expect(r.points, 5);
      expect(r.reportedBy, 'Clara Classteacher');
      expect(r.reportedById, isNotEmpty);
      expect(r.resolved, isFalse);
      expect(categoryLabel(r.category), 'Helping Others');
    });

    test('string meta from the real controller (page/limit echoed as strings)', () {
      final p = BehaviourPage.fromJson({'data': [], 'meta': {'total': 41, 'page': '2', 'limit': '20', 'pages': 3}});
      expect(p.pages, 3);
      expect(p.total, 41);
    });

    test('unparsed fields never reach the model', () {
      final r = BehaviourRecord.fromJson({'_id': 'r', 'witnesses': ['x'], 'parentResponse': 'secret', 'verifiedBy': 'v', 'location': 'l'});
      expect(r.toString(), isNot(contains('secret')));
      expect(r.id, 'r');
    });

    test('unknown category falls back to a readable label', () {
      expect(categoryLabel('new_thing'), 'New thing');
    });

    test('incident day is the UTC date of the stored instant', () {
      expect(BehaviourRecord.fromJson({'_id': 'r', 'date': '2026-10-05T00:00:00.000Z'}).day, DateTime(2026, 10, 5));
    });
  });

  group('who logged it (isMine)', () {
    test('reportedById wins when present', () {
      final r = BehaviourRecord.fromJson({'_id': 'r', 'reportedBy': 'Someone Else', 'reportedById': 'u1'});
      expect(r.isMine(userId: 'u1', userName: 'Tess'), isTrue);
      expect(r.isMine(userId: 'u2', userName: 'Someone Else'), isFalse); // an id that is not mine is never rescued by a name
    });

    test('web records (no id) fall back to the name, case-insensitively', () {
      final r = BehaviourRecord.fromJson({'_id': 'r', 'reportedBy': 'tess teacher'});
      expect(r.isMine(userId: 'u1', userName: 'Tess Teacher'), isTrue);
      expect(r.isMine(userId: 'u1', userName: ''), isFalse);
      expect(BehaviourRecord.fromJson({'_id': 'r', 'reportedBy': 'Admin'}).isMine(userId: 'u', userName: 'Tess'), isFalse);
    });

    test('fixture split: mine / colleague', () {
      final mine = page.records.where((r) => r.isMine(userId: '64a000000000000000000001', userName: 'Tess Teacher')).toList();
      expect(mine.map((r) => r.category), containsAll(['late_coming', 'parent_meeting', 'leadership']));
      expect(mine.every((r) => r.reportedBy == 'Tess Teacher'), isTrue);
    });
  });

  group('class matching of records', () {
    const c5a = ClassRef(grade: 'Grade 5', section: 'A');
    test('tolerant: "5"/"a" belongs to Grade 5 A; 5B and 6B do not', () {
      final inClass = page.records.where(c5a.containsRecord).toList();
      expect(inClass.any((r) => r.grade == '5' && r.section == 'a'), isTrue);
      expect(inClass.any((r) => r.section == 'B'), isFalse);
      expect(inClass, hasLength(6));
    });
    test('whole-grade class matches any section', () {
      expect(const ClassRef(grade: 'Grade 5').containsRecord(BehaviourRecord.fromJson({'_id': 'r', 'grade': 'Grade 5', 'section': 'B'})), isTrue);
    });
  });

  group('BehaviourDraft.toJson (POST /behaviour/records body)', () {
    const student = StudentSummary(
        id: '64f000000000000000000205', firstName: 'Zara', lastName: 'Malik', grade: 'Grade 5', section: 'A', rollNumber: '6', academicYear: '2026-27');
    BehaviourDraft d(BehaviourKind k, int pts, {String sev = 'low'}) => BehaviourDraft(
        student: student, kind: k, category: kBehaviourCategories[k]!.first, title: '  Title ', description: ' Desc ',
        severity: sev, points: pts, day: DateTime(2026, 10, 5), reporterName: 'Tess Teacher', reporterId: 'u1');

    test('merit: exact keys, positive points, parentNotified false', () {
      expect(d(BehaviourKind.merit, 5).toJson(), {
        'studentId': '64f000000000000000000205',
        'studentName': 'Zara Malik',
        'grade': 'Grade 5',
        'section': 'A',
        'rollNumber': '6',
        'date': '2026-10-05',
        'type': 'positive',
        'category': 'academic_excellence',
        'title': 'Title',
        'description': 'Desc',
        'severity': 'low',
        'points': 5,
        'parentNotified': false,
        'followUpRequired': false,
        'reportedBy': 'Tess Teacher',
        'reportedById': 'u1',
        'academicYear': '2026-27',
      });
    });

    test('demerit / note types, and academicYear omitted when unknown', () {
      expect(d(BehaviourKind.demerit, -3, sev: 'high').toJson()['type'], 'negative');
      expect(d(BehaviourKind.note, 0).toJson()['type'], 'neutral');
      final noYear = BehaviourDraft(
          student: const StudentSummary(id: 'x', firstName: 'A', grade: 'Grade 5'), kind: BehaviourKind.note, category: 'parent_meeting',
          title: 't', description: 'd', points: 0, day: DateTime(2026, 1, 1), reporterName: 'n', reporterId: 'i').toJson();
      expect(noYear.containsKey('academicYear'), isFalse);
      expect(noYear.containsKey('section'), isFalse);
      expect(noYear.containsKey('rollNumber'), isFalse);
    });

    test('every offered category is a member of the schema enum (27) and belongs to exactly one kind', () {
      final all = kBehaviourCategories.values.expand((e) => e).toList();
      expect(all.toSet(), hasLength(27));
      expect(all.every(kCategoryLabels.containsKey), isTrue);
    });
  });

  group('Tarbiyah', () {
    final t = TarbiyahAssessment.fromJson(((fx('tarbiyah') as Map<String, dynamic>)['data'] as List).first as Map<String, dynamic>);
    test('parses period, traits and rating', () {
      expect(t.period, 'Term 1 2026-27');
      expect(t.traits, hasLength(3));
      expect(t.traits.first.label, 'Truthfulness (Sidq)');
      expect(t.overallPercentage, 75);
      expect(t.ratingLabel, 'Good');
      expect(t.areasForImprovement, ['Patience']);
    });
    test('unknown trait key falls back to the key', () {
      expect(const TraitScore('custom', 3, '').label, 'custom');
    });
  });
}
