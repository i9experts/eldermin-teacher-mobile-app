import 'dart:io';
import 'package:dio/dio.dart';
import 'package:eldermin_teacher_app/core/models/early_years/ece_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/network/base_client.dart';
import 'package:eldermin_teacher_app/core/services/early_years_repository.dart';
import 'package:flutter_test/flutter_test.dart';

typedef Call = ({String method, String path, Map<String, dynamic>? q, dynamic body, Map<String, String>? headers});

class _Client extends BaseClient {
  final Object? Function(String method, String path, Map<String, dynamic>? q, dynamic body) handler;
  final calls = <Call>[];
  _Client(this.handler);

  Response _respond(String method, String url, Map<String, dynamic>? q, dynamic body, Map<String, String>? headers) {
    final path = Uri.parse(url).path.replaceFirst('/api/v1', '');
    calls.add((method: method, path: path, q: q, body: body, headers: headers));
    final ro = RequestOptions(path: url);
    final r = handler(method, path, q, body);
    if (r is int) {
      throw DioException(
          requestOptions: ro,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: ro, statusCode: r, data: {'statusCode': r, 'message': r == 503 ? 'File uploads are not available on this server (storage is not configured).' : 'nope'}));
    }
    return Response(requestOptions: ro, statusCode: method == 'POST' ? 201 : 200, data: r);
  }

  @override
  Future<Response> get(String url, {Map<String, dynamic>? queryParameters, bool requiresAuth = true, Map<String, String>? headers}) async =>
      _respond('GET', url, queryParameters, null, headers);
  @override
  Future<Response> post(String url, {dynamic data, Map<String, dynamic>? queryParameters, bool requiresAuth = true, Map<String, String>? headers}) async =>
      _respond('POST', url, queryParameters, data, headers);
  @override
  Future<Response> multipart(String url,
          {required Map<String, List<MultipartFile>> files,
          Map<String, dynamic>? fields,
          String method = 'POST',
          void Function(int sent, int total)? onSendProgress,
          bool requiresAuth = true}) async {
    final f = files['file']!.single;
    onSendProgress?.call(5, 10);
    return _respond('MULTIPART', url, null, {'field': 'file', 'filename': f.filename, 'type': f.contentType?.toString()}, null);
  }
}

const _years = [
  {'name': '2024-25', 'isCurrent': false},
  {'name': '2025-26', 'isCurrent': true},
];

Object? _routes(String m, String p, Map<String, dynamic>? q, dynamic b) {
  switch ('$m $p') {
    case 'GET /organization/academic-years':
      return _years;
    case 'GET /ece/children':
      return [{'_id': 'c1', 'firstName': 'A', 'lastName': 'B', 'currentGrade': 'Nursery', 'allergies': ['x']}];
    case 'GET /ece/domains':
      return [{'_id': 'd2', 'name': 'Second', 'order': 2}, {'_id': 'd1', 'name': 'First', 'order': 1}];
    case 'GET /ece/skills':
      return [{'_id': 's1', 'domainId': 'd1', 'name': 'Pencil'}];
    case 'GET /ece/frameworks':
      return [{'_id': 'f', 'name': 'F', 'progressionLevels': ['Low', 'High']}];
    case 'GET /ece/students/c1/profile':
      return {'domainSummaries': [], 'interests': [], 'schemas': []};
    case 'GET /ece/observations':
      return [{'_id': 'o1', 'narrative': 'n'}];
    case 'GET /ece/students/c1/portfolio':
      return [{'_id': 'p1', 'title': 't'}];
    case 'POST /ece/observations/quick':
    case 'POST /ece/observations':
      return {'_id': 'o9', ...(b as Map)};
    case 'POST /ece/portfolio':
      return {'_id': 'p9', ...(b as Map)};
    case 'GET /upload/signed-url':
      return {'url': 'https://signed.example/x'};
    case 'MULTIPART /upload/single/ece-evidence':
      return {'success': true, 'data': {'url': 'https://b.s3.x.amazonaws.com/s/ece-evidence/p.jpg', 'key': 's/ece-evidence/p.jpg', 'fileName': 'p.jpg'}};
  }
  return 404;
}

