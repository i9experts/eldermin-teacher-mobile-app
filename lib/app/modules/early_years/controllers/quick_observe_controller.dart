import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../../core/models/early_years/ece_models.dart';
import '../../home/models/section_state.dart';
import 'ey_form_base.dart';
import 'ey_submit.dart';

/// The pickers of the observation forms: learning areas, skills and level names.
class EyRefs {
  final List<EceDomain> domains;
  final List<EceSkill> skills;
  final List<String> levels;
  const EyRefs({required this.domains, required this.skills, required this.levels});
  List<EceSkill> skillsOf(String? domainId) => [for (final s in skills) if (domainId != null && s.domainId == domainId) s];
}

/// Quick observation (`/early-years/child/:id/quick`): pick a skill and a level, optionally a line of text. `POST /ece/observations/quick`.
class QuickObserveController extends EyFormBase {
  QuickObserveController({required super.childId, super.initial, super.repository, super.auth, super.permissions});

  final refs = Rx<SectionState<EyRefs>>(const SectionState.loading());
  final domainId = RxnString();
  final skillId = RxnString();
  final level = RxnString();
  final narrativeC = TextEditingController();

  @override
  void onReady() {
    super.onReady();
    loadRefs();
  }

  @override
  void onClose() {
    narrativeC.dispose();
    super.onClose();
  }

  Future<void> loadRefs() async {
    if (blocked != null) return;
    refs.value = const SectionState.loading();
    try {
      final r = await Future.wait<Object>([repo.fetchDomains(), repo.fetchSkills(), repo.fetchProgressionLevels()]);
      final domains = r[0] as List<EceDomain>;
      final skills = r[1] as List<EceSkill>;
      refs.value = skills.isEmpty ? const SectionState.empty() : SectionState.data(EyRefs(domains: domains, skills: skills, levels: r[2] as List<String>));
    } catch (e) {
      refs.value = SectionState<EyRefs>.fromError(e);
    }
  }

  void setDomain(String id) {
    if (domainId.value == id) return;
    domainId.value = id;
    skillId.value = null; // a skill belongs to one learning area
    errors.remove('skill');
  }

  void setSkill(String id) {
    skillId.value = id;
    errors.remove('skill');
  }

  void setLevel(String l) {
    level.value = l;
    errors.remove('level');
  }

  Map<String, String> validate() {
    final e = <String, String>{};
    if (skillId.value == null) e['skill'] = 'Choose a skill';
    if (level.value == null) e['level'] = 'Choose a level';
    if (child == null) e['child'] = "This child isn't one of your classes' children";
    return e;
  }

  bool get isDirty => skillId.value != null || level.value != null || narrativeC.text.trim().isNotEmpty;

  Future<EySubmit<EceObservation>> submit() async {
    if (saving.value) return const EyIgnored();
    if (blocked != null) return EyInvalid({'child': blocked!});
    final problems = validate();
    errors.assignAll(problems);
    if (problems.isNotEmpty) return EyInvalid(problems);
    saving.value = true;
    failure.value = null;
    try {
      final saved = await repo.createQuickObservation(
          EceQuickObservationDraft(studentId: childId, skillId: skillId.value!, level: level.value!, narrative: narrativeC.text));
      childPage?.addObservation(saved);
      return EySaved(saved);
    } catch (e) {
      final f = eyFailure(e, what: 'save this observation');
      failure.value = f;
      return EyFailed(f);
    } finally {
      saving.value = false;
    }
  }
}
