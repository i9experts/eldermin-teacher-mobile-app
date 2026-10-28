import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../../core/models/early_years/ece_models.dart';
import '../../../../core/services/attachment_picker.dart';
import '../../home/models/section_state.dart';
import 'evidence_photos.dart';
import 'ey_form_base.dart';
import 'ey_submit.dart';
import 'quick_observe_controller.dart' show EyRefs;

/// Full observation (`/early-years/child/:id/observe`): narrative, type, next step, an optional skill and level, photos, and a share switch
/// (default OFF). `POST /ece/observations`. `isSharedWithFamily` is stored at creation and there is no way to change it afterwards.
class ObservationFormController extends EyFormBase {
  final AttachmentPicker? _picker;
  ObservationFormController({required super.childId, super.initial, super.repository, super.auth, super.permissions, AttachmentPicker? picker}) : _picker = picker;

  late final EvidencePhotos photos = EvidencePhotos(repo: repo, picker: _picker);

  final narrativeC = TextEditingController();
  final nextStepC = TextEditingController();
  final type = 'spontaneous'.obs;
  final share = false.obs;

  final refs = Rx<SectionState<EyRefs>>(const SectionState.loading());
  final domainId = RxnString();
  final skillId = RxnString();
  final level = RxnString();

  @override
  void onReady() {
    super.onReady();
    loadRefs();
  }

  @override
  void onClose() {
    narrativeC.dispose();
    nextStepC.dispose();
    super.onClose();
  }

  /// The skill list is optional here: a failure to load it leaves the form usable without a skill.
  Future<void> loadRefs() async {
    if (blocked != null) return;
    refs.value = const SectionState.loading();
    try {
      final r = await Future.wait<Object>([repo.fetchDomains(), repo.fetchSkills(), repo.fetchProgressionLevels()]);
      final skills = r[1] as List<EceSkill>;
      refs.value = skills.isEmpty ? const SectionState.empty() : SectionState.data(EyRefs(domains: r[0] as List<EceDomain>, skills: skills, levels: r[2] as List<String>));
    } catch (e) {
      refs.value = SectionState<EyRefs>.fromError(e);
    }
  }

  void setType(String t) => type.value = t;
  void setShare(bool v) => share.value = v;

  void setDomain(String id) {
    if (domainId.value == id) return;
    domainId.value = id;
    skillId.value = null;
    errors.remove('skill');
  }

  void setSkill(String id) {
    skillId.value = id;
    errors.remove('skill');
  }

  void setLevel(String l) {
    level.value = l;
    errors.remove('skill');
  }

  void clearSkill() {
    domainId.value = null;
    skillId.value = null;
    level.value = null;
    errors.remove('skill');
  }

  /// True when saving will share this with the family and the teacher must confirm first.
  bool get needsShareConfirm => share.value;

  static const shareConfirmTitle = 'Share with the family?';
  static const shareConfirmMessage = "Parents will be able to see this observation in their app. It can't be changed or taken back from this app afterwards.";

  Map<String, String> validate() {
    final e = <String, String>{};
    if (narrativeC.text.trim().isEmpty) e['narrative'] = 'Describe what you observed';
    // a skill and a level go together
    if ((skillId.value == null) != (level.value == null)) e['skill'] = skillId.value == null ? 'Choose the skill, or clear the level' : 'Choose a level for this skill';
    if (photos.busy) e['photos'] = 'Wait for the photos to finish uploading';
    if (photos.hasFailed) e['photos'] = 'Retry or remove the photo that failed';
    if (child == null) e['child'] = "This child isn't one of your classes' children";
    return e;
  }

  EceObservationDraft? get draft {
    if (child == null) return null;
    return EceObservationDraft(
      studentId: childId,
      narrative: narrativeC.text,
      type: type.value,
      nextStep: nextStepC.text,
      skills: skillId.value != null && level.value != null ? [EceSkillMapping(skillId: skillId.value!, level: level.value!)] : const [],
      evidence: photos.evidence,
      shareWithFamily: share.value,
    );
  }

  bool get isDirty =>
      narrativeC.text.trim().isNotEmpty || nextStepC.text.trim().isNotEmpty || photos.hasAny || skillId.value != null || type.value != 'spontaneous' || share.value;

  Future<EySubmit<EceObservation>> submit() async {
    if (saving.value) return const EyIgnored();
    if (blocked != null) return EyInvalid({'child': blocked!});
    final problems = validate();
    errors.assignAll(problems);
    final d = draft;
    if (problems.isNotEmpty || d == null) return EyInvalid(problems);
    saving.value = true;
    failure.value = null;
    try {
      final saved = await repo.createObservation(d);
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
