import 'package:get/get.dart';
import '../../../../core/models/classroom/student_models.dart';
import '../../../../core/services/students_repository.dart';
import '../../../../core/utils/roster_scope.dart';
import '../../home/models/section_state.dart';

/// Student picker state for "start a conversation": the teacher's OWN classes (class chips) and the roster of the chosen one
/// (`GET /students` per class, re-scoped client-side by [StudentsRepository.fetchClassRoster]); never the whole campus. Same behaviour as
/// the behaviour-log picker, kept separate so each module owns its screen state.
class ClassRosterPicker {
  final StudentsRepository Function() _students;
  final List<ClassRef> Function() _classes;
  ClassRosterPicker(this._students, this._classes);

  final selectedClass = 0.obs;
  final query = ''.obs;
  final rosters = <String, SectionState<List<StudentSummary>>>{}.obs;
  GradesSections? _known;
  bool _knownTried = false;
  final _tokens = <String, int>{};

  List<ClassRef> get classes => _classes();

  ClassRef? get current {
    final cs = classes;
    if (cs.isEmpty) return null;
    return cs[selectedClass.value.clamp(0, cs.length - 1)];
  }

  SectionState<List<StudentSummary>> get state {
    final c = current;
    if (c == null) return const SectionState.empty();
    return rosters[c.key] ?? const SectionState.loading();
  }

  /// The current roster narrowed by the search text (name, preferred name, exact roll number, GR no).
  List<StudentSummary> get visible {
    final all = state.data ?? const <StudentSummary>[];
    final q = query.value.trim().toLowerCase();
    if (q.isEmpty) return all;
    return [
      for (final s in all)
        if (s.fullName.toLowerCase().contains(q) || (s.preferredName ?? '').toLowerCase().contains(q) || (s.rollNumber ?? '') == q || (s.grNo ?? '').toLowerCase().contains(q)) s
    ];
  }

  void selectClass(int i) {
    if (i == selectedClass.value) return;
    selectedClass.value = i;
    query.value = '';
    load();
  }

  Future<void> load({bool force = false}) async {
    final c = current;
    if (c == null) return;
    final existing = rosters[c.key];
    if (!force && existing != null && (existing.hasData || existing.status == SectionStatus.empty)) return;
    final token = (_tokens[c.key] ?? 0) + 1;
    _tokens[c.key] = token;
    rosters[c.key] = const SectionState.loading();
    try {
      if (!_knownTried) {
        _knownTried = true;
        try {
          _known = await _students().fetchGradesSections();
        } catch (_) {
          _known = null;
        }
      }
      final list = await _students().fetchClassRoster(c, known: _known);
      if (_tokens[c.key] != token) return;
      rosters[c.key] = list.isEmpty ? const SectionState.empty() : SectionState.data(list);
    } catch (e) {
      if (_tokens[c.key] != token) return;
      rosters[c.key] = SectionState<List<StudentSummary>>.fromError(e);
    }
  }
}
