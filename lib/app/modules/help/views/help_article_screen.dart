import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/help/kb_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/custom_text.dart';
import '../../../components/rich_text_view.dart';
import '../controllers/help_controller.dart';

/// One help article (`/help/:module/:tabKey`): tagline, body (inert rich text), numbered "How to use it" steps.
class HelpArticleScreen extends GetView<HelpArticleController> {
  const HelpArticleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Help')),
      body: Obx(() => ScreenStateView<KbArticle>(
            state: c.state.value,
            onRefresh: () => c.load(userInitiated: true),
            onRetry: () => c.load(userInitiated: true),
            builder: (a) => [
              AppTag(kbModuleLabel(a.module).toUpperCase(), style: TagStyle.neutral),
              const SizedBox(height: 8),
              CustomText(key: const Key('help_article_title'), text: a.title, fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primaryColor),
              if (a.tagline.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: CustomText(text: a.tagline, fontSize: 13, color: AppColors.muted, height: 1.4, fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              if (a.body.isNotEmpty) RichTextView(a.body),
              if (a.steps.isNotEmpty) ...[
                const SubHeading('How to use it'),
                RichTextView(key: const Key('help_steps'), [for (var i = 0; i < a.steps.length; i++) '${i + 1}. ${a.steps[i].replaceAll('\n', ' ')}'].join('\n')),
              ],
            ],
          )),
    );
  }
}
