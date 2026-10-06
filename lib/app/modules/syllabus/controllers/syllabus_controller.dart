import 'package:get/get.dart';
import '../../../../core/models/academic/syllabus_models.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/services/syllabus_repository.dart';
import '../../../../core/utils/class_match.dart';
import '../../../../core/utils/roster_scope.dart';
import '../../../common/action_failure.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/models/section_state.dart';

enum SyllabusFilter {
  all('All'),
  behind('Behind schedule'),
  completed('Completed');

  final String label;
  const SyllabusFilter(this.label);
}

/// Outcome of marking coverage.
sealed class MarkResult {
  const MarkResult();
}

class MarkOk extends MarkResult {
  const MarkOk();
}

class MarkFailed extends MarkResult {
  final ActionFailure failure;
  const MarkFailed(this.failure);
}

class MarkIgnored extends MarkResult {
  const MarkIgnored();
}

class _Pending {
  final int unitNo;
  final int topicNo;
  final int? subNo;
  final bool covered;
  const _Pending(this.unitNo, this.topicNo, this.subNo, this.covered);
}

/// "My syllabi" (`/syllabus`, `/syllabus/:id`) and coverage marking.
///
/// Which syllabi are mine: `GET /syllabus` has NO owner scoping (campus only, syllabus.service.ts:95-110), so the list asks for
///  (a) `teacherId=<my Staff id>` (+ my TeacherProfile id: UNVERIFIED which one real data holds) and
///  (b) per distinct grade of MY assignments `gradeLevel=<grade>`, then keeps a syllabus only when it is assigned to me OR it is for one of
///      my classes AND subjects (grade/section matched with the app port of the backend's tolerant matcher; a syllabus without a section
///      applies to the whole grade). Everything else (colleagues' subjects) is dropped client-side. Archived syllabi are not listed.
///
/// Marking is OPTIMISTIC: the tick flips at once, `PATCH mark-sub-topic` / `mark-topic` follows, the server's saved syllabus (re-rolled totals)
/// replaces ours, a failure rolls back ONLY that item. An item with a request in flight ignores further taps. A topic that has sub-topics is
/// never marked directly (the server would set it without the rollup noticing, syllabus.service.ts:533): its state derives from its sub-topics.
class SyllabusController extends GetxController {
  final SyllabusRepository? _repo;
  final AuthController? _auth;
  final PermissionService? _perms;

  SyllabusController({SyllabusRepository? repository, AuthController? auth, PermissionService? permissions})
      : _repo = repository,
        _auth = auth,
        _perms = permissions;

  SyllabusRepository get repo => _repo ?? Get.find<SyllabusRepository>();
  AuthController get auth => _auth ?? Get.find<AuthController>();
  PermissionService get perms => _perms ?? Get.find<PermissionService>();

  final state = Rx<SectionState<List<Syllabus>>>(const SectionState.loading());
  final filter = SyllabusFilter.all.obs;

  /// Items with a request in flight (`s:<syllabus>:<unit>:<topic>:<sub|->`).
  final pending = <String>{}.obs;
  final _inflight = <String, _Pending>{};
  int _token = 0;

  List<String> get myIds {
    final out = <String>[];
    final s = auth.staffId;
    final p = auth.teacherProfileId;
    if (s != null && s.isNotEmpty) out.add(s);
    if (p != null && p.isNotEmpty && p != s) out.add(p);
    return out;
  }

  bool get canView {
    auth.staffMe.value;
    return perms.canAccess('teaching:view');
  }

  String get myName => auth.staffMe.value?.user.name ?? '';

  List<ClassRef> get _myClasses => teacherClassesOf(auth.staffMe.value?.teacherProfile);

  List<Syllabus> get items => state.value.data ?? const [];

  List<Syllabus> get filtered => switch (filter.value) {
        SyllabusFilter.all => items,
        SyllabusFilter.behind => items.where((s) => s.isBehind).toList(),
        SyllabusFilter.completed => items.where((s) => s.trackStatus == 'completed' || s.progress.isComplete).toList(),
      };

  int countFor(SyllabusFilter f) => switch (f) {
        SyllabusFilter.all => items.length,
        SyllabusFilter.behind => items.where((s) => s.isBehind).length,
        SyllabusFilter.completed => items.where((s) => s.trackStatus == 'completed' || s.progress.isComplete).length,
      };

  /// Assigned to me by id (`teacherId`).
  bool assignedToMe(Syllabus s) => s.teacherId.isNotEmpty && myIds.contains(s.teacherId);

  /// For one of my classes AND subjects.
  bool forMyClass(Syllabus s) {
    for (final c in _myClasses) {
      if (!sameGrade(s.gradeLevel, c.grade)) continue;
      if (s.sectionName.isNotEmpty && c.section.isNotEmpty && !sameSection(s.sectionName, c.section)) continue;
      if (c.subjects.any((x) => x.trim().toLowerCase() == s.subjectName.trim().toLowerCase())) return true;
    }
    return false;
  }

  bool inScope(Syllabus s) => s.status != 'archived' && (assignedToMe(s) || forMyClass(s));

  @override
  void onReady() {
    super.onReady();
    load();
  }

  void setFilter(SyllabusFilter f) => filter.value = f;

