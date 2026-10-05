import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/models/homework/homework_models.dart';
import '../../../../core/services/homework_repository.dart';
import '../../../../core/utils/home_time.dart';
import '../../../../core/utils/timetable_week.dart' show dateOnly;
import '../../../common/action_failure.dart';
import '../../home/models/section_state.dart';
import 'homework_controller.dart';

typedef UrlOpener = Future<bool> Function(Uri url);

/// Opens [url] outside the app (browser / viewer).
Future<bool> defaultUrlOpener(Uri url) => launchUrl(url, mode: LaunchMode.externalApplication);

/// Outcome of a detail action (assign / delete / open file).
sealed class DetailResult {
  const DetailResult();
}

class DetailOk extends DetailResult {
  const DetailOk();
}

class DetailFailed extends DetailResult {
  final ActionFailure failure;
  const DetailFailed(this.failure);
}

class DetailIgnored extends DetailResult {
  const DetailIgnored();
}

/// One assignment (`/homework/:id`). The data comes from the list controller's cache; there is NO `GET /teaching/assignments/:id`, so a
/// cold deep link falls back to `GET /assignments/:id/submissions`, whose payload carries the full `assignment` document.
class HomeworkDetailController extends GetxController {
  final String id;
  final HomeworkRepository? _repo;
  final HomeworkController? _list;
  final UrlOpener _open;
  final Clock clock;

  HomeworkDetailController({required this.id, HomeworkRepository? repository, HomeworkController? list, UrlOpener? opener, Clock? clock})
      : _repo = repository,
        _list = list,
        _open = opener ?? defaultUrlOpener,
        clock = clock ?? DateTime.now;

  HomeworkRepository get repo => _repo ?? Get.find<HomeworkRepository>();
  HomeworkController get list => _list ?? Get.find<HomeworkController>();

  /// Set only when the assignment was not in the list cache (deep link) and had to be fetched.
  final fallback = Rx<SectionState<Assignment>>(const SectionState.loading());
  final busy = false.obs;
  final deleted = false.obs;
  final openingKey = RxnString();

  DateTime get today => dateOnly(clock());

  /// The assignment to show, reactive on the list controller's state.
  SectionState<Assignment> get state {
    if (deleted.value) return const SectionState.empty();
    final cached = list.byId(id);
    if (cached != null) return SectionState.data(cached);
    // a deleted assignment disappears from the list: fallback keeps the last known value only if it was fetched
    return fallback.value;
  }

  Assignment? get assignment => state.data;

  @override
  void onReady() {
    super.onReady();
    if (list.byId(id) == null) load();
  }

  Future<void> load() async {
    fallback.value = const SectionState.loading();
    try {
      final res = await repo.fetchSubmissions(id);
      if (res.assignment.id.isEmpty) {
        fallback.value = const SectionState.unavailable();
        return;
      }
      fallback.value = SectionState.data(res.assignment);
    } catch (e) {
      fallback.value = SectionState<Assignment>.fromError(e);
    }
  }

  Future<void> reload() async {
    await list.load(force: true);
    if (list.byId(id) == null) await load();
  }

  /// Draft -> assigned: `PATCH { status: 'assigned' }`; the server then creates the roster snapshot and notifies guardians
  /// (teaching.service.ts:910-920, 949-979).
  Future<DetailResult> assign() async {
    final a = assignment;
    if (busy.value || a == null || !a.isDraft) return const DetailIgnored();
    busy.value = true;
    try {
      final saved = await repo.update(a.id, {'status': 'assigned'});
      list.upsert(saved);
      return const DetailOk();
    } catch (e) {
      return DetailFailed(ActionFailure.from(e, what: 'assign this homework', keep: ''));
    } finally {
      busy.value = false;
    }
  }

  /// `DELETE /teaching/assignments/:id`: also deletes every submission and grade of it (teaching.service.ts:922-929).
  Future<DetailResult> delete() async {
    final a = assignment;
    if (busy.value || a == null) return const DetailIgnored();
    busy.value = true;
    try {
      await repo.delete(a.id);
      deleted.value = true;
      list.remove(a.id);
      return const DetailOk();
    } catch (e) {
      return DetailFailed(ActionFailure.from(e, what: 'delete this homework', keep: ''));
    } finally {
      busy.value = false;
    }
  }

  /// Resolves an attachment key to a time-limited link (`GET /upload/signed-url?key=`) and opens it outside the app.
  Future<DetailResult> openAttachment(String key) async {
    if (openingKey.value != null) return const DetailIgnored();
    openingKey.value = key;
    try {
      final url = await repo.signedUrl(key);
      final ok = await _open(Uri.parse(url));
      if (!ok) return const DetailFailed(ActionFailure(ActionFailureKind.other, "Couldn't open this file on your device."));
      return const DetailOk();
    } catch (e) {
      return DetailFailed(ActionFailure.from(e, what: 'open this file', keep: ''));
    } finally {
      openingKey.value = null;
    }
  }
}
