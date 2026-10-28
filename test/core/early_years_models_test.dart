import 'dart:io';
import 'package:eldermin_teacher_app/core/models/early_years/ece_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EceChild', () {
    test('reads the roster fields and ignores everything else (care, allergy, medical, guardians)', () {
      final k = EceChild.fromJson({
        '_id': 'abc',
        'studentId': 'ST-9',
        'firstName': 'Ayesha',
        'lastName': 'Khan',
        'photo': 'https://cdn.example/a.jpg',
        'dateOfBirth': '2022-03-01T00:00:00.000Z',
        'currentGrade': 'Nursery',
        'currentSection': 'A',
        'allergies': ['peanuts'],
        'medical': {'bloodGroup': 'O+'},
        'guardians': [{'name': 'Parent', 'cnic': '123'}],
        'careNotes': 'x',
      });
      expect(k.id, 'abc');
      expect(k.fullName, 'Ayesha Khan');
      expect(k.initials, 'AK');
      expect(k.classLabel, 'Nursery - A');
      expect(k.studentCode, 'ST-9');
      expect(k.dateOfBirth, isNotNull);
      // nothing sensitive is reachable from the model: the class has no such field, so the values cannot be shown or logged
      expect(k.toString(), isNot(contains('peanuts')));
      expect('$k ${k.fullName} ${k.classLabel} ${k.photoUrl}', isNot(contains('123')));
    });

    test('tolerates missing and odd values', () {
      final k = EceChild.fromJson({'_id': {'_id': 'nested'}, 'firstName': null, 'currentGrade': 7});
      expect(k.id, 'nested');
      expect(k.fullName, '');
      expect(k.initials, '?');
      expect(k.grade, '7');
      expect(k.classLabel, '7');
    });
  });

  group('profile, domains, skills, frameworks', () {
    test('profile rollup', () {
      final p = EceProfile.fromJson({
        'domainSummaries': [
          {'domainId': 'd1', 'currentLevel': 'Developing', 'evidenceCount': 3, 'lastObservedAt': '2026-10-01T09:00:00.000Z'},
          'junk',
        ],
        'interests': ['Animals'],
        'schemas': ['Rotation'],
        'careRecords': ['ignored'],
      });
      expect(p.domains, hasLength(1));
      expect(p.domains.single.level, 'Developing');
      expect(p.domains.single.evidenceCount, 3);
      expect(p.interests, ['Animals']);
      expect(p.isEmpty, isFalse);
    });

    test('the empty shape the backend sends for a never-observed child', () {
      expect(EceProfile.fromJson({'domainSummaries': [], 'interests': [], 'schemas': []}).isEmpty, isTrue);
      expect(EceProfile.fromJson({}).isEmpty, isTrue);
    });

    test('framework levels fall back to the default six', () {
      expect(EceFramework.fromJson({'_id': 'f', 'name': 'F', 'progressionLevels': ['A', 'B']}).progressionLevels, ['A', 'B']);
      expect(EceFramework.fromJson({'_id': 'f', 'name': 'F', 'progressionLevels': []}).progressionLevels, kDefaultProgressionLevels);
      expect(EceFramework.fromJson({'_id': 'f', 'name': 'F'}).progressionLevels, kDefaultProgressionLevels);
    });

    test('domain and skill rows', () {
      expect(EceDomain.fromJson({'_id': 'd', 'name': 'Physical', 'order': 2}).order, 2);
      final s = EceSkill.fromJson({'_id': 's', 'domainId': 'd', 'name': 'Pencil Control', 'subDomainName': 'Fine Motor'});
      expect([s.domainId, s.name, s.subDomain], ['d', 'Pencil Control', 'Fine Motor']);
    });
  });

  group('observations and portfolio', () {
    test('observation', () {
      final o = EceObservation.fromJson({
        '_id': 'o1',
        'observationType': 'learning_story',
        'narrative': 'Built a tower',
        'nextStep': 'Count blocks',
        'observedBy': 'Ms Sara',
        'observedById': 'secret-id',
        'skillMappings': [{'skillId': 's1', 'progressionLevel': 'Emerging'}],
        'evidence': [{'type': 'photo', 'url': 'https://b.s3.x.amazonaws.com/school/ece-evidence/a.jpg', 'caption': 'Tower'}],
        'isSharedWithFamily': true,
        'createdAt': '2026-10-02T08:00:00.000Z',
        'context': 'Outdoor',
      });
      expect(o.narrative, 'Built a tower');
      expect(o.skills.single.level, 'Emerging');
      expect(o.evidence.single.isPhoto, isTrue);
      expect(o.evidence.single.key, 'school/ece-evidence/a.jpg');
      expect(o.sharedWithFamily, isTrue);
      expect(o.createdAt, isNotNull);
      expect('${o.observedBy} ${o.type}', isNot(contains('secret-id')));
    });

    test('portfolio entry shows whether it is shared; the family reply is not read', () {
      final e = EcePortfolioEntry.fromJson({
        '_id': 'p1',
        'title': 'Painting',
        'narrative': 'Mixed colours',
        'tryThisAtHome': 'Paint with water',
        'isVisibleToFamily': false,
        'familyResponse': {'text': 'reply', 'respondedBy': 'Someone'},
      });
      expect(e.visibleToFamily, isFalse);
      expect(e.tryThisAtHome, 'Paint with water');
      expect(e.evidence, isEmpty);
      expect(EcePortfolioEntry.fromJson({'_id': 'p2', 'isVisibleToFamily': true}).visibleToFamily, isTrue);
    });
  });

  group('evidence keys', () {
    test('only a <school>/<folder>/<file> shape yields a key', () {
      expect(eceEvidenceKey('https://b.s3.ap-south-1.amazonaws.com/s/ece-evidence/a%20b.jpg'), 's/ece-evidence/a b.jpg');
      expect(eceEvidenceKey('s/ece-evidence/a.jpg'), 's/ece-evidence/a.jpg');
      expect(eceEvidenceKey('/s/ece-evidence/a.jpg'), 's/ece-evidence/a.jpg');
      for (final bad in ['', null, 'a.jpg', 's/a.jpg', 's/ece-evidence/', 's/../x/a.jpg', 's//ece-evidence/a.jpg', 's/e/a/b.jpg', 's/e/a.jpg?x=1', r's\e\a.jpg', 'https://']) {
        expect(eceEvidenceKey(bad), isNull, reason: '$bad');
      }
    });
  });

  group('upload body', () {
    test('the real {success, data:{...}} envelope and a bare body', () {
      final a = EceUploaded.fromBody({'success': true, 'data': {'url': 'https://b/x/y/z.jpg', 'key': 'x/y/z.jpg', 'fileName': 'z.jpg'}})!;
      expect([a.url, a.key, a.fileName], ['https://b/x/y/z.jpg', 'x/y/z.jpg', 'z.jpg']);
      expect(EceUploaded.fromBody({'key': 'x/y/z.jpg'})!.url, 'x/y/z.jpg');
      expect(EceUploaded.fromBody({'url': 'https://b/x/ece-evidence/z.jpg'})!.key, 'x/ece-evidence/z.jpg');
      expect(EceUploaded.fromBody({'success': true}), isNull);
      expect(EceUploaded.fromBody('nope'), isNull);
    });
  });

  group('drafts (exact request bodies)', () {
    test('quick observation', () {
      expect(const EceQuickObservationDraft(studentId: 'c1', skillId: 's1', level: 'Emerging').toJson(), {'studentId': 'c1', 'skillId': 's1', 'progressionLevel': 'Emerging'});
      expect(const EceQuickObservationDraft(studentId: 'c1', skillId: 's1', level: 'Emerging', narrative: ' Great ').toJson()['narrative'], 'Great');
    });

    test('full observation: not shared unless asked, blanks are left out', () {
      final b = const EceObservationDraft(studentId: 'c1', narrative: ' Built a tower ').toJson();
      expect(b, {'studentId': 'c1', 'observationType': 'spontaneous', 'narrative': 'Built a tower', 'isSharedWithFamily': false});
      final full = EceObservationDraft(
        studentId: 'c1',
        narrative: 'n',
        type: 'learning_story',
        nextStep: ' next ',
        skills: const [EceSkillMapping(skillId: 's1', level: 'Developing')],
        evidence: const [EceEvidence(type: 'photo', url: 'u', caption: ' cap ')],
        shareWithFamily: true,
      ).toJson();
      expect(full['nextStep'], 'next');
      expect(full['skillMappings'], [{'skillId': 's1', 'progressionLevel': 'Developing'}]);
      expect(full['evidence'], [{'type': 'photo', 'url': 'u', 'caption': 'cap'}]);
      expect(full['isSharedWithFamily'], isTrue);
    });

    test('portfolio entry: private by default', () {
      expect(const EcePortfolioDraft(studentId: 'c1', title: ' T ', narrative: ' N ').toJson(), {'studentId': 'c1', 'title': 'T', 'narrative': 'N', 'isVisibleToFamily': false});
      final shared = const EcePortfolioDraft(studentId: 'c1', title: 'T', narrative: 'N', tryThisAtHome: 'Home', shareWithFamily: true).toJson();
      expect(shared['isVisibleToFamily'], isTrue);
      expect(shared['tryThisAtHome'], 'Home');
    });
  });

  test('the model file never mentions care, allergy, medical or support data in code (comments aside)', () {
    final src = File('lib/core/models/early_years/ece_models.dart')
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    expect(src, isNot(matches(RegExp(r'allerg|medic|careRecord|care_record|supportCase|support_case|guardian|cnic|injur', caseSensitive: false))));
  });
}
