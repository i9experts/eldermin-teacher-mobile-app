import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/help/kb_models.dart';
import '../network/base_client.dart';
import '../network/dio_exception_handler.dart';
import '../network/response_shape.dart';

/// Knowledge base, read only (eldermin-backend `modules/knowledge-base/knowledge-base.controller.ts` = KC, `.service.ts` = KS). Any authenticated user.
class KbRepository {
  final BaseClient _client;
  KbRepository([BaseClient? client]) : _client = client ?? BaseClient();

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw DioExceptionHandler.handle(e);
    }
  }

  /// `GET /kb/articles[?module=]` (KC:24-27 -> KS:46-50): bare array sorted by `order`, no paging.
  Future<List<KbArticle>> list({String? module}) => _guard(() async {
        final res = await _client.get(ApiConstants.kbArticles, queryParameters: {if (module != null && module.isNotEmpty) 'module': module});
        return parseKbArticles(expectRows(res.data, what: 'help articles'));
      });

  /// `GET /kb/search?q=` (KC:30-33 -> KS:61-67; NOT `/kb/articles/search`, which would not match any route): bare array, an empty / blank `q` answers `[]`.
  Future<List<KbArticle>> search(String q) => _guard(() async {
        final res = await _client.get(ApiConstants.kbSearch, queryParameters: {'q': q});
        return parseKbArticles(expectRows(res.data, what: 'help search'));
      });

  /// `GET /kb/articles/:module/:tabKey` (KC:36-39 -> KS:53-59): one article; 404 'No KB article found for <module>/<tabKey>'.
  Future<KbArticle> article(String module, String tabKey) => _guard(() async {
        final res = await _client.get(ApiConstants.kbArticle(module, tabKey));
        final a = KbArticle.tryParse(expectMap(res.data, what: 'the help article'));
        if (a == null) throw UnexpectedResponseShape('the help article', 'module / tabKey / title missing');
        return a;
      });
}
