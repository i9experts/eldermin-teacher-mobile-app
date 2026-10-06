import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/models/academic/syllabus_models.dart';
import '../../../../core/services/syllabus_repository.dart';
import '../../home/models/section_state.dart';
import 'syllabus_controller.dart';

typedef UrlOpener = Future<bool> Function(Uri url);
Future<bool> _defaultOpener(Uri url) => launchUrl(url, mode: LaunchMode.externalApplication);

/// One syllabus (`/syllabus/:id`): from the list controller's cache; a cold link (no list yet) loads the list first and, when the id is
/// not in it, `GET /syllabus/:id` (which has NO owner / campus check, syllabus.service.ts:112-116) followed by the same scope test as the
/// list: a syllabus that is not mine is refused and dropped.
class SyllabusDetailController extends GetxController {
  final String id;
  final SyllabusController? _list;
  final SyllabusRepository? _repo;
  final UrlOpener _open;

  SyllabusDetailController({required this.id, SyllabusController? list, SyllabusRepository? repository, UrlOpener? opener})
      : _list = list,
        _repo = repository,
        _open = opener ?? _defaultOpener;

  SyllabusController get list => _list ?? Get.find<SyllabusController>();
  SyllabusRepository get repo => _repo ?? Get.find<SyllabusRepository>();

  final state = Rx<SectionState<Syllabus>>(const SectionState.loading());

  /// Expanded topic keys (`<unit>:<topic>`).
  final expanded = <String>{}.obs;

  @override
  void onReady() {
    super.onReady();
    load();
  }

  static String topicKey(int unitNo, int topicNo) => '$unitNo:$topicNo';

  void toggleTopic(int unitNo, int topicNo) {
    final k = topicKey(unitNo, topicNo);
    if (!expanded.remove(k)) expanded.add(k);
  }

  Future<void> load({bool force = false}) async {
    if (force) {
      await list.load(force: true);
    } else {
      await list.ensureLoaded();
    }
    final ls = list.state.value;
    if (ls.status == SectionStatus.forbidden) {
      state.value = const SectionState.forbidden();
      return;
    }
    final s = list.byId(id);
    if (s != null) {
      state.value = SectionState.data(s);
      return;
    }
    if (ls.status == SectionStatus.error) {
      state.value = SectionState.error(ls.message ?? "Couldn't load this syllabus.");
      return;
    }
    try {
      final one = await repo.one(id);
      if (!list.inScope(one)) {
        state.value = const SectionState.error("This syllabus isn't one of yours.");
        return;
      }
      list.upsert(one);
      state.value = SectionState.data(one);
    } catch (e) {
      state.value = SectionState<Syllabus>.fromError(e);
    }
  }

  /// Opens a lesson's link outside the app (read-only content). Only http(s) links are opened.
  Future<bool> openLesson(SyllabusLesson l) async {
    final u = Uri.tryParse(l.link);
    if (u == null || !(u.scheme == 'https' || u.scheme == 'http')) return false;
    try {
      return await _open(u);
    } catch (_) {
      return false;
    }
  }
}
