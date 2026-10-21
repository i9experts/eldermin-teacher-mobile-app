import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/help/kb_models.dart';
import '../../../../core/theme/app_theme.dart' show TagStyle;
import '../../../../core/widgets/app_widgets.dart' show AppTag;
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/rich_text_view.dart';
import '../controllers/help_controller.dart';
import '../../../../core/design/design.dart';

/// One help article (`/help/:module/:tabKey`): tagline, body (inert rich text), numbered "How to use it" steps.
class HelpArticleScreen extends GetView<HelpArticleController> {
  const HelpArticleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return EmScaffold(
      appBar: EmAppBar(title: 'Help'),
      body: Obx(() => ScreenStateView<KbArticle>(
            state: c.state.value,
            onRefresh: () => c.load(userInitiated: true),
            onRetry: () => c.load(userInitiated: true),
            builder: (a) => [
              AppTag(kbModuleLabel(a.module).toUpperCase(), style: TagStyle.neutral),
              const SizedBox(height: EmSpacing.s8),
              Text(a.title, key: const Key('help_article_title'), style: EmType.title.copyWith(fontWeight: FontWeight.w800, color: EmColors.ink)),
              if (a.tagline.isNotEmpty) Padding(padding: const EdgeInsets.only(top: EmSpacing.s8), child: Text(a.tagline, style: EmType.label.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w600, height: 1.4))),
              const SizedBox(height: EmSpacing.block),
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
