import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/design/design.dart';
import '../../../../core/models/early_years/ece_models.dart';
import '../../../../core/widgets/detail_bottom_sheet.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../routes/app_routes.dart';
import '../../home/models/section_state.dart';
import '../controllers/early_years_child_controller.dart';
import 'widgets/early_years_widgets.dart';

/// One child's Early Years page (`/early-years/child/:id`): progress by domain, observations, portfolio.
/// Entries not shared with the family are listed too (this is the staff view) and marked "Private".
class EarlyYearsChildScreen extends GetView<EarlyYearsChildController> {
  const EarlyYearsChildScreen({super.key});

  EarlyYearsChildController get c => controller;

  @override
  Widget build(BuildContext context) {
    return EmScaffold(
      appBar: EmAppBar(title: 'Early Years'),
      floatingActionButton: Obx(() {
        final k = c.childState.value.data;
        if (k == null || !c.canManage) return const SizedBox.shrink();
        return FloatingActionButton.extended(
          key: const Key('ey_add_fab'),
          onPressed: () => _showAddSheet(context, k),
          icon: const Icon(Icons.add_rounded),
          label: Text('Add', style: EmType.label.copyWith(color: EmColors.onPrimary)),
        );
      }),
      body: Obx(() => _body(context)),
    );
  }

