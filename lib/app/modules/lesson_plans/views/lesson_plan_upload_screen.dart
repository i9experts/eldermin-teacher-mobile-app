import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../routes/app_routes.dart';
import '../../homework/views/widgets/homework_widgets.dart' show FormLabel;
import '../controllers/lesson_plan_form_controller.dart';
import '../controllers/lesson_plan_upload_controller.dart';
import 'widgets/lesson_plan_widgets.dart';
import '../../../../core/design/design.dart';

/// Upload & parse (`/lesson-plans/upload`): a Word / Excel / text file or a Google Doc link is read by the server into a DRAFT that fills
/// the create form for review. Nothing is saved or submitted here.
class LessonPlanUploadScreen extends GetView<LessonPlanUploadController> {
  const LessonPlanUploadScreen({super.key});

  LessonPlanUploadController get c => controller;

  @override
  Widget build(BuildContext context) {
    return EmScaffold(
      appBar: EmAppBar(title: 'Upload & parse'),
      body: Obx(() {
        final reading = c.phase.value == UploadPhase.reading;
        final file = c.picked.value;
        final notice = c.pickNotice.value;
        final fail = c.failure.value;
        final prog = c.progress.value;
        final hasLink = c.link.value.trim().isNotEmpty;
        final quiet = EmType.caption.copyWith(color: EmColors.textSecondary);
        return ListView(padding: EmSpacing.listPadding, children: [
          const NoteBox(
            icon: Icons.auto_awesome_outlined,
            title: 'AI-assisted draft',
            body: 'Choose your own lesson plan document. The server reads it and fills the form below for you to review. Nothing is saved or sent for approval until you do that yourself.',
            tone: EmTone.info,
          ),
          const FormLabel('Document'),
          if (file == null)
            EmSecondaryButton(key: const Key('lp_pick_file'), expand: true, icon: Icons.attach_file_rounded, label: 'Choose a file', onPressed: reading ? null : c.pickFile)
          else
            AppCard(
              key: const Key('lp_picked'),
              child: Row(children: [
                const ExcludeSemantics(child: Icon(Icons.description_outlined, color: EmColors.primary)),
                const SizedBox(width: EmSpacing.row),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(file.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w600)),
                    Text(sizeText(file.size), style: quiet),
                  ]),
                ),
                IconButton(key: const Key('lp_clear_file'), tooltip: 'Remove file', onPressed: reading ? null : c.clearFile, icon: const Icon(Icons.close_rounded, size: 20, color: EmColors.textSecondary)),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.only(top: EmSpacing.s8, bottom: EmSpacing.s4),
            child: Text('Word (.docx), Excel (.xlsx, .xls), .csv or .txt, up to 10 MB. PDFs and old .doc files are not supported: save as .docx first.', style: quiet),
          ),
          if (notice != null)
            Padding(
              padding: const EdgeInsets.only(bottom: EmSpacing.s8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const ExcludeSemantics(child: Icon(Icons.error_outline_rounded, size: 16, color: EmColors.error)),
                const SizedBox(width: EmSpacing.s4),
                Expanded(child: Text(notice, key: const Key('lp_pick_notice'), style: quiet.copyWith(color: EmColors.error, fontWeight: FontWeight.w600))),
              ]),
            ),
          const SizedBox(height: EmSpacing.s8),
          const FormLabel('Or paste a Google Doc link'),
          TextField(
            key: const Key('lp_link_field'),
            enabled: !reading && file == null,
            onChanged: c.setLink,
            keyboardType: TextInputType.url,
            style: EmType.body.copyWith(color: EmColors.ink),
            decoration: const InputDecoration(isDense: true, hintText: 'https://docs.google.com/document/d/...'),
          ),
          Padding(padding: const EdgeInsets.only(top: EmSpacing.s8), child: Text('Sharing must be "Anyone with the link can view".', style: quiet)),
          const SizedBox(height: EmSpacing.block),
          if (fail != null)
            NoteBox(
              boxKey: const Key('lp_parse_failure'),
              icon: Icons.error_outline_rounded,
              title: fail.manual ? "We couldn't read this document" : "This didn't work",
              body: fail.message,
              tone: EmTone.error,
            ),
          if (reading)
            Padding(
              padding: const EdgeInsets.only(bottom: EmSpacing.row),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(
                  borderRadius: EmRadius.pillAll,
                  child: LinearProgressIndicator(key: const Key('lp_parse_progress'), value: prog > 0 && prog < 1 ? prog : null, minHeight: EmSpacing.s8, color: EmColors.primary, backgroundColor: EmColors.primaryLight),
                ),
                const SizedBox(height: EmSpacing.s8),
                Text(prog >= 1 || prog == 0 ? 'Reading your document... this can take up to a minute.' : 'Uploading ${(prog * 100).round()}%', style: quiet),
              ]),
            ),
          EmPrimaryButton(
            key: const Key('lp_parse'),
            icon: Icons.auto_awesome_rounded,
            loading: reading,
            label: reading ? 'Reading...' : (fail != null && !fail.manual ? 'Try again' : 'Read document'),
            onPressed: c.canParse ? () => _parse(context) : null,
          ),
          const SizedBox(height: EmSpacing.s8),
          Center(
            child: TextButton(
              key: const Key('lp_fill_manually'),
              onPressed: reading ? null : () => Get.offNamed(Routes.lessonPlanNew),
              child: Text(hasLink || file != null || fail != null ? 'Skip and fill it in myself' : 'Fill it in myself instead', textAlign: TextAlign.center, style: EmType.label.copyWith(color: EmColors.primary)),
            ),
          ),
        ]);
      }),
    );
  }

  Future<void> _parse(BuildContext context) async {
    final d = await c.parse();
    if (d == null) return;
    // Hand the draft to the create form (replaces this screen, so Back returns to the list). The form is NOT submitted.
    await Get.offNamed(Routes.lessonPlanNew, arguments: LessonPlanFormArgs(draft: d));
  }
}
