import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/home/teaching.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/utils/fixture_rules.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/confirm_dialog.dart';
import '../../../routes/app_routes.dart';
import '../controllers/fixtures_controller.dart';
import '../../../../core/design/design.dart';

EmTone fixtureStatusStyle(String s) => switch (s) {
      'open' => EmTone.warning,
      'assigned' => EmTone.info,
      'completed' => EmTone.success,
      _ => EmTone.neutral,
    };

String fixtureStatusLabel(String s, {required bool iAmOriginalTeacher}) => switch (s) {
      'open' => iAmOriginalTeacher ? 'NOT COVERED YET' : 'OPEN',
      'assigned' => 'ASSIGNED',
      'completed' => 'COMPLETED',
      'cancelled' => 'CANCELLED',
      _ => s.isEmpty ? 'UNKNOWN' : s.toUpperCase().replaceAll('_', ' '),
    };

String periodLine(Substitution s) => [
      if (s.periodNo != null) 'Period ${s.periodNo}',
      if (s.startTime.isNotEmpty || s.endTime.isNotEmpty) [s.startTime, s.endTime].where((e) => e.isNotEmpty).join(' - '),
    ].join(' · ');

String detailLine(Substitution s) => [s.classLabel, s.subject, if (s.roomNo.isNotEmpty) 'Room ${s.roomNo}'].where((e) => e.isNotEmpty).join(' · ');

String dayHeading(DateTime d, DateTime now) {
  final t = DateTime(now.year, now.month, now.day);
  final diff = daysBetween(t, d);
  if (diff == 0) return 'Today · ${shortDay(d)}';
  if (diff == 1) return 'Tomorrow · ${shortDay(d)}';
  return '${shortDay(d)} ${d.year}';
}

/// Substitutions (`/fixtures`): 'Covering for others' and 'My periods covered'.
class FixturesScreen extends GetView<FixturesController> {
  const FixturesScreen({super.key});

  FixturesController get c => controller;

  @override
  Widget build(BuildContext context) {
    return EmScaffold(
      appBar: EmAppBar(title: 'Substitutions'),
      body: Obx(() {
        final st = c.load.value;
        final tab = c.tab.value;
        final now = c.clock();
        return ScreenStateView<List<Substitution>>(
          state: st,
          onRefresh: () => c.reload(userInitiated: true),
          onRetry: () => c.reload(userInitiated: true),
          emptyIcon: Icons.swap_horiz_rounded,
          emptyTitle: 'No substitutions',
          emptySubtitle: 'Periods you cover for a colleague, or that a colleague covers for you, appear here.',
          header: [
            if (st.hasData) ...[
              EmSegmentedTabs<FixtureTab>(
                key: const Key('fx_tabs'),
                segments: [
                  EmSegment(FixtureTab.covering, 'Covering for others (${c.rows(FixtureTab.covering).length})'),
                  EmSegment(FixtureTab.covered, 'My periods covered (${c.rows(FixtureTab.covered).length})'),
                ],
                selected: tab,
                onChanged: c.selectTab,
              ),
              const SizedBox(height: EmSpacing.s16),
            ],
          ],
          builder: (_) {
            final rows = c.rows(tab);
            if (rows.isEmpty) {
              return [
                Padding(
                  padding: const EdgeInsets.only(top: EmSpacing.s24),
                  child: AppEmptyView(
                    key: const Key('fx_tab_empty'),
                    icon: Icons.swap_horiz_rounded,
                    title: tab == FixtureTab.covering ? "You aren't covering any period" : 'None of your periods needs cover',
                    subtitle: 'Showing from 14 days ago onward.',
                  ),
                ),
              ];
            }
            final g = groupFixtures(rows, now);
            return [
              for (final d in g.days) ...[
                SubHeading(dayHeading(d.day, now)),
                for (final s in d.rows) FixtureCard(fixture: s, tab: tab, onTap: () => Get.toNamed(Routes.fixtureDetailOf(s.id))),
              ],
              for (final s in g.undated) FixtureCard(fixture: s, tab: tab, onTap: () => Get.toNamed(Routes.fixtureDetailOf(s.id))),
              if (c.cut.value) Text('Showing the first 200 substitutions.', key: const Key('fx_cut'), textAlign: TextAlign.center, style: EmType.caption.copyWith(color: EmColors.textSecondary)),
            ];
          },
        );
      }),
    );
  }
}

