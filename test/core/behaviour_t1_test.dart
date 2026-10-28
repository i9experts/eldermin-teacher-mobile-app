// T1 (core): the shared section rule, ClassRef matching, extended record model, filters, drafts, settings, repository requests.
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:eldermin_teacher_app/core/models/behaviour/behaviour_models.dart';
import 'package:eldermin_teacher_app/core/models/classroom/student_360.dart';
import 'package:eldermin_teacher_app/core/models/classroom/student_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/network/base_client.dart';
import 'package:eldermin_teacher_app/core/services/behaviour_repository.dart';
import 'package:eldermin_teacher_app/core/utils/class_match.dart';
import 'package:eldermin_teacher_app/core/utils/roster_scope.dart';
import 'package:flutter_test/flutter_test.dart';

BehaviourRecord rec(Map<String, Object?> o) => BehaviourRecord.fromJson({'_id': 'r1', 'studentId': 's1', 'grade': 'Grade 5', 'section': 'A', 'type': 'negative', ...o});
StudentSummary stu(String section, {String grade = 'Grade 5'}) => StudentSummary(id: 's$section', firstName: 'A', lastName: 'B', grade: grade, section: section);

class _Client extends BaseClient {
  final Object? Function(String method, String path, Map<String, dynamic>? q, dynamic body) handler;
  final calls = <({String method, String path, Map<String, dynamic>? q, dynamic body})>[];
  _Client(this.handler);

  Response _respond(String method, String url, Map<String, dynamic>? q, dynamic body) {
    final path = Uri.parse(url).path.replaceFirst('/api/v1', '');
    calls.add((method: method, path: path, q: q, body: body));
    final ro = RequestOptions(path: url);
    final r = handler(method, path, q, body);
    if (r is int) {
      throw DioException(requestOptions: ro, type: DioExceptionType.badResponse, response: Response(requestOptions: ro, statusCode: r, data: {'statusCode': r, 'message': 'msg $r'}));
    }
    return Response(requestOptions: ro, statusCode: 200, data: r);
  }

  @override
  Future<Response> get(String url, {Map<String, dynamic>? queryParameters, bool requiresAuth = true, Map<String, String>? headers}) async => _respond('GET', url, queryParameters, null);
  @override
  Future<Response> put(String url, {dynamic data, Map<String, dynamic>? queryParameters, bool requiresAuth = true, Map<String, String>? headers}) async => _respond('PUT', url, queryParameters, data);
  @override
  Future<Response> patch(String url, {dynamic data, Map<String, dynamic>? queryParameters, bool requiresAuth = true, Map<String, String>? headers}) async => _respond('PATCH', url, queryParameters, data);
}

