import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/assessments/reference_models.dart';
import '../../../../core/theme/app_theme.dart' show TagStyle;
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../home/models/section_state.dart';
import '../../homework/views/widgets/homework_widgets.dart' show FilterChipsRow;
import '../controllers/library_controller.dart';
import '../../../../core/design/design.dart';

/// Library catalogue (`/library`): search by title / author / ISBN (whole words) and see whether a copy is available. Read-only: issuing,
/// returning, renewing, fines and reservations are librarian actions.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final text = TextEditingController();
  final scroll = ScrollController();
  Timer? _debounce;
  LibraryController get c => Get.find<LibraryController>();

  @override
  void initState() {
    super.initState();
    scroll.addListener(() {
      if (scroll.hasClients && scroll.position.pixels > scroll.position.maxScrollExtent - 300) unawaited(c.loadMore());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    text.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _typed(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => c.setQuery(v));
  }

  @override
  Widget build(BuildContext context) {
    return EmScaffold(
      appBar: EmAppBar(title: 'Library'),
      body: Obx(() {
        final state = c.state.value;
        final cat = c.category.value;
        final avail = c.availableOnly.value;
        final more = c.hasMore;
        final loadingMore = c.loadingMore.value;
        final moreErr = c.loadMoreError.value;
        final totalCount = c.total.value;
        return ScreenStateView<List<Book>>(
          scrollController: scroll,
          state: c.canView ? state : const SectionState<List<Book>>.forbidden(),
          onRefresh: c.reload,
          onRetry: () => c.load(force: true),
          emptyIcon: Icons.local_library_outlined,
          emptyTitle: c.filtersActive ? 'No books match' : 'The catalogue is empty',
          emptySubtitle: c.filtersActive ? 'Search matches whole words (try "fractions", not "fract"). Clear the filters to see everything.' : 'No books have been added to your library yet.',
          header: [
            EmCaptionLine(totalCount == null ? 'Search the catalogue' : '$totalCount ${totalCount == 1 ? 'book' : 'books'}'),
            if (c.canView && state.status != SectionStatus.forbidden) ...[
              EmSearchPill(
                fieldKey: const Key('lib_search'),
                controller: text,
                hint: 'Title, author or ISBN',
                onChanged: _typed,
                onSubmitted: (v) {
                  _debounce?.cancel();
                  c.setQuery(v);
                },
              ),
              const SizedBox(height: EmSpacing.row),
              FilterChipsRow(chips: [
                ('Available now', -1, avail, () => c.toggleAvailable(!avail), 'available'),
                for (final k in const ['textbook', 'science', 'fiction', 'islamic', 'reference'])
                  (bookCategoryLabel(k), -1, cat == k, () => c.setCategory(cat == k ? '' : k), 'cat_$k'),
              ]),
              const SizedBox(height: EmSpacing.row),
            ],
          ],
          builder: (books) => [
            for (final b in books) _BookTile(key: ValueKey('book_${b.id}'), book: b),
            if (loadingMore) const Padding(padding: EdgeInsets.all(EmSpacing.s12), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
            if (moreErr != null) TextButton(key: const Key('lib_more_retry'), onPressed: c.loadMore, child: Text(moreErr, textAlign: TextAlign.center, style: EmType.label.copyWith(color: EmColors.error))),
            if (more && !loadingMore && moreErr == null) const SizedBox(height: EmSpacing.s24),
          ],
        );
      }),
    );
  }
}

class _BookTile extends StatelessWidget {
  final Book book;
  const _BookTile({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    final b = book;
    final where = [if (b.location.isNotEmpty) b.location, if (b.shelfNo.isNotEmpty) 'shelf ${b.shelfNo}', if (b.callNumber.isNotEmpty) b.callNumber].join(' · ');
    final quiet = EmType.body.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(b.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.bodyLarge.copyWith(color: EmColors.ink))),
          const SizedBox(width: EmSpacing.s8),
          AppTag(b.isAvailable ? '${b.availableCopies} OF ${b.totalCopies} AVAILABLE' : 'ALL ISSUED', style: b.isAvailable ? TagStyle.green : TagStyle.amber),
        ]),
        const SizedBox(height: EmSpacing.s4),
        Text([b.author, if (b.publishYear != null) '${b.publishYear}'].where((e) => e.isNotEmpty).join(' · '), style: quiet),
        Text([bookCategoryLabel(b.category), if (b.language.isNotEmpty) b.language, if (b.edition.isNotEmpty) '${b.edition} ed.'].join(' · '), style: quiet),
        if (where.isNotEmpty) Text(where, style: quiet),
        if (b.gradeLevels.isNotEmpty) Text('For ${b.gradeLevels.join(', ')}', style: quiet),
      ]),
    );
  }
}
