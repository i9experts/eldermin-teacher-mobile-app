import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/home/teaching.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/utils/fixture_rules.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/confirm_dialog.dart';
import '../../../components/custom_text.dart';
import '../../../routes/app_routes.dart';
import '../controllers/fixtures_controller.dart';

TagStyle fixtureStatusStyle(String s) => switch (s) {
      'open' => TagStyle.amber,
      'assigned' => TagStyle.info,
      'completed' => TagStyle.green,
      _ => TagStyle.neutral,
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
    return Scaffold(
      appBar: AppBar(title: const Text('Substitutions')),
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
              SegmentedControl(
                key: const Key('fx_tabs'),
                options: ['Covering for others (${c.rows(FixtureTab.covering).length})', 'My periods covered (${c.rows(FixtureTab.covered).length})'],
                selectedIndex: tab.index,
                onChanged: (i) => c.selectTab(FixtureTab.values[i]),
              ),
              const SizedBox(height: 12),
            ],
          ],
          builder: (_) {
            final rows = c.rows(tab);
            if (rows.isEmpty) {
              return [
                Padding(
                  padding: const EdgeInsets.only(top: 24),
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
              if (c.cut.value) const CustomText(key: Key('fx_cut'), text: 'Showing the first 200 substitutions.', fontSize: 11, color: AppColors.muted, textAlign: TextAlign.center),
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
          Expanded(child: CustomText(text: periodLine(s).isEmpty ? 'Period' : periodLine(s), fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.primaryColor)),
          const SizedBox(width: 8),
          AppTag(fixtureStatusLabel(s.status, iAmOriginalTeacher: !covering), style: fixtureStatusStyle(s.status)),
        ]),
        const SizedBox(height: 4),
        CustomText(text: detailLine(s).isEmpty ? '-' : detailLine(s), fontSize: 12, color: AppColors.ink, fontWeight: FontWeight.w700),
        const SizedBox(height: 3),
        CustomText(text: who, fontSize: 11.5, color: AppColors.muted),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Substitution')),
      body: Obx(() {
        final st = c.load.value;
        final s = c.find(id);
        return ScreenStateView<List<Substitution>>(
          state: st,
          onRefresh: () => c.reload(userInitiated: true),
          onRetry: () => c.reload(userInitiated: true),
          builder: (_) {
            if (s == null) {
              return [const Padding(padding: EdgeInsets.only(top: 24), child: AppEmptyView(key: Key('fx_not_found'), icon: Icons.search_off_rounded, title: 'Substitution not found', subtitle: 'It is not in your recent substitutions (the last 14 days and later).'))];
            }
            final mine = iAmSubstitute(s, c.myStaffId);
            final d = fixtureDay(s);
            final working = c.completing.value == s.id;
            return [
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: CustomText(key: const Key('fx_title'), text: periodLine(s).isEmpty ? 'Period' : periodLine(s), fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primaryColor)),
                    AppTag(fixtureStatusLabel(s.status, iAmOriginalTeacher: !mine), style: fixtureStatusStyle(s.status)),
                  ]),
                  const SizedBox(height: 10),
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
              if (canMarkComplete(s, c.myStaffId))
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const Key('fx_complete'),
                    onPressed: c.completing.value != null ? null : () => _complete(s),
                    child: working ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Mark complete'),
                  ),
                ),
            ];
          },
        );
      }),
    );
  }

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 16, color: AppColors.muted), const SizedBox(width: 8), Expanded(child: CustomText(text: text, fontSize: 13, color: AppColors.ink))]),
      );
}