void main() {
  group('sectionCovered / isBlankSection (the ONE shared rule)', () {
    test('blank = null, empty, whitespace-only (and a bare "section" prefix is not a blank)', () {
      for (final v in [null, '', '   ', '\t']) {
        expect(isBlankSection(v), isTrue, reason: '$v');
      }
      expect(isBlankSection('A'), isFalse);
      expect(isBlankSection('Section A'), isFalse);
    });

    test('class without a section covers everything; item without a section matches any class of the grade', () {
      expect(sectionCovered('', 'B'), isTrue);
      expect(sectionCovered('A', ''), isTrue);
      expect(sectionCovered('A', null), isTrue);
      expect(sectionCovered('A', '  '), isTrue);
      expect(sectionCovered('', ''), isTrue);
    });

    test('otherwise sections must match, tolerantly', () {
      expect(sectionCovered('A', 'a'), isTrue);
      expect(sectionCovered('A', 'Section A'), isTrue);
      expect(sectionCovered('A', 'B'), isFalse);
    });
  });

  group('ClassRef matching', () {
    const a = ClassRef(grade: 'Grade 5', section: 'A');
    test('students: strict by default (attendance rosters stay exact), lenient with includeUnsectioned', () {
      expect(a.contains(stu('')), isFalse);
      expect(a.contains(stu(''), includeUnsectioned: true), isTrue);
      expect(a.contains(stu('A')), isTrue);
      expect(a.contains(stu('B'), includeUnsectioned: true), isFalse);
      expect(a.contains(stu('', grade: 'Grade 6'), includeUnsectioned: true), isFalse, reason: 'the grade is still required');
    });

    test('records: a record without a section is in every class of its grade (shared rule)', () {
      expect(a.containsRecord(rec({'section': ''})), isTrue);
      expect(a.containsRecord(rec({'section': '   '})), isTrue);
      expect(a.containsRecord(rec({'section': null})), isTrue);
      expect(a.containsRecord(rec({'section': 'B'})), isFalse);
      expect(a.containsRecord(rec({'grade': 'Grade 6', 'section': ''})), isFalse);
      expect(a.containsRecord(rec({'grade': '5', 'section': 'a'})), isTrue);
    });

    test('scopeRoster / inAnyClass keep the strict default and honour includeUnsectioned', () {
      final all = [stu('A'), stu(''), stu('B')];
      expect(scopeRoster(all, a).map((s) => s.section), ['A']);
      expect(scopeRoster(all, a, includeUnsectioned: true).map((s) => s.id), unorderedEquals(['sA', 's']));
      expect(inAnyClass(stu(''), [a]), isFalse);
      expect(inAnyClass(stu(''), [a], includeUnsectioned: true), isTrue);
      expect(inAnyClass(stu('B'), [a], includeUnsectioned: true), isFalse);
    });
  });

  group('BehaviourRecord (extended fields)', () {
    test('parses every field a teacher may see', () {
      final r = rec({
        'location': 'Corridor', 'consequence': 'detention', 'actionTaken': 'Warned', 'witnesses': ['Ali', 'Sara'], 'followUpRequired': true,
        'followUpDate': '2026-10-10T00:00:00.000Z', 'followUpNote': 'Call home', 'parentNotified': true, 'parentNotifiedDate': '2026-10-02T00:00:00.000Z',
        'parentNotifiedBy': 'Ms T', 'parentResponse': 'ok', 'verified': true, 'verifiedBy': 'Principal', 'attachments': ['https://x/y/a.pdf'],
        'resolved': true, 'resolvedNote': 'done', 'resolvedDate': '2026-10-05T00:00:00.000Z',
      });
      expect(r.location, 'Corridor');
      expect(r.consequence, 'detention');
      expect(r.witnesses, ['Ali', 'Sara']);
      expect(r.followUpRequired, isTrue);
      expect(r.followUpNote, 'Call home');
      expect(r.parentNotified, isTrue);
      expect(r.parentNotifiedBy, 'Ms T');
      expect(r.verifiedBy, 'Principal');
      expect(r.attachments, ['https://x/y/a.pdf']);
      expect(r.resolvedDate, isNotNull);
    });

    test('a thin record (older payload) parses with safe defaults', () {
      final r = rec({});
      expect(r.location, '');
      expect(r.witnesses, isEmpty);
      expect(r.followUpRequired, isFalse);
      expect(r.attachments, isEmpty);
    });

    test('copyWith(resolved) keeps the rest', () {
      final r = rec({'title': 'T', 'location': 'L'}).copyWith(resolved: true, resolvedNote: 'n');
      expect(r.resolved, isTrue);
      expect(r.resolvedNote, 'n');
      expect(r.title, 'T');
      expect(r.location, 'L');
    });

    test('consequence labels: the web list, plus a readable fallback for other stored values', () {
      expect(kConsequences, hasLength(8));
      expect(consequenceLabel('verbal_warning'), 'Verbal warning');
      expect(consequenceLabel('merit_award'), 'Merit award');
      expect(consequenceLabel('some_new_one'), 'Some new one');
      expect(consequenceLabel(''), '');
    });
  });

  group('RecordFilters', () {
    test('none is inactive and sends nothing', () {
      expect(RecordFilters.none.isActive, isFalse);
      expect(RecordFilters.none.toQuery(), isEmpty);
      expect(RecordFilters.none.count, 0);
    });

    test('query params use the backend names; resolved is the string true/false; "to" includes its whole day', () {
      final f = RecordFilters(type: 'negative', severity: 'high', resolved: false, from: DateTime(2026, 9, 1), to: DateTime(2026, 9, 30), search: ' zara ');
      expect(f.toQuery(), {
        'type': 'negative', 'severity': 'high', 'resolved': 'false', 'from': '2026-09-01', 'to': '2026-09-30T23:59:59.999Z', 'search': 'zara',
      });
      expect(f.count, 5);
      expect(f.isActive, isTrue);
    });

    test('copyWith can set and clear one field without touching the others', () {
      const base = RecordFilters(type: 'negative', severity: 'low');
      final cleared = base.copyWith(type: null);
      expect(cleared.type, isNull);
      expect(cleared.severity, 'low');
      expect(base.copyWith(resolved: true).resolved, isTrue);
      expect(base.copyWith().type, 'negative');
    });

    test('accepts: type, severity, resolved, date range (inclusive) and search over name / title / description', () {
      final r = rec({'type': 'negative', 'severity': 'high', 'resolved': false, 'date': '2026-09-15T00:00:00.000Z', 'studentName': 'Zara Malik', 'title': 'Late', 'description': 'came after the bell'});
      expect(const RecordFilters(type: 'positive').accepts(r), isFalse);
      expect(const RecordFilters(type: 'negative', severity: 'high', resolved: false).accepts(r), isTrue);
      expect(const RecordFilters(resolved: true).accepts(r), isFalse);
      expect(RecordFilters(from: DateTime(2026, 9, 15), to: DateTime(2026, 9, 15)).accepts(r), isTrue, reason: 'both ends inclusive');
      expect(RecordFilters(from: DateTime(2026, 9, 16)).accepts(r), isFalse);
      expect(RecordFilters(to: DateTime(2026, 9, 14)).accepts(r), isFalse);
      expect(const RecordFilters(search: 'ZARA').accepts(r), isTrue);
      expect(const RecordFilters(search: 'bell').accepts(r), isTrue);
      expect(const RecordFilters(search: 'nothing').accepts(r), isFalse);
    });

    test('a record without a date never passes a date filter', () {
      expect(RecordFilters(from: DateTime(2026, 1, 1)).accepts(rec({})), isFalse);
    });
  });

  group('BehaviourDraft (create / update bodies)', () {
    final s = StudentSummary(id: 'st1', firstName: 'Zara', lastName: 'Malik', grade: 'Grade 5', section: 'A', rollNumber: '3', academicYear: '2026-27');
    BehaviourDraft draft({String consequence = '', String location = '', bool parents = false, bool follow = false}) => BehaviourDraft(
          student: s, kind: BehaviourKind.demerit, category: 'misconduct', title: ' T ', description: ' D ', severity: 'high', points: -5, day: DateTime(2026, 10, 1),
          reporterName: 'Tess', reporterId: 'u1', consequence: consequence, location: location, parentNotified: parents, followUpRequired: follow);

    test('create: consequence / location only when set; the two flags always; existing keys unchanged', () {
      final bare = draft().toJson();
      expect(bare.containsKey('consequence'), isFalse);
      expect(bare.containsKey('location'), isFalse);
      expect(bare['parentNotified'], false);
      expect(bare['followUpRequired'], false);
      final full = draft(consequence: 'detention', location: ' Corridor ', parents: true, follow: true).toJson();
      expect(full['consequence'], 'detention');
      expect(full['location'], 'Corridor');
      expect(full['parentNotified'], true);
      expect(full['followUpRequired'], true);
      expect(full['reportedById'], 'u1');
      expect(full['title'], 'T');
    });

    test('update body: only what the form edits, never student / reporter / parentNotified / tenancy', () {
      final u = draft(consequence: '', location: '', follow: true, parents: true).toUpdateJson();
      expect(u.keys.toSet(), {'date', 'type', 'category', 'title', 'description', 'severity', 'points', 'consequence', 'location', 'followUpRequired'});
      expect(u['consequence'], '', reason: 'cleared values are sent so an edit can remove them');
      expect(u['location'], '');
      expect(u['followUpRequired'], true);
      for (final forbidden in ['studentId', 'studentName', 'grade', 'section', 'reportedBy', 'reportedById', 'parentNotified', 'schoolSlug', 'campusId']) {
        expect(u.containsKey(forbidden), isFalse, reason: forbidden);
      }
    });
  });

  group('CharacterSettings', () {
    test('parses programme name, trait names and scale', () {
      final c = CharacterSettings.fromJson({
        'moduleDisplayName': 'Akhlaq', 'characteristics': [{'key': 'sidq', 'nameEn': 'Honesty'}, {'key': 'custom_x', 'nameEn': 'Custom X'}], 'ratingScale': {'min': 1, 'max': 10},
      });
      expect(c.programName, 'Akhlaq');
      expect(c.labelFor('sidq'), 'Honesty');
      expect(c.labelFor('custom_x'), 'Custom X');
      expect(c.scaleMax, 10);
    });

    test('fallback order: the school name, the built-in Tarbiyah name, then a readable key', () {
      final c = CharacterSettings.fromJson({'characteristics': [{'key': 'sidq', 'nameEn': 'Honesty'}]});
      expect(c.programName, 'Tarbiyah');
      expect(c.labelFor('adab'), 'Manners & Respect (Adab)');
      expect(c.labelFor('brand_new_trait'), 'Brand new trait');
      expect(c.labelFor(''), '');
      expect(CharacterSettings.fallback.labelFor('sabr'), 'Patience (Sabr)');
    });

    test('an empty / junk body falls back to defaults, never throws', () {
      expect(CharacterSettings.fromJson(const {}).labelFor('shukr'), 'Gratitude (Shukr)');
      expect(CharacterSettings.fromJson({'characteristics': 'nope', 'ratingScale': 5}).scaleMax, 5);
    });
  });

  group('Student 360 behaviour item (B1 union)', () {
    test('records items carry id + source; only those can be opened in full', () {
      final i = BehaviourItem.fromJson({'_id': 'abc', 'source': 'records', 'title': 'T', 'type': 'negative', 'points': -2});
      expect(i.isRecord, isTrue);
      expect(i.title, 'T');
      expect(BehaviourItem.fromJson({'_id': 'abc', 'source': 'legacy'}).isRecord, isFalse);
      expect(BehaviourItem.fromJson({'description': 'old server, no id / source'}).isRecord, isFalse);
    });
  });

  group('BehaviourRepository requests', () {
    test('fetchRecordsPage sends grade, filters, page and limit; meta.pages tells if there is more', () async {
      final c = _Client((m, p, q, b) => {'data': [{'_id': 'r1', 'studentId': 's1'}], 'meta': {'total': 120, 'page': '1', 'limit': '50', 'pages': 3}});
      final page = await BehaviourRepository(c).fetchRecordsPage(
        grade: 'Grade 5', filters: const RecordFilters(type: 'negative', resolved: false), page: 2, limit: 50);
      expect(c.calls.single.path, '/behaviour/records');
      expect(c.calls.single.q, {'grade': 'Grade 5', 'type': 'negative', 'resolved': 'false', 'limit': 50, 'page': 2});
      expect(page.pages, 3);
      expect(page.total, 120);
      expect(page.records.single.id, 'r1');
    });

    test('student query, section and mine are only sent when asked for', () async {
      final c = _Client((m, p, q, b) => {'data': [], 'meta': {'total': 0, 'pages': 1}});
      await BehaviourRepository(c).fetchRecordsPage(studentId: 'st1');
      await BehaviourRepository(c).fetchRecordsPage(grade: 'G', section: 'A', mine: true);
      expect(c.calls[0].q!.keys.toSet(), {'studentId', 'limit', 'page'});
      expect(c.calls[1].q, {'grade': 'G', 'section': 'A', 'mine': 'true', 'limit': 100, 'page': 1});
    });

    test('update is a PUT of the body; resolve a PATCH with the trimmed note; fetchRecord a GET by id', () async {
      final c = _Client((m, p, q, b) => {'_id': 'r9', 'title': 'x'});
      final repo = BehaviourRepository(c);
      await repo.update('r9', {'title': 'x'});
      await repo.resolve('r9', note: '  fixed  ');
      await repo.fetchRecord('r9');
      expect(c.calls.map((e) => '${e.method} ${e.path}'), ['PUT /behaviour/records/r9', 'PATCH /behaviour/records/r9/resolve', 'GET /behaviour/records/r9']);
      expect(c.calls[0].body, {'title': 'x'});
      expect(c.calls[1].body, {'note': 'fixed'});
    });

    test('character settings and the points total', () async {
      final c = _Client((m, p, q, b) => p.endsWith('/character-settings')
          ? {'moduleDisplayName': 'Akhlaq', 'characteristics': [], 'ratingScale': {'min': 1, 'max': 5}}
          : {'pointsTotal': -7, 'records': []});
      final repo = BehaviourRepository(c);
      expect((await repo.fetchCharacterSettings()).programName, 'Akhlaq');
      expect(await repo.fetchPointsTotal('st1'), -7);
      expect(c.calls.last.path, '/behaviour/students/st1/profile');
    });

    test('a 403 surfaces as an ApiException with the status (callers show a friendly message)', () async {
      final c = _Client((m, p, q, b) => 403);
      expect(() => BehaviourRepository(c).update('r1', {}), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)));
      expect(() => BehaviourRepository(c).resolve('r1'), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)));
      expect(() => BehaviourRepository(c).fetchRecord('r1'), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)));
    });
  });

  test('jsonDecode sanity of the wire day', () => expect(jsonEncode({'d': wireDayForTest()}), contains('2026-10-01')));
}

String wireDayForTest() => '2026-10-01';
