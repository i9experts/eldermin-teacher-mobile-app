import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../../core/models/early_years/ece_models.dart';
import '../../../../core/services/attachment_picker.dart';
import 'evidence_photos.dart';
import 'ey_form_base.dart';
import 'ey_submit.dart';

/// New portfolio entry (`/early-years/child/:id/portfolio/new`): title, what happened, an optional "try this at home", photos. PRIVATE by
/// default. `POST /ece/portfolio`; with the share switch on, the backend emails the child's guardian.
class PortfolioFormController extends EyFormBase {
  final AttachmentPicker? _picker;
  PortfolioFormController({required super.childId, super.initial, super.repository, super.auth, super.permissions, AttachmentPicker? picker}) : _picker = picker;

  late final EvidencePhotos photos = EvidencePhotos(repo: repo, picker: _picker);

  final titleC = TextEditingController();
  final narrativeC = TextEditingController();
  final tryHomeC = TextEditingController();
  final share = false.obs;

  @override
  void onClose() {
    titleC.dispose();
    narrativeC.dispose();
    tryHomeC.dispose();
    super.onClose();
  }

  void setShare(bool v) => share.value = v;

  bool get needsShareConfirm => share.value;

  static const shareConfirmTitle = 'Share with the family?';
  static const shareConfirmMessage = "The child's guardian will be emailed about this entry, and parents will be able to see it in their app.";

  Map<String, String> validate() {
    final e = <String, String>{};
    if (titleC.text.trim().isEmpty) e['title'] = 'Enter a title';
    if (narrativeC.text.trim().isEmpty) e['narrative'] = 'Describe what happened';
    if (photos.busy) e['photos'] = 'Wait for the photos to finish uploading';
    if (photos.hasFailed) e['photos'] = 'Retry or remove the photo that failed';
    if (child == null) e['child'] = "This child isn't one of your classes' children";
    return e;
  }

  EcePortfolioDraft? get draft {
    if (child == null) return null;
    return EcePortfolioDraft(
      studentId: childId,
      title: titleC.text,
      narrative: narrativeC.text,
      tryThisAtHome: tryHomeC.text,
      evidence: photos.evidence,
      shareWithFamily: share.value,
    );
  }

  bool get isDirty => titleC.text.trim().isNotEmpty || narrativeC.text.trim().isNotEmpty || tryHomeC.text.trim().isNotEmpty || photos.hasAny || share.value;

  Future<EySubmit<EcePortfolioEntry>> submit() async {
    if (saving.value) return const EyIgnored();
    if (blocked != null) return EyInvalid({'child': blocked!});
    final problems = validate();
    errors.assignAll(problems);
    final d = draft;
    if (problems.isNotEmpty || d == null) return EyInvalid(problems);
    saving.value = true;
    failure.value = null;
    try {
      final saved = await repo.createPortfolioEntry(d);
      childPage?.addPortfolioEntry(saved);
      return EySaved(saved);
    } catch (e) {
      final f = eyFailure(e, what: 'save this entry');
      failure.value = f;
      return EyFailed(f);
    } finally {
      saving.value = false;
    }
  }
}
