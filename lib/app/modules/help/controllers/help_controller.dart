import 'package:get/get.dart';
import '../../../../core/models/help/kb_models.dart';
import '../../../../core/services/kb_repository.dart';
import '../../home/models/section_state.dart';

/// Help (`/help`): the knowledge base list grouped by module, and search (`GET /kb/search?q=`, submitted, not per keystroke).
class HelpController extends GetxController {
  final KbRepository? _repo;
  HelpController({KbRepository? repository}) : _repo = repository;
  KbRepository get repo => _repo ?? Get.find<KbRepository>();

  final list = Rx<SectionState<List<KbArticle>>>(const SectionState.loading());
  final query = ''.obs;
  final results = Rx<SectionState<List<KbArticle>>?>(null);
  int _lt = 0, _st = 0;

  bool get searching => results.value != null;

  @override
  void onReady() {
    super.onReady();
    load();
  }

  Future<void> load({bool userInitiated = false}) async {
    final token = ++_lt;
    final previous = list.value;
    if (!previous.hasData) list.value = const SectionState.loading();
    try {
      final rows = await repo.list();
      if (token != _lt) return;
      list.value = rows.isEmpty ? const SectionState.empty() : SectionState.data(rows);
    } catch (e) {
      if (token != _lt) return;
      final failed = SectionState<List<KbArticle>>.fromError(e);
      list.value = previous.hasData && failed.status == SectionStatus.error && !userInitiated ? previous : failed;
    }
    if (searching && userInitiated) await search(query.value);
  }

  /// Groups by module (module order = first appearance in the server's `order` sort), articles by `order`.
  Map<String, List<KbArticle>> get grouped {
    final out = <String, List<KbArticle>>{};
    for (final a in list.value.data ?? const <KbArticle>[]) {
      (out[a.module] ??= []).add(a);
    }
    for (final l in out.values) {
      l.sort((a, b) => a.order.compareTo(b.order));
    }
    return out;
  }

  Future<void> search(String q) async {
    final text = q.trim();
    query.value = q;
    if (text.isEmpty) {
      clearSearch();
      return;
    }
    final token = ++_st;
    results.value = const SectionState.loading();
    try {
      final rows = await repo.search(text);
      if (token != _st) return;
      results.value = rows.isEmpty ? const SectionState.empty() : SectionState.data(rows);
    } catch (e) {
      if (token != _st) return;
      results.value = SectionState<List<KbArticle>>.fromError(e);
    }
  }

  void clearSearch() {
    _st++;
    query.value = '';
    results.value = null;
  }
}

/// `/help/:module/:tabKey`: shows the list row at once (arguments), then reads the article by key.
class HelpArticleController extends GetxController {
  final KbRepository? _repo;
  final String module, tabKey;
  final KbArticle? initial;
  HelpArticleController({KbRepository? repository, required this.module, required this.tabKey, this.initial}) : _repo = repository;
  KbRepository get repo => _repo ?? Get.find<KbRepository>();

  late final state = Rx<SectionState<KbArticle>>(initial == null ? const SectionState.loading() : SectionState.data(initial!));
  int _t = 0;

  @override
  void onReady() {
    super.onReady();
    load();
  }

  Future<void> load({bool userInitiated = false}) async {
    final token = ++_t;
    final previous = state.value;
    if (!previous.hasData) state.value = const SectionState.loading();
    try {
      final a = await repo.article(module, tabKey);
      if (token != _t) return;
      state.value = SectionState.data(a);
    } catch (e) {
      if (token != _t) return;
      final failed = SectionState<KbArticle>.fromError(e);
      state.value = previous.hasData && failed.status == SectionStatus.error && !userInitiated ? previous : failed;
    }
  }
}
