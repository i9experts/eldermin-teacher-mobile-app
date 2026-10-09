import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/help/kb_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/custom_text.dart';
import '../../../routes/app_routes.dart';
import '../controllers/help_controller.dart';

/// Help (`/help`): knowledge-base articles by module, with search.
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
            header: [_search()],
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
          header: [_search()],
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