  Future<void> load({bool force = false}) async {
    if (!canView) {
      state.value = const SectionState.forbidden();
      return;
    }
    if (myIds.isEmpty) {
      state.value = const SectionState.error("Your teacher profile isn't loaded yet. Pull down to refresh.");
      return;
    }
    if (!force && state.value.hasData) return;
    final token = ++_token;
    if (!state.value.hasData) state.value = const SectionState.loading();
    try {
      final byId = <String, Syllabus>{};
      for (final id in myIds) {
        for (final s in await repo.list({'teacherId': id})) {
          byId[s.id] = s;
        }
      }
      // Class-based extras are best effort: a failure here must not hide the syllabi assigned to me.
      final grades = {for (final c in _myClasses) if (c.subjects.isNotEmpty) c.grade};
      for (final g in grades) {
        try {
          for (final s in await repo.list({'gradeLevel': g})) {
            byId.putIfAbsent(s.id, () => s);
          }
        } catch (_) {}
      }
      if (token != _token) return;
      final mine = byId.values.where(inScope).toList()
        ..sort((a, b) {
          final g = a.gradeLevel.compareTo(b.gradeLevel);
          return g != 0 ? g : a.subjectName.compareTo(b.subjectName);
        });
      state.value = mine.isEmpty ? const SectionState.empty() : SectionState.data(mine);
    } catch (e) {
      if (token != _token) return;
      state.value = SectionState<List<Syllabus>>.fromError(e);
    }
  }

  Future<void> reload() async {
    await auth.refreshProfile(force: true);
    await load(force: true);
  }

  Future<void> ensureLoaded() async {
    if (state.value.hasData || state.value.status == SectionStatus.empty) return;
    await load(force: state.value.status == SectionStatus.error);
  }

  Syllabus? byId(String id) {
    for (final s in items) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Replaces (or adds) a syllabus, keeping the sort order.
  void upsert(Syllabus s) {
    final list = [...items];
    final i = list.indexWhere((x) => x.id == s.id);
    if (i >= 0) {
      list[i] = s;
    } else {
      list.add(s);
    }
    state.value = SectionState.data(list);
  }

  // ── marking ──────────────────────────────────────────────────

  static String _key(String sid, int u, int t, int? s) => 's:$sid:$u:$t:${s ?? '-'}';

  bool isPending(String sid, int unitNo, int topicNo, [int? subNo]) => pending.contains(_key(sid, unitNo, topicNo, subNo));

  /// The server's saved syllabus, with the OTHER in-flight optimistic marks of the same syllabus re-applied on top.
  Syllabus _reapply(Syllabus server, String sid, String except) {
    var s = server;
    _inflight.forEach((k, p) {
      if (k == except || !k.startsWith('s:$sid:')) return;
      s = p.subNo == null ? s.withTopicCovered(p.unitNo, p.topicNo, p.covered) : s.withSubTopicCovered(p.unitNo, p.topicNo, p.subNo!, p.covered);
    });
    return s;
  }

  Future<MarkResult> markSubTopic(String sid, int unitNo, int topicNo, int subNo, bool covered) =>
      _mark(sid, unitNo, topicNo, subNo, covered);

  /// Only for a topic WITHOUT sub-topics.
  Future<MarkResult> markTopic(String sid, int unitNo, int topicNo, bool covered) => _mark(sid, unitNo, topicNo, null, covered);

  Future<MarkResult> _mark(String sid, int unitNo, int topicNo, int? subNo, bool covered) async {
    final key = _key(sid, unitNo, topicNo, subNo);
    final before = byId(sid);
    if (before == null || pending.contains(key)) return const MarkIgnored();
    final topic = before.topicAt(unitNo, topicNo);
    if (topic == null) return const MarkIgnored();
    if (subNo == null && topic.hasSubTopics) return const MarkIgnored(); // derived from its sub-topics, never marked directly
    final already = subNo == null ? topic.isCovered : (topic.subTopics.where((s) => s.no == subNo).firstOrNull?.isCovered ?? covered);
    if (already == covered) return const MarkIgnored();
    _inflight[key] = _Pending(unitNo, topicNo, subNo, covered);
    pending.add(key);
    upsert(subNo == null ? before.withTopicCovered(unitNo, topicNo, covered) : before.withSubTopicCovered(unitNo, topicNo, subNo, covered)); // optimistic
    try {
      final saved = subNo == null
          ? await repo.markTopic(sid, unitNo: unitNo, topicNo: topicNo, covered: covered, coveredBy: myName)
          : await repo.markSubTopic(sid, unitNo: unitNo, topicNo: topicNo, subTopicNo: subNo, covered: covered, coveredBy: myName);
      _inflight.remove(key);
      upsert(_reapply(saved, sid, key));
      return const MarkOk();
    } catch (e) {
      _inflight.remove(key);
      final now = byId(sid);
      if (now != null) {
        // Roll back ONLY this item (other marks of the syllabus keep their own state).
        upsert(subNo == null ? now.withTopicCovered(unitNo, topicNo, !covered) : now.withSubTopicCovered(unitNo, topicNo, subNo, !covered));
      }
      return MarkFailed(ActionFailure.from(e, what: 'update this syllabus', keep: 'The tick was put back.'));
    } finally {
      pending.remove(key);
    }
  }
}
