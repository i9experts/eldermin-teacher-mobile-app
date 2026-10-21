import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/constants/support_config.dart';
import '../../../../core/models/help/kb_models.dart';
import '../../../../core/models/help/teacher_faqs.dart';
import '../../../../core/widgets/app_widgets.dart' show AppCard, ListCardRow;
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/external_link.dart';
import '../../../routes/app_routes.dart';
import '../controllers/help_controller.dart';
import '../../../../core/design/design.dart';

/// Help (`/help`): bundled teacher FAQs at the top (static, always shown while not searching), then teacher-appropriate knowledge-base articles by module (HR / admin guides are hidden, see [isTeacherHelpArticle]), search, and a
/// Contact support card when the build configures one.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});
  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _text = TextEditingController();
  HelpController get c => Get.find<HelpController>();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Widget _search() => Padding(
        padding: const EdgeInsets.only(bottom: EmSpacing.s12),
        child: EmSearchPill(
          fieldKey: const Key('help_search'),
          controller: _text,
          hint: 'Search help',
          onSubmitted: c.search,
          trailing: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _text,
            builder: (_, v, __) => v.text.isEmpty
                ? const SizedBox.shrink()
                : EmIconCircleButton(key: const Key('help_search_clear'), icon: Icons.close_rounded, semanticLabel: 'Clear search', tooltip: 'Clear search', onTap: () {
                    _text.clear();
                    c.clearSearch();
                  }),
          ),
        ),
      );

  /// "Contact support": only when the app was built with a support address / page (SupportConfig); never invented.
  Widget _support() {
    final email = SupportConfig.email, url = SupportConfig.url;
    if (email == null && url == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: EmSpacing.s12),
      child: Column(key: const Key('help_support'), crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SubHeading('Contact support'),
          if (email != null) ListCardRow(key: const Key('help_support_email'), icon: Icons.mail_outline_rounded, title: 'Email support', subtitle: email, trailing: const Icon(Icons.chevron_right_rounded, color: EmColors.textTertiary), onTap: () => ExternalLinks.openMail(email)),
          if (url != null) ListCardRow(key: const Key('help_support_web'), icon: Icons.language_rounded, title: 'Support website', subtitle: url.host, trailing: const Icon(Icons.chevron_right_rounded, color: EmColors.textTertiary), onTap: () => ExternalLinks.openWithConfirm(url.toString())),
        ]),
    );
  }

  /// The bundled FAQs ([kTeacherFaqs]): static, offline, one expandable row per question.
  Widget _faqs() => Padding(
        padding: const EdgeInsets.only(bottom: EmSpacing.s12),
        child: Column(key: const Key('help_faqs'), crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SubHeading('Frequently asked questions'),
          for (final f in kTeacherFaqs)
            AppCard(
              margin: const EdgeInsets.only(bottom: EmSpacing.s8),
              padding: EdgeInsets.zero,
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: ValueKey('faq_${f.id}'),
                  tilePadding: const EdgeInsets.symmetric(horizontal: EmSpacing.s16),
                  childrenPadding: const EdgeInsets.fromLTRB(EmSpacing.s16, 0, EmSpacing.s16, EmSpacing.s16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  title: Text(f.question, style: EmType.label.copyWith(fontWeight: FontWeight.w700, color: EmColors.ink)),
                  children: [Text(f.answer, style: EmType.label.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400, height: 1.45))],
                ),
              ),
            ),
        ]),
      );

  Widget _row(KbArticle a) => ListCardRow(
        key: ValueKey('help_${a.key}'),
        icon: Icons.article_outlined,
        title: a.title,
        subtitle: a.tagline.isEmpty ? kbModuleLabel(a.module) : a.tagline,
        trailing: const Icon(Icons.chevron_right_rounded, color: EmColors.textTertiary),
        onTap: () => Get.toNamed(Routes.helpArticle.replaceFirst(':module', Uri.encodeComponent(a.module)).replaceFirst(':tabKey', Uri.encodeComponent(a.tabKey)), arguments: a),
      );

  @override
  Widget build(BuildContext context) {
    return EmScaffold(
      appBar: EmAppBar(title: 'Help'),
      body: Obx(() {
        final res = c.results.value;
        if (res != null) {
          return ScreenStateView<List<KbArticle>>(
            state: res,
            header: [_search(), _support()],
            onRefresh: () => c.search(c.query.value),
            onRetry: () => c.search(c.query.value),
            emptyIcon: Icons.search_off_rounded,
            emptyTitle: 'No articles match',
            emptySubtitle: 'Try different words.',
            builder: (rows) => [for (final a in rows) _row(a)],
          );
        }
        return ScreenStateView<List<KbArticle>>(
          state: c.list.value,
          header: [_search(), _faqs(), _support()],
          onRefresh: () => c.load(userInitiated: true),
          onRetry: () => c.load(userInitiated: true),
          emptyIcon: Icons.menu_book_outlined,
          emptyTitle: 'No further guides yet',
          emptySubtitle: 'More guides appear here when your school publishes them.',
          builder: (_) => [
            for (final g in c.grouped.entries) ...[SubHeading(kbModuleLabel(g.key)), for (final a in g.value) _row(a)],
            const SizedBox(height: EmSpacing.s8),
            AppCard(key: const Key('help_contact'), child: Text("Can't find what you need? Ask your school administration, or your safeguarding lead for anything about a child's safety.", style: EmType.label.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400, height: 1.4))),
          ],
        );
      }),
    );
  }
}