void main() {
  group('x-academic-year on every Early Years call', () {
    test('reads and creates all carry the school\'s current year; the year lookup itself does not', () async {
      final c = _Client(_routes);
      final r = EarlyYearsRepository(c);
      await r.fetchChildren();
      await r.fetchDomains();
      await r.fetchSkills(domainId: 'd1');
      await r.fetchProgressionLevels();
      await r.fetchProfile('c1');
      await r.fetchObservations('c1');
      await r.fetchPortfolio('c1');
      await r.createQuickObservation(const EceQuickObservationDraft(studentId: 'c1', skillId: 's1', level: 'Low'));
      await r.createObservation(const EceObservationDraft(studentId: 'c1', narrative: 'n'));
      await r.createPortfolioEntry(const EcePortfolioDraft(studentId: 'c1', title: 't', narrative: 'n'));
      final ey = c.calls.where((x) => x.path.startsWith('/ece/')).toList();
      expect(ey, hasLength(10));
      for (final call in ey) {
        expect(call.headers, {'x-academic-year': '2025-26'}, reason: '${call.method} ${call.path}');
      }
      final lookups = c.calls.where((x) => x.path == '/organization/academic-years').toList();
      expect(lookups, hasLength(1), reason: 'looked up once, then cached');
      expect(lookups.single.headers, isNull);
    });

    test('no year flagged current: reads go without the header, creates refuse and send nothing', () async {
      final c = _Client((m, p, q, b) => p == '/organization/academic-years' ? [{'name': '2024-25', 'isCurrent': false}] : _routes(m, p, q, b));
      final r = EarlyYearsRepository(c);
      await r.fetchChildren();
      expect(c.calls.last.headers, isNull);
      await expectLater(r.createObservation(const EceObservationDraft(studentId: 'c1', narrative: 'n')), throwsA(isA<AcademicYearUnknown>()));
      await expectLater(r.createQuickObservation(const EceQuickObservationDraft(studentId: 'c1', skillId: 's', level: 'L')), throwsA(isA<AcademicYearUnknown>()));
      await expectLater(r.createPortfolioEntry(const EcePortfolioDraft(studentId: 'c1', title: 't', narrative: 'n')), throwsA(isA<AcademicYearUnknown>()));
      expect(c.calls.where((x) => x.method == 'POST'), isEmpty);
    });

    test('a failed lookup is not remembered: the next call tries again', () async {
      var fail = true;
      final c = _Client((m, p, q, b) => p == '/organization/academic-years' ? (fail ? 500 : _years) : _routes(m, p, q, b));
      final r = EarlyYearsRepository(c);
      await r.fetchChildren();
      expect(c.calls.last.headers, isNull);
      fail = false;
      await r.fetchChildren();
      expect(c.calls.last.headers, {'x-academic-year': '2025-26'});
    });

    test('an odd lookup body is treated as "unknown", never a crash', () async {
      final c = _Client((m, p, q, b) => p == '/organization/academic-years' ? 'not json rows' : _routes(m, p, q, b));
      expect(await EarlyYearsRepository(c).currentAcademicYear(), isNull);
    });
  });

  group('requests and parsing', () {
    test('children: parsed with the allow-list model (allergy data in the row never surfaces)', () async {
      final list = await EarlyYearsRepository(_Client(_routes)).fetchChildren();
      expect(list.single.fullName, 'A B');
      expect('${list.single.fullName}${list.single.classLabel}${list.single.studentCode}', isNot(contains('x')));
    });

    test('domains sorted by order; skills filtered by domain; levels from the first framework', () async {
      final c = _Client(_routes);
      final r = EarlyYearsRepository(c);
      expect((await r.fetchDomains()).map((d) => d.id), ['d1', 'd2']);
      await r.fetchSkills(domainId: 'd1');
      expect(c.calls.firstWhere((x) => x.path == '/ece/skills').q, {'domainId': 'd1'});
      expect(await r.fetchProgressionLevels(), ['Low', 'High']);
    });

    test('observations are asked for one child', () async {
      final c = _Client(_routes);
      await EarlyYearsRepository(c).fetchObservations('c1');
      expect(c.calls.firstWhere((x) => x.path == '/ece/observations').q, {'studentId': 'c1'});
    });

    test('create bodies are exactly the drafts', () async {
      final c = _Client(_routes);
      final r = EarlyYearsRepository(c);
      await r.createQuickObservation(const EceQuickObservationDraft(studentId: 'c1', skillId: 's1', level: 'Low'));
      await r.createObservation(const EceObservationDraft(studentId: 'c1', narrative: 'n', shareWithFamily: true));
      await r.createPortfolioEntry(const EcePortfolioDraft(studentId: 'c1', title: 't', narrative: 'n'));
      final posts = c.calls.where((x) => x.method == 'POST').toList();
      expect(posts[0].path, '/ece/observations/quick');
      expect(posts[0].body, {'studentId': 'c1', 'skillId': 's1', 'progressionLevel': 'Low'});
      expect(posts[1].path, '/ece/observations');
      expect((posts[1].body as Map)['isSharedWithFamily'], isTrue);
      expect(posts[2].path, '/ece/portfolio');
      expect((posts[2].body as Map)['isVisibleToFamily'], isFalse);
    });

    test('server errors are mapped, not leaked as DioException', () async {
      final r = EarlyYearsRepository(_Client((m, p, q, b) => p == '/ece/children' ? 403 : _routes(m, p, q, b)));
      await expectLater(r.fetchChildren(), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)));
    });

    test('an object where a list is expected is a typed shape error', () async {
      final r = EarlyYearsRepository(_Client((m, p, q, b) => p == '/ece/children' ? {'oops': true} : _routes(m, p, q, b)));
      await expectLater(r.fetchChildren(), throwsA(isA<Exception>()));
    });
  });

  group('photos', () {
    late File photo;
    setUp(() async {
      final dir = await Directory.systemTemp.createTemp('ey_upload');
      photo = File('${dir.path}/p.jpg')..writeAsBytesSync([1, 2, 3]);
    });

    test('upload goes to the ece-evidence folder with an image type and returns url + key', () async {
      final c = _Client(_routes);
      var seen = 0;
      final up = await EarlyYearsRepository(c).uploadEvidence(path: photo.path, fileName: 'p.jpg', onProgress: (s, t) => seen = s);
      expect(c.calls.single.path, '/upload/single/ece-evidence');
      expect(c.calls.single.body, {'field': 'file', 'filename': 'p.jpg', 'type': contains('image/jpeg')});
      expect(up.key, 's/ece-evidence/p.jpg');
      expect(up.url, startsWith('https://'));
      expect(seen, 5);
    });

    test('503 (storage not configured) surfaces with its status so the form can say uploads are unavailable', () async {
      final r = EarlyYearsRepository(_Client((m, p, q, b) => m == 'MULTIPART' ? 503 : _routes(m, p, q, b)));
      await expectLater(r.uploadEvidence(path: photo.path, fileName: 'p.jpg'), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 503)));
    });

    test('a reply with no file reference is an error', () async {
      final r = EarlyYearsRepository(_Client((m, p, q, b) => m == 'MULTIPART' ? {'success': true} : _routes(m, p, q, b)));
      await expectLater(r.uploadEvidence(path: photo.path, fileName: 'p.jpg'), throwsA(isA<ApiException>()));
    });

    test('signed link for a key', () async {
      final c = _Client(_routes);
      expect(await EarlyYearsRepository(c).signedUrl('s/ece-evidence/p.jpg'), 'https://signed.example/x');
      expect(c.calls.single.q, {'key': 's/ece-evidence/p.jpg'});
    });
  });

  test('the repository exposes no care, allergy or support call', () {
    final src = File('lib/core/services/early_years_repository.dart')
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    expect(src, isNot(matches(RegExp(r'care-records|allergies|support-cases|fetchCare|fetchAllerg|fetchSupport', caseSensitive: false))));
    final consts = File('lib/core/constants/api_constants.dart').readAsStringSync();
    expect(consts, isNot(contains('/ece/care-records')));
    expect(consts, isNot(contains('/allergies')));
    expect(consts, isNot(contains('/ece/support-cases')));
  });
}
