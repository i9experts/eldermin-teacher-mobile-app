import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/design/design.dart';
import '../../../../core/models/early_years/ece_models.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
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
      body: Obx(_body),
    );
  }

  Widget _body() {
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
          builder: (p) => [
            for (final d in c.progress) EceDomainProgressTile(progress: d),
            if (p.interests.isNotEmpty) ...[
              const SectionRow(title: 'Interests'),
              Wrap(spacing: EmSpacing.s8, runSpacing: EmSpacing.s8, children: [for (final i in p.interests) AppTag(i, style: EmTone.neutral)]),
            ],
            if (p.schemas.isNotEmpty) ...[
              const SectionRow(title: 'Play patterns'),
              Wrap(spacing: EmSpacing.s8, runSpacing: EmSpacing.s8, children: [for (final i in p.schemas) AppTag(i, style: EmTone.neutral)]),
            ],
          ],
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
            for (final o in list) EceObservationCard(observation: o, skillNames: c.skillNames, resolve: c.photoUrl),
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
            for (final e in list) EcePortfolioCard(entry: e, resolve: c.photoUrl),
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
      child: AppCard(
        key: const Key('ey_child_header'),
        margin: EdgeInsets.zero,
        child: Row(children: [
          EceChildAvatar(child: child, size: 56),
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
