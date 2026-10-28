import 'package:get/get.dart';
import '../../../../core/models/early_years/ece_models.dart';
import '../../../../core/services/early_years_repository.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/utils/early_years_format.dart';
import '../../../../core/utils/early_years_scope.dart';
import '../../../../core/utils/roster_scope.dart';
import '../../../../core/widgets/detail_bottom_sheet.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/models/section_state.dart';
import 'early_years_controller.dart';

/// The photos of an observation or portfolio entry once they have a viewable link; [failed] counts the ones that could not be given one.
class EcePhotoLinks {
  final List<DetailAttachment> items;
  final int failed;
  const EcePhotoLinks(this.items, this.failed);
}

enum EyTab { progress, observations, portfolio }

/// One domain of the child's development, ready to draw.
class DomainProgress {
  final String domainId;
  final String name;
  final String level;
  final double? fraction;
  final int evidenceCount;
  final DateTime? lastObservedAt;
  const DomainProgress({required this.domainId, required this.name, required this.level, this.fraction, this.evidenceCount = 0, this.lastObservedAt});
}

/// A child's Early Years page (`/early-years/child/:id`): progress by domain, observations and portfolio (all staff-side, so entries not shared
/// with the family are listed too and marked). The three sections load and fail independently.
///
/// The child must be one of MY classes' children (UI-only scoping, see `early_years_scope.dart`): an id outside them shows a plain "not one of
/// your classes" message and loads nothing. Care, allergy and support data are not reachable from this controller.
class EarlyYearsChildController extends GetxController {
  final String childId;
  final EceChild? initial;
  final EarlyYearsRepository? _repo;
  final AuthController? _auth;
  final PermissionService? _perms;
  final DateTime Function() _now;

  EarlyYearsChildController({
    required this.childId,
    this.initial,
    EarlyYearsRepository? repository,
    AuthController? auth,
    PermissionService? permissions,
    DateTime Function()? now,
  })  : _repo = repository,
        _auth = auth,
        _perms = permissions,
        _now = now ?? DateTime.now;

  EarlyYearsRepository get repo => _repo ?? Get.find<EarlyYearsRepository>();
  AuthController get auth => _auth ?? Get.find<AuthController>();
  PermissionService get perms => _perms ?? Get.find<PermissionService>();

  /// How long a signed photo link is reused. The server's link lasts about an hour.
  static const Duration photoLinkTtl = Duration(minutes: 45);

  final childState = Rx<SectionState<EceChild>>(const SectionState.loading());
  final profileState = Rx<SectionState<EceProfile>>(const SectionState.loading());
  final observationsState = Rx<SectionState<List<EceObservation>>>(const SectionState.loading());
  final portfolioState = Rx<SectionState<List<EcePortfolioEntry>>>(const SectionState.loading());
  final tab = EyTab.progress.obs;

  final domains = <EceDomain>[].obs;
  final levels = <String>[].obs;
  final skillNames = <String, String>{}.obs;

  final _photoLinks = <String, ({String url, DateTime at})>{};
  final _photoInFlight = <String, Future<String?>>{};
  int _token = 0;

  bool get canView {
    auth.staffMe.value;
    return perms.canAccess('early-years:view');
  }

  /// Creating observations and portfolio entries also needs `early-years:manage`.
  bool get canManage {
    auth.staffMe.value;
    return perms.canAccess('early-years:manage');
  }

  List<ClassRef> get classes {
    auth.staffMe.value;
    return teacherClassesOf(auth.staffMe.value?.teacherProfile);
  }

  EceChild? get child => childState.value.data;
  String? get ageText => ageLabel(child?.dateOfBirth, _now());

  List<DomainProgress> get progress {
    final p = profileState.value.data;
    if (p == null) return const [];
    final names = {for (final d in domains) d.id: d};
    final lv = levels.isEmpty ? kDefaultProgressionLevels : levels.toList();
    final rows = [
      for (final s in p.domains)
        DomainProgress(
          domainId: s.domainId,
          name: names[s.domainId]?.name ?? 'Learning area',
          level: s.level,
          fraction: levelFraction(s.level, lv),
          evidenceCount: s.evidenceCount,
          lastObservedAt: s.lastObservedAt,
        ),
    ];
    final order = {for (final d in domains) d.id: d.order};
    rows.sort((a, b) => (order[a.domainId] ?? 9999).compareTo(order[b.domainId] ?? 9999));
    return rows;
  }

  @override
  void onReady() {
    super.onReady();
    load();
  }

  void setTab(EyTab t) => tab.value = t;

  Future<void> reload() async {
    await auth.refreshProfile(force: true);
    await load(force: true);
  }

  /// The child's own record if it is one of mine: the one passed in, the list screen's, or a fresh roster fetch. Null + a message state otherwise.
  Future<EceChild?> _resolveChild() async {
    EceChild? k = initial;
    if (k == null && Get.isRegistered<EarlyYearsController>()) k = Get.find<EarlyYearsController>().childById(childId);
    if (k == null) {
      final all = await repo.fetchChildren();
      for (final c in all) {
        if (c.id == childId) {
          k = c;
          break;
        }
      }
    }
    if (k == null || !childInAnyClass(classes, k)) return null;
    return k;
  }

