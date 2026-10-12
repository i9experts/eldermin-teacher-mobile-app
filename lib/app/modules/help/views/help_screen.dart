import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/constants/support_config.dart';
import '../../../../core/models/help/kb_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/custom_text.dart';
import '../../../components/external_link.dart';
import '../../../routes/app_routes.dart';
import '../controllers/help_controller.dart';

/// Help (`/help`): teacher-appropriate knowledge-base articles by module (HR / admin guides are hidden, see [isTeacherHelpArticle]), search, and a
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
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          key: const Key('help_search'),
          controller: _text,
          textInputAction: TextInputAction.search,
          onSubmitted: c.search,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search help',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _text,
              builder: (_, v, __) => v.text.isEmpty ? const SizedBox.shrink() : IconButton(key: const Key('help_search_clear'), icon: const Icon(Icons.close_rounded, size: 18), onPressed: () { _text.clear(); c.clearSearch(); }),
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.line)),
          ),
        ),
      );

  /// "Contact support": only when the app was built with a support address / page (SupportConfig); never invented.
  Widget _support() {
    final email = SupportConfig.email, url = SupportConfig.url;
    if (email == null && url == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(key: const Key('help_support'), crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SubHeading('Contact support'),
          if (email != null) ListCardRow(key: const Key('help_support_email'), icon: Icons.mail_outline_rounded, title: 'Email support', subtitle: email, trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.faint), onTap: () => ExternalLinks.openMail(email)),
          if (url != null) ListCardRow(key: const Key('help_support_web'), icon: Icons.language_rounded, title: 'Support website', subtitle: url.host, trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.faint), onTap: () => ExternalLinks.openWithConfirm(url.toString())),
        ]),
    );
  }

  Widget _row(KbArticle a) => ListCardRow(
        key: ValueKey('help_${a.key}'),
        icon: Icons.article_outlined,
        title: a.title,
        subtitle: a.tagline.isEmpty ? kbModuleLabel(a.module) : a.tagline,
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.faint),
        onTap: () => Get.toNamed(Routes.helpArticle.replaceFirst(':module', Uri.encodeComponent(a.module)).replaceFirst(':tabKey', Uri.encodeComponent(a.tabKey)), arguments: a),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help')),
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
          header: [_search(), _support()],
          onRefresh: () => c.load(userInitiated: true),
          onRetry: () => c.load(userInitiated: true),
          emptyIcon: Icons.menu_book_outlined,
          emptyTitle: 'No help articles yet',
          emptySubtitle: 'Guides appear here when they are published.',
          builder: (_) => [
            for (final g in c.grouped.entries) ...[SubHeading(kbModuleLabel(g.key)), for (final a in g.value) _row(a)],
            const SizedBox(height: 8),
            const AppCard(key: Key('help_contact'), child: CustomText(text: "Can't find what you need? Ask your school administration, or your safeguarding lead for anything about a child's safety.", fontSize: 12, color: AppColors.muted, height: 1.4)),
          ],
        );
      }),
    );
  }
}
