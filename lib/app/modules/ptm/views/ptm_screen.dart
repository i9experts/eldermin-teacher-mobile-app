import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/utils/ptm_rules.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../routes/app_routes.dart';
import '../controllers/ptm_controller.dart';
import 'widgets/ptm_widgets.dart';
import '../../../../core/design/design.dart';
import '../../../common/write_access.dart';

/// Parent meetings (`/ptm`): Upcoming / Today / Past / Cancelled tabs of MY meetings.
class PtmScreen extends GetView<PtmController> {
  const PtmScreen({super.key});

  PtmController get c => controller;

  static const _labels = {PtmTab.upcoming: 'Upcoming', PtmTab.today: 'Today', PtmTab.past: 'Past', PtmTab.cancelled: 'Cancelled'};

  @override
  Widget build(BuildContext context) {
    return EmScaffold(
      appBar: EmAppBar(title: 'Parent meetings'),
      floatingActionButton: Obx(() => canWritePtm
          ? FloatingActionButton.extended(
              key: const Key('ptm_new'),
              onPressed: () => Get.toNamed(Routes.ptmNew),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New meeting'),
            )
          : const SizedBox.shrink()),
      body: Obx(() {
        final st = c.load.value;
        final tab = c.tab.value;
        final tabs = c.tabs;
        final now = c.clock();
        return ScreenStateView(
          state: st,
          onRefresh: () => c.reload(userInitiated: true),
          onRetry: () => c.reload(userInitiated: true),
          emptyIcon: Icons.handshake_outlined,
          emptyTitle: 'No parent meetings yet',
          emptySubtitle: 'Meetings you schedule, and the ones the school books with you, appear here.',
          padding: const EdgeInsets.fromLTRB(EmSpacing.screenH, EmSpacing.s16, EmSpacing.screenH, EmSpacing.fabClearance),
          header: [
            if (st.hasData) ...[
              EmSegmentedTabs<PtmTab>(
                key: const Key('ptm_tabs'),
                segments: [for (final t in PtmTab.values) EmSegment(t, '${_labels[t]} (${tabs.countOf(t)})')],
                selected: tab,
                onChanged: c.selectTab,
              ),
              const SizedBox(height: EmSpacing.s16),
            ],
          ],
          builder: (t) {
            Widget card(m) => PtmCard(meeting: m, now: now, onTap: () => Get.toNamed(Routes.ptmDetailOf(m.id)));
            switch (tab) {
              case PtmTab.today:
                if (t.todayCount == 0) return [_none('No meetings today', 'Nothing is booked for today.')];
                return [
                  for (final m in t.todayRemaining) card(m),
                  if (t.todayEarlier.isNotEmpty) ...[const SubHeading('Earlier today'), for (final m in t.todayEarlier) card(m)],
                ];
              case PtmTab.upcoming:
                if (t.upcoming.isEmpty) return [_none('No upcoming meetings', 'Requested and confirmed meetings on later days appear here.')];
                return [for (final m in t.upcoming) card(m), if (c.aheadCut.value) _cut('Showing the first ${PtmController.serverLimit} meetings from today on.')];
              case PtmTab.past:
                if (t.past.isEmpty) return [_none('No past meetings', 'Meetings that already took place appear here.')];
                return [for (final m in t.past) card(m), if (c.pastCut.value) _cut('Showing the latest ${PtmController.serverLimit} earlier meetings.')];
              case PtmTab.cancelled:
                if (t.cancelled.isEmpty) return [_none('No cancelled meetings', 'Cancelled meetings are kept here.')];
                return [for (final m in t.cancelled) card(m)];
            }
          },
        );
      }),
    );
  }

  Widget _none(String title, String sub) => Padding(padding: const EdgeInsets.only(top: EmSpacing.s24), child: AppEmptyView(key: const Key('ptm_tab_empty'), icon: Icons.event_busy_outlined, title: title, subtitle: sub));
  Widget _cut(String text) => Padding(padding: const EdgeInsets.only(top: EmSpacing.s4), child: Text(text, key: const Key('ptm_cut'), textAlign: TextAlign.center, style: EmType.caption.copyWith(color: EmColors.textSecondary)));
}
