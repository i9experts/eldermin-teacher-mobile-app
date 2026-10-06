import 'package:get/get.dart';
import '../../../../core/models/assessments/reference_models.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/services/reference_repository.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/models/section_state.dart';

/// Library catalogue search, read-only (`/library`): `GET /academics/library/books?search&category&available=true&page&limit=20`
/// (academics.service.ts:497-518). `search` is a MongoDB text search: WHOLE WORDS, not substrings (so "fract" finds nothing, "fractions"
/// does). NO issue / return / renew / fine / reservation, and `GET .../books/:id` is NOT used (it writes and returns borrower history).
class LibraryController extends GetxController {
  final ReferenceRepository? _repo;
  final AuthController? _auth;
  final PermissionService? _perms;

  LibraryController({ReferenceRepository? repository, AuthController? auth, PermissionService? permissions})
      : _repo = repository,
        _auth = auth,
        _perms = permissions;

  ReferenceRepository get repo => _repo ?? Get.find<ReferenceRepository>();
  AuthController get auth => _auth ?? Get.find<AuthController>();
  PermissionService get perms => _perms ?? Get.find<PermissionService>();

  final state = Rx<SectionState<List<Book>>>(const SectionState.loading());
  final query = ''.obs;
  final category = ''.obs;
  final availableOnly = false.obs;
  final loadingMore = false.obs;
  final loadMoreError = RxnString();
  final total = RxnInt();
  int _page = 1;
  bool _hasMore = false;
  int _token = 0;

  bool get canView {
    auth.staffMe.value;
    return perms.canAccess('academics:view');
  }

  List<Book> get books => state.value.data ?? const [];
  bool get hasMore => _hasMore;
  bool get filtersActive => query.value.trim().isNotEmpty || category.value.isNotEmpty || availableOnly.value;

  @override
  void onReady() {
    super.onReady();
    load();
  }

  Future<void> load({bool force = false}) async {
    if (!canView) {
      state.value = const SectionState.forbidden();
      return;
    }
    if (!force && state.value.hasData) return;
    final token = ++_token;
    if (!state.value.hasData) state.value = const SectionState.loading();
    loadMoreError.value = null;
    try {
      final p = await repo.books(search: query.value, category: category.value, availableOnly: availableOnly.value, page: 1);
      if (token != _token) return;
      _page = 1;
      _hasMore = p.hasMore;
      total.value = p.total;
      state.value = p.items.isEmpty ? const SectionState.empty() : SectionState.data(p.items);
    } catch (e) {
      if (token != _token) return;
      state.value = SectionState<List<Book>>.fromError(e);
    }
  }

  Future<void> reload() => load(force: true);

  /// Next page (appended; ids already shown are skipped).
  Future<void> loadMore() async {
    if (loadingMore.value || !_hasMore || !state.value.hasData) return;
    final token = _token;
    loadingMore.value = true;
    loadMoreError.value = null;
    try {
      final p = await repo.books(search: query.value, category: category.value, availableOnly: availableOnly.value, page: _page + 1);
      if (token != _token) return;
      _page += 1;
      _hasMore = p.hasMore;
      final seen = {for (final b in books) b.id};
      state.value = SectionState.data([...books, for (final b in p.items) if (!seen.contains(b.id)) b]);
    } catch (_) {
      if (token == _token) loadMoreError.value = "Couldn't load more books. Tap to retry.";
    } finally {
      loadingMore.value = false;
    }
  }

  Future<void> setQuery(String q) async {
    if (q.trim() == query.value.trim()) return;
    query.value = q;
    await load(force: true);
  }

  Future<void> setCategory(String c) async {
    category.value = c;
    await load(force: true);
  }

  Future<void> toggleAvailable(bool v) async {
    availableOnly.value = v;
    await load(force: true);
  }

  Future<void> clearFilters() async {
    query.value = '';
    category.value = '';
    availableOnly.value = false;
    await load(force: true);
  }
}
