import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/paginated.dart';
import '../models/assessments/reference_models.dart';
import '../network/api_exception.dart';
import '../network/base_client.dart';
import '../network/response_shape.dart';
import '../network/dio_exception_handler.dart';

/// Read-only curriculum and library catalogue (eldermin-backend/src/modules/academics/: ACC controller, ACS service).
/// NOT used on purpose: POST/PATCH curriculum, :id/slo, library books create/update/deaccession, issue / return / renew / fine-paid / lost /
/// damaged, reservations, settings, reports, `GET library/books/:id` (it WRITES via ensureCopies and returns borrower history, ACS:520-533)
/// and `GET library/search` (unscoped by campus, 20 rows, no availability filter).
class ReferenceRepository {
  final BaseClient _client;
  ReferenceRepository([BaseClient? client]) : _client = client ?? BaseClient();

  static const int bookPageSize = 20;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw DioExceptionHandler.handle(e);
    }
  }

  /// `GET /academics/curriculum?status=active` (ACC:111-114 -> ACS:375-383): bare array, tenant-wide, no teacher/campus scoping.
  Future<List<Curriculum>> curricula() => _guard(() async {
        final res = await _client.get(ApiConstants.curriculum, queryParameters: {'status': 'active'});
        final rows = expectRows(res.data, what: 'the curriculum');
        return rows.map(Curriculum.fromJson).where((c) => c.id.isNotEmpty).toList();
      });

  /// `GET /academics/curriculum/:id` (ACC:123-126): 404 "Curriculum not found".
  Future<Curriculum> curriculum(String id) => _guard(() async {
        final res = await _client.get(ApiConstants.curriculumById(id));
        final c = Curriculum.fromJson(expectMap(res.data, what: 'this curriculum'));
        if (c.id.isEmpty) throw ApiException('Curriculum not found', statusCode: 404);
        return c;
      });

  /// `GET /academics/library/books?page&limit&search&category&available=true` (ACC:165-168 -> ACS:497-518): `{data, meta}`. `search` is a
  /// MongoDB text search (whole words, not substrings). Deaccessioned books are excluded by the server by default.
  Future<Paginated<Book>> books({String search = '', String category = '', bool availableOnly = false, int page = 1}) => _guard(() async {
        final res = await _client.get(ApiConstants.libraryBooks, queryParameters: {
          'page': page,
          'limit': bookPageSize,
          if (search.trim().isNotEmpty) 'search': search.trim(),
          if (category.isNotEmpty) 'category': category,
          if (availableOnly) 'available': 'true',
        });
        final p = Paginated<Book>.parse(res.data, Book.fromJson, what: 'library books');
        return Paginated<Book>(items: [...p.items.where((b) => b.id.isNotEmpty)], total: p.total, page: p.page, limit: p.limit, pages: p.pages);
      });
}