  Future<void> load({bool force = false}) async {
    if (!canView) {
      childState.value = const SectionState.forbidden();
      profileState.value = const SectionState.forbidden();
      observationsState.value = const SectionState.forbidden();
      portfolioState.value = const SectionState.forbidden();
      return;
    }
    if (!force && child != null && profileState.value.status != SectionStatus.loading) return;
    final token = ++_token;
    if (child == null) childState.value = const SectionState.loading();
    EceChild? k;
    try {
      k = await _resolveChild();
    } catch (e) {
      if (token != _token) return;
      childState.value = SectionState<EceChild>.fromError(e, previous: childState.value);
      return;
    }
    if (token != _token) return;
    if (k == null) {
      childState.value = const SectionState<EceChild>.forbidden(detail: "This child isn't one of the children in your classes.");
      profileState.value = const SectionState.forbidden(detail: "This child isn't one of the children in your classes.");
      observationsState.value = const SectionState.forbidden(detail: "This child isn't one of the children in your classes.");
      portfolioState.value = const SectionState.forbidden(detail: "This child isn't one of the children in your classes.");
      return;
    }
    childState.value = SectionState.data(k);
    await Future.wait([_loadProgress(token), _loadObservations(token), _loadPortfolio(token)]);
  }

  Future<void> _loadProgress(int token) async {
    if (!profileState.value.hasData) profileState.value = const SectionState.loading();
    try {
      // the domain names and level names are nice-to-have: without them the page still shows the levels, under a neutral area name
      final results = await Future.wait<Object?>([
        repo.fetchProfile(childId),
        repo.fetchDomains().then<Object?>((v) => v, onError: (_) => null),
        repo.fetchProgressionLevels().then<Object?>((v) => v, onError: (_) => null),
      ]);
      if (token != _token) return;
      final d = results[1];
      final l = results[2];
      if (d is List<EceDomain>) domains.assignAll(d);
      if (l is List<String>) levels.assignAll(l);
      final profile = results[0] as EceProfile;
      profileState.value = profile.isEmpty ? const SectionState.empty() : SectionState.data(profile);
    } catch (e) {
      if (token != _token) return;
      profileState.value = SectionState<EceProfile>.fromError(e, previous: profileState.value);
    }
  }

  Future<void> _loadObservations(int token) async {
    if (!observationsState.value.hasData) observationsState.value = const SectionState.loading();
    try {
      final list = await repo.fetchObservations(childId);
      if (token != _token) return;
      observationsState.value = list.isEmpty ? const SectionState.empty() : SectionState.data(list);
      if (list.any((o) => o.skills.isNotEmpty) && skillNames.isEmpty) _loadSkillNames(token);
    } catch (e) {
      if (token != _token) return;
      observationsState.value = SectionState<List<EceObservation>>.fromError(e, previous: observationsState.value);
    }
  }

  Future<void> _loadSkillNames(int token) async {
    try {
      final skills = await repo.fetchSkills();
      if (token != _token) return;
      skillNames.assignAll({for (final s in skills) s.id: s.name});
    } catch (_) {
      // names are optional: an observation without them still shows its level
    }
  }

  Future<void> _loadPortfolio(int token) async {
    if (!portfolioState.value.hasData) portfolioState.value = const SectionState.loading();
    try {
      final list = await repo.fetchPortfolio(childId);
      if (token != _token) return;
      portfolioState.value = list.isEmpty ? const SectionState.empty() : SectionState.data(list);
    } catch (e) {
      if (token != _token) return;
      portfolioState.value = SectionState<List<EcePortfolioEntry>>.fromError(e, previous: portfolioState.value);
    }
  }

  /// A viewable link for a stored photo. Signed links are reused for [photoLinkTtl], requests for the same key share one call, and a failure
  /// returns null (the screen shows "Photo unavailable") without being remembered, so the next look tries again.
  Future<String?> photoUrl(EceEvidence e) {
    final key = e.key;
    if (key == null) return Future.value(null);
    final hit = _photoLinks[key];
    if (hit != null && _now().difference(hit.at) < photoLinkTtl) return Future.value(hit.url);
    return _photoInFlight[key] ??= () async {
      try {
        final url = await repo.signedUrl(key);
        _photoLinks[key] = (url: url, at: _now());
        return url;
      } catch (_) {
        return null;
      } finally {
        _photoInFlight.remove(key);
      }
    }();
  }

  /// A new signed link for [e], ignoring the remembered one (used when the viewer's link expired).
  Future<String?> freshPhotoUrl(EceEvidence e) {
    final key = e.key;
    if (key != null) _photoLinks.remove(key);
    return photoUrl(e);
  }

  /// Links for the photos of one record, fetched when its sheet opens (signed links are never stored on disk, see [photoUrl]).
  Future<EcePhotoLinks> photoLinks(List<EceEvidence> evidence) async {
    final photos = evidence.where((e) => e.isPhoto).toList();
    final urls = await Future.wait([for (final p in photos) photoUrl(p)]);
    final items = <DetailAttachment>[];
    for (var i = 0; i < photos.length; i++) {
      final u = urls[i];
      if (u != null) items.add(DetailAttachment(photos[i].caption.isEmpty ? 'Photo ${i + 1}' : photos[i].caption, u, isImage: true, refreshUrl: () => freshPhotoUrl(photos[i])));
    }
    return EcePhotoLinks(items, photos.length - items.length);
  }

  /// A fresh entry or observation the user just created (so the page shows it without a refetch).
  void addObservation(EceObservation o) {
    final list = [o, ...(observationsState.value.data ?? const <EceObservation>[]).where((x) => x.id != o.id)];
    observationsState.value = SectionState.data(list);
  }

  void addPortfolioEntry(EcePortfolioEntry e) {
    final list = [e, ...(portfolioState.value.data ?? const <EcePortfolioEntry>[]).where((x) => x.id != e.id)];
    portfolioState.value = SectionState.data(list);
  }
}