class FixtureCard extends StatelessWidget {
  final Substitution fixture;
  final FixtureTab tab;
  final VoidCallback onTap;
  const FixtureCard({super.key, required this.fixture, required this.tab, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = fixture;
    final covering = tab == FixtureTab.covering;
    final who = covering
        ? 'Covering for ${s.originalTeacherName.isEmpty ? 'a colleague' : s.originalTeacherName}'
        : (s.substituteTeacherName.isEmpty ? (s.status == 'open' ? 'Not covered yet' : 'No substitute named') : 'Covered by ${s.substituteTeacherName}');
    return AppCard(
      key: ValueKey('fx_${s.id}'),
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(periodLine(s).isEmpty ? 'Period' : periodLine(s), style: EmType.body.copyWith(fontWeight: FontWeight.w800, color: EmColors.ink))),
          const SizedBox(width: EmSpacing.s8),
          AppTag(fixtureStatusLabel(s.status, iAmOriginalTeacher: !covering), style: fixtureStatusStyle(s.status)),
        ]),
        const SizedBox(height: EmSpacing.s4),
        Text(detailLine(s).isEmpty ? '-' : detailLine(s), style: EmType.label.copyWith(color: EmColors.ink, fontWeight: FontWeight.w700)),
        const SizedBox(height: EmSpacing.s4),
        Text(who, style: EmType.caption.copyWith(color: EmColors.textSecondary)),
      ]),
    );
  }
}

/// One substitution (`/fixtures/:id`): resolved from the loaded list (no get-one endpoint exists).
class FixtureDetailScreen extends StatefulWidget {
  final String? fixtureId;
  const FixtureDetailScreen({super.key, this.fixtureId});

  @override
  State<FixtureDetailScreen> createState() => _FixtureDetailScreenState();
}

class _FixtureDetailScreenState extends State<FixtureDetailScreen> {
  late final String id = widget.fixtureId ?? Get.parameters['id'] ?? '';
  final c = Get.find<FixturesController>();

  void _snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

  @override
  void initState() {
    super.initState();
    if (!c.load.value.hasData) c.reload(userInitiated: true);
  }

  Future<void> _complete(Substitution s) async {
    final ok = await ConfirmDialog.show(title: 'Mark this cover as complete?', message: '${periodLine(s)} · ${s.classLabel}', confirmLabel: 'Mark complete');
    if (!ok || !mounted) return;
    final r = await c.complete(id);
    if (!mounted) return;
    switch (r) {
      case CompleteDone():
        _snack('Marked as complete.');
      case CompleteFailed(:final text):
        _snack(text);
      case CompleteIgnored():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return EmScaffold(
      appBar: EmAppBar(title: 'Substitution'),
      body: Obx(() {
        final st = c.load.value;
        final s = c.find(id);
        return ScreenStateView<List<Substitution>>(
          state: st,
          onRefresh: () => c.reload(userInitiated: true),
          onRetry: () => c.reload(userInitiated: true),
          builder: (_) {
            if (s == null) {
              return [const Padding(padding: EdgeInsets.only(top: EmSpacing.s24), child: AppEmptyView(key: Key('fx_not_found'), icon: Icons.search_off_rounded, title: 'Substitution not found', subtitle: 'It is not in your recent substitutions (the last 14 days and later).'))];
            }
            final mine = iAmSubstitute(s, c.myStaffId);
            final d = fixtureDay(s);
            final working = c.completing.value == s.id;
            return [
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Text(periodLine(s).isEmpty ? 'Period' : periodLine(s), key: const Key('fx_title'), style: EmType.bodyLarge.copyWith(fontWeight: FontWeight.w800, color: EmColors.ink))),
                    const SizedBox(width: EmSpacing.s8),
                    AppTag(fixtureStatusLabel(s.status, iAmOriginalTeacher: !mine), style: fixtureStatusStyle(s.status)),
                  ]),
                  const SizedBox(height: EmSpacing.s12),
                  _line(Icons.event_rounded, d == null ? 'Date not set' : '${shortDay(d)} ${d.year}'),
                  _line(Icons.groups_rounded, s.classLabel.isEmpty ? 'Class not set' : s.classLabel),
                  if (s.subject.isNotEmpty) _line(Icons.menu_book_rounded, s.subject),
                  if (s.roomNo.isNotEmpty) _line(Icons.meeting_room_rounded, 'Room ${s.roomNo}'),
                  _line(Icons.person_off_rounded, 'Away: ${s.originalTeacherName.isEmpty ? 'a colleague' : s.originalTeacherName}'),
                  _line(Icons.person_rounded, s.substituteTeacherName.isEmpty ? 'No substitute assigned yet' : 'Cover: ${s.substituteTeacherName}'),
                  if (s.reason.isNotEmpty) _line(Icons.info_outline_rounded, 'Reason: ${s.reason}'),
                  if (s.notes.isNotEmpty) _line(Icons.notes_rounded, s.notes),
                ]),
              ),
              if (c.canManageFixtures && canMarkComplete(s, c.myStaffId))
                EmPrimaryButton(key: const Key('fx_complete'), label: 'Mark complete', loading: working, onPressed: c.completing.value != null ? null : () => _complete(s)),
            ];
          },
        );
      }),
    );
  }

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: EmSpacing.s8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.only(top: EmSpacing.s2), child: ExcludeSemantics(child: Icon(icon, size: 18, color: EmColors.textSecondary))), const SizedBox(width: EmSpacing.s8), Expanded(child: Text(text, style: EmType.label.copyWith(color: EmColors.ink, fontWeight: FontWeight.w500)))]),
      );
}