  /// What can be added for this child: a quick observation, a full observation or a portfolio entry.
  void _showAddSheet(BuildContext context, EceChild k) {
    EmBottomSheet.show<void>(
      context,
      title: 'Add for ${k.firstName.isEmpty ? 'this child' : k.firstName}',
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _addRow(const Key('ey_add_quick'), Icons.bolt_rounded, 'Quick observation', 'A skill and a level in a few taps', () => Get.toNamed(Routes.earlyYearsQuickOf(k.id), arguments: k)),
        _addRow(const Key('ey_add_observe'), Icons.visibility_outlined, 'Observation', 'Write what you saw, add photos', () => Get.toNamed(Routes.earlyYearsObserveOf(k.id), arguments: k)),
        _addRow(const Key('ey_add_portfolio'), Icons.photo_album_outlined, 'Portfolio entry', 'A moment to keep, with photos', () => Get.toNamed(Routes.earlyYearsPortfolioNewOf(k.id), arguments: k)),
      ]),
    );
  }

  Widget _addRow(Key key, IconData icon, String title, String subtitle, VoidCallback go) => Padding(
        padding: const EdgeInsets.only(bottom: EmSpacing.s8),
        child: EmListRow(
          key: key,
          leading: Icon(icon, color: EmColors.primary),
          title: title,
          subtitle: subtitle,
          trailing: const Icon(Icons.chevron_right_rounded, color: EmColors.textSecondary),
          onTap: () {
            Get.back(); // close the sheet
            go();
          },
        ),
      );

  /// Detail sheet of an observation. The photo links are fetched when it opens (loading state meanwhile) and kept in memory only.
  void _openObservation(BuildContext context, EceObservation o) {
    final photos = Rxn<EcePhotoLinks>();
    if (o.evidence.any((e) => e.isPhoto)) {
      c.photoLinks(o.evidence).then((v) => photos.value = v);
    } else {
      photos.value = const EcePhotoLinks([], 0);
    }
    DetailBottomSheet.show<void>(context, reactive: true, fitContent: true, data: () => observationSheetData(o, c.skillNames, photos.value));
  }

  void _openEntry(BuildContext context, EcePortfolioEntry e) {
    final photos = Rxn<EcePhotoLinks>();
    if (e.evidence.any((x) => x.isPhoto)) {
      c.photoLinks(e.evidence).then((v) => photos.value = v);
    } else {
      photos.value = const EcePhotoLinks([], 0);
    }
    DetailBottomSheet.show<void>(context, reactive: true, fitContent: true, data: () => portfolioSheetData(e, photos.value));
  }

  Widget _body(BuildContext context) {
    final cs = c.childState.value;
    if (cs.status != SectionStatus.data) {
      return ScreenStateView<EceChild>(
        state: cs,
        onRefresh: c.reload,
        onRetry: () => c.load(force: true),
        showServerForbidden: true,
        builder: (_) => const [],
      );
    }
    final k = cs.data!;
    final header = <Widget>[
      _ChildHeader(child: k, ageText: c.ageText),
      EmSegmentedTabs<EyTab>(
        segments: const [EmSegment(EyTab.progress, 'Progress'), EmSegment(EyTab.observations, 'Observations'), EmSegment(EyTab.portfolio, 'Portfolio')],
        selected: c.tab.value,
        onChanged: c.setTab,
      ),
      const SizedBox(height: EmSpacing.row),
    ];
    switch (c.tab.value) {
      case EyTab.progress:
        return ScreenStateView<EceProfile>(
          state: c.profileState.value,
          onRefresh: c.reload,
          onRetry: () => c.load(force: true),
          showServerForbidden: true,
          header: header,
          emptyIcon: Icons.insights_outlined,
          emptyTitle: 'No progress recorded yet',
          emptySubtitle: 'Observations that name a learning area and a level build this picture.',
          builder: (p) {
            final rows = c.progress;
            final evidence = rows.fold<int>(0, (sum, d) => sum + d.evidenceCount);
            return [
              if (rows.isNotEmpty)
                EmStatTileRow(tiles: [
                  EmStatTile(key: const Key('ey_stat_areas'), icon: Icons.insights_outlined, value: '${rows.length}', label: 'Learning areas'),
                  EmStatTile(key: const Key('ey_stat_evidence'), icon: Icons.visibility_outlined, value: '$evidence', label: 'Evidence'),
                ]),
              if (rows.isNotEmpty) const SizedBox(height: EmSpacing.row),
              for (final d in rows) EceDomainProgressTile(progress: d),
              if (p.interests.isNotEmpty) ...[
                const _SectionLabel('Interests'),
                Wrap(spacing: EmSpacing.s8, runSpacing: EmSpacing.s8, children: [for (final i in p.interests) EmChip.status(label: i)]),
              ],
              if (p.schemas.isNotEmpty) ...[
                const _SectionLabel('Play patterns'),
                Wrap(spacing: EmSpacing.s8, runSpacing: EmSpacing.s8, children: [for (final i in p.schemas) EmChip.status(label: i)]),
              ],
            ];
          },
        );
      case EyTab.observations:
        return ScreenStateView<List<EceObservation>>(
          state: c.observationsState.value,
          onRefresh: c.reload,
          onRetry: () => c.load(force: true),
          showServerForbidden: true,
          header: header,
          emptyIcon: Icons.visibility_outlined,
          emptyTitle: 'No observations yet',
          emptySubtitle: 'Observations recorded for this child appear here.',
          builder: (list) => [
            const EmInfoBanner(key: Key('ey_obs_note'), tone: EmTone.neutral, text: 'Observations marked Private are only visible to staff.'),
            const SizedBox(height: EmSpacing.row),
            for (final o in list) EceObservationRow(observation: o, onTap: () => _openObservation(context, o)),
          ],
        );
      case EyTab.portfolio:
        return ScreenStateView<List<EcePortfolioEntry>>(
          state: c.portfolioState.value,
          onRefresh: c.reload,
          onRetry: () => c.load(force: true),
          showServerForbidden: true,
          header: header,
          emptyIcon: Icons.photo_album_outlined,
          emptyTitle: 'No portfolio entries yet',
          emptySubtitle: 'Portfolio entries for this child appear here.',
          builder: (list) => [
            const EmInfoBanner(key: Key('ey_portfolio_note'), tone: EmTone.neutral, text: 'Entries marked Private are only visible to staff.'),
            const SizedBox(height: EmSpacing.row),
            for (final e in list) EcePortfolioRow(entry: e, onTap: () => _openEntry(context, e)),
          ],
        );
    }
  }
}

class _ChildHeader extends StatelessWidget {
  final EceChild child;
  final String? ageText;
  const _ChildHeader({required this.child, this.ageText});

  @override
  Widget build(BuildContext context) {
    final sub = [if (child.classLabel.isNotEmpty) child.classLabel, if (ageText != null) ageText!].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: EmSpacing.block),
      child: EmCard(
        key: const Key('ey_child_header'),
        child: Row(children: [
          EceChildAvatar(child: child),
          const SizedBox(width: EmSpacing.row),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(child.fullName.isEmpty ? 'Child' : child.fullName, style: EmType.heading.copyWith(color: EmColors.ink)),
              if (sub.isNotEmpty) Text(sub, style: EmType.caption.copyWith(color: EmColors.textSecondary)),
              if (child.studentCode.isNotEmpty) Text(child.studentCode, style: EmType.caption.copyWith(color: EmColors.textSecondary)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: EmSpacing.block, bottom: EmSpacing.s8),
        child: Semantics(header: true, child: Text(text, style: EmType.label.copyWith(fontWeight: FontWeight.w700, color: EmColors.textSecondary))),
      );
}
