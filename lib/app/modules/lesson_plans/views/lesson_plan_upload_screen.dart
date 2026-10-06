import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../components/custom_text.dart';
import '../../../routes/app_routes.dart';
import '../../homework/views/widgets/homework_widgets.dart' show FormLabel;
import '../controllers/lesson_plan_form_controller.dart';
import '../controllers/lesson_plan_upload_controller.dart';
import 'widgets/lesson_plan_widgets.dart';

/// Upload & parse (`/lesson-plans/upload`): a Word / Excel / text file or a Google Doc link is read by the server into a DRAFT that fills
/// the create form for review. Nothing is saved or submitted here.
class LessonPlanUploadScreen extends GetView<LessonPlanUploadController> {
  const LessonPlanUploadScreen({super.key});

  LessonPlanUploadController get c => controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const CustomText(text: 'Upload & parse', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
      body: Obx(() {
        final reading = c.phase.value == UploadPhase.reading;
        final file = c.picked.value;
        final notice = c.pickNotice.value;
        final fail = c.failure.value;
        final prog = c.progress.value;
        final hasLink = c.link.value.trim().isNotEmpty;
        return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
          const NoteBox(
            icon: Icons.auto_awesome_outlined,
            title: 'AI-assisted draft',
            body: 'Choose your own lesson plan document. The server reads it and fills the form below for you to review. Nothing is saved or sent for approval until you do that yourself.',
            fg: AppColors.blue,
            bg: AppColors.pale,
          ),
          const FormLabel('Document'),
          if (file == null)
            OutlinedButton.icon(
              key: const Key('lp_pick_file'),
              onPressed: reading ? null : c.pickFile,
              icon: const Icon(Icons.attach_file_rounded, size: 18),
              label: const CustomText(text: 'Choose a file', color: AppColors.primaryColor, fontWeight: FontWeight.w700),
            )
          else
            AppCard(
              key: const Key('lp_picked'),
              child: Row(children: [
                const Icon(Icons.description_outlined, color: AppColors.primaryColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    CustomText(text: file.name, fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.primaryColor, maxLines: 1, overflow: TextOverflow.ellipsis),
                    CustomText(text: sizeText(file.size), color: AppColors.muted, fontSize: 11),
                  ]),
                ),
                IconButton(key: const Key('lp_clear_file'), onPressed: reading ? null : c.clearFile, icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.muted)),
              ]),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 6, bottom: 4),
            child: CustomText(text: 'Word (.docx), Excel (.xlsx, .xls), .csv or .txt, up to 10 MB. PDFs and old .doc files are not supported: save as .docx first.', color: AppColors.muted, fontSize: 11),
          ),
          if (notice != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: CustomText(key: const Key('lp_pick_notice'), text: notice, color: AppColors.redText, fontSize: 11.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const FormLabel('Or paste a Google Doc link'),
          TextField(
            key: const Key('lp_link_field'),
            enabled: !reading && file == null,
            onChanged: c.setLink,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'https://docs.google.com/document/d/...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.line)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const Padding(padding: EdgeInsets.only(top: 6), child: CustomText(text: 'Sharing must be "Anyone with the link can view".', color: AppColors.muted, fontSize: 11)),
          const SizedBox(height: 16),
          if (fail != null) ...[
            NoteBox(
              boxKey: const Key('lp_parse_failure'),
              icon: Icons.error_outline_rounded,
              title: fail.manual ? "We couldn't read this document" : "This didn't work",
              body: fail.message,
              fg: AppColors.redText,
              bg: AppColors.redBg,
            ),
          ],
          if (reading)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(key: const Key('lp_parse_progress'), value: prog > 0 && prog < 1 ? prog : null, minHeight: 5, color: AppColors.primaryColor, backgroundColor: AppColors.pale)),
                const SizedBox(height: 6),
                CustomText(text: prog >= 1 || prog == 0 ? 'Reading your document... this can take up to a minute.' : 'Uploading ${(prog * 100).round()}%', color: AppColors.muted, fontSize: 11.5),
              ]),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('lp_parse'),
              onPressed: c.canParse ? () => _parse(context) : null,
              icon: reading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.auto_awesome_rounded, size: 18),
              label: CustomText(text: reading ? 'Reading...' : (fail != null && !fail.manual ? 'Try again' : 'Read document'), color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              key: const Key('lp_fill_manually'),
              onPressed: reading ? null : () => Get.offNamed(Routes.lessonPlanNew),
              child: CustomText(text: hasLink || file != null || fail != null ? 'Skip and fill it in myself' : 'Fill it in myself instead', color: AppColors.primaryColor, fontWeight: FontWeight.w700),
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
