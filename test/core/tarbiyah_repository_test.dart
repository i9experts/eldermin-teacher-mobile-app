// A1 item 9 (core): Tarbiyah create / edit requests and the draft payloads.
import 'package:dio/dio.dart';
import 'package:eldermin_teacher_app/core/models/behaviour/behaviour_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/network/base_client.dart';
import 'package:eldermin_teacher_app/core/network/response_shape.dart';
import 'package:eldermin_teacher_app/core/services/behaviour_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _Client extends BaseClient {
  final Object? Function(String method, String path, dynamic body) handler;
  final calls = <({String method, String path, dynamic body})>[];
  _Client(this.handler);

  Response _respond(String method, String url, dynamic body) {
    final path = Uri.parse(url).path.replaceFirst('/api/v1', '');
    calls.add((method: method, path: path, body: body));
    final ro = RequestOptions(path: url);
    final r = handler(method, path, body);
    if (r is int) {
      throw DioException(requestOptions: ro, type: DioExceptionType.badResponse, response: Response(requestOptions: ro, statusCode: r, data: {'statusCode': r, 'message': 'msg $r'}));
    }
    return Response(requestOptions: ro, statusCode: method == 'POST' ? 201 : 200, data: r);
  }

  @override
  Future<Response> post(String url, {dynamic data, Map<String, dynamic>? queryParameters, bool requiresAuth = true, Map<String, String>? headers}) async => _respond('POST', url, data);
  @override
  Future<Response> put(String url, {dynamic data, Map<String, dynamic>? queryParameters, bool requiresAuth = true, Map<String, String>? headers}) async => _respond('PUT', url, data);
}

final _saved = {
  '_id': 'ta1',
  'studentId': 's1',
  'period': 'Term 1',
  'periodType': 'termly',
  'assessmentDate': '2026-10-05T00:00:00.000Z',
  'traits': [
    {'traitKey': 'sidq', 'score': 4}
  ],
  'overallPercentage': 75,
  'overallRating': 'good',
  'assessedBy': 'Tess Teacher',
  'assessedById': 'u',
};

void main() {
  final draft = TarbiyahDraft(
    periodType: 'termly',
    period: ' Term 1 ',
    day: DateTime(2026, 10, 5),
    scores: const {'sidq': 4, 'adab': 5},
    observations: ' ok ',
    strengths: const ['Honest'],
    improvements: const [],
  );

  test('create: POST /behaviour/tarbiyah with the draft; the answer is parsed (author id kept)', () async {
    final c = _Client((m, p, b) => _saved);
    final a = await BehaviourRepository(c).createTarbiyah(draft.toCreateJson(studentId: 's1', studentName: 'Zara Malik', grade: 'Grade 5', section: 'A'));
    expect(c.calls.single.method, 'POST');
    expect(c.calls.single.path, '/behaviour/tarbiyah');
    final b = c.calls.single.body as Map;
    expect(b['studentId'], 's1');
    expect(b['studentName'], 'Zara Malik');
    expect(b['period'], 'Term 1');
    expect(b['assessmentDate'], '2026-10-05');
    expect(b['teacherObservations'], 'ok');
    expect(b['traits'], [
      {'traitKey': 'sidq', 'score': 4},
      {'traitKey': 'adab', 'score': 5}
    ]);
    expect(a.id, 'ta1');
    expect(a.assessedById, 'u');
  });

  test('a student without a section sends no section key', () {
    final b = draft.toCreateJson(studentId: 's1', studentName: 'Z', grade: 'Grade 5', section: '');
    expect(b.containsKey('section'), isFalse);
  });

  test('edit: PUT /behaviour/tarbiyah/:id with only the editable fields', () async {
    final c = _Client((m, p, b) => _saved);
    await BehaviourRepository(c).updateTarbiyah('ta1', draft.toUpdateJson());
    expect(c.calls.single.method, 'PUT');
    expect(c.calls.single.path, '/behaviour/tarbiyah/ta1');
    expect((c.calls.single.body as Map).keys.toSet(), {'period', 'periodType', 'assessmentDate', 'traits', 'teacherObservations', 'areasOfStrength', 'areasForImprovement'});
  });

  test('403 / 404 / 400 surface as ApiException with the status; a non-object answer is an unexpected-shape error', () async {
    for (final s in [400, 403, 404, 500]) {
      await expectLater(BehaviourRepository(_Client((m, p, b) => s)).createTarbiyah({}), throwsA(isA<ApiException>().having((e) => e.statusCode, 's', s)));
      await expectLater(BehaviourRepository(_Client((m, p, b) => s)).updateTarbiyah('x', {}), throwsA(isA<ApiException>().having((e) => e.statusCode, 's', s)));
    }
    await expectLater(BehaviourRepository(_Client((m, p, b) => [1])).createTarbiyah({}), throwsA(isA<UnexpectedResponseShape>()));
  });
}
