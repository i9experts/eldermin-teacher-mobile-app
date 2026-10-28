import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/behaviour/behaviour_models.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/widgets/app_date_picker.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../routes/app_routes.dart';
import '../../homework/views/widgets/homework_widgets.dart';
import '../../home/models/section_state.dart';
import '../controllers/behaviour_controller.dart';
import 'behaviour_detail_sheet.dart';
import 'widgets/behaviour_widgets.dart';
import '../../../../core/design/design.dart';

/// Behaviour & Tarbiyah (`/behaviour`): what I logged and what is recorded for my classes. Records of other classes never appear.
class BehaviourScreen extends StatefulWidget {
  const BehaviourScreen({super.key});

  @override
  State<BehaviourScreen> createState() => _BehaviourScreenState();
}

class _BehaviourScreenState extends State<BehaviourScreen> {
  final search = TextEditingController();
  BehaviourController get c => Get.find<BehaviourController>();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _openFilters(BuildContext context) => EmBottomSheet.show<void>(
        context,
        title: 'Filter records',
        child: _FilterSheet(initial: c.filters.value, onApply: (f) {
          Navigator.of(context).pop();
          c.setFilters(f);
        }),
      );

  @override
  Widget build(BuildContext context) {
    return EmScaffold(
      appBar: EmAppBar(title: 'Behaviour & Tarbiyah'),
      floatingActionButton: Obx(() => c.canView && c.canLog && c.classes.isNotEmpty && c.state.value.status != SectionStatus.forbidden
          ? EmDiamondFab(key: const Key('beh_new_fab'), icon: Icons.add_rounded, semanticLabel: 'Log behaviour', onPressed: () => Get.toNamed(Routes.behaviourNew))
          : const SizedBox.shrink()),
      body: Obx(_body),
    );
  }

  Widget _body() {
    final state = c.state.value;
    final scope = c.scope.value;
    final filter = c.classFilter.value;
    final visible = c.visible;
    final classes = c.classes;
    final myCount = c.countMine();
    final total = c.all.length;
    final q = c.query.value;
    final myId = c.myId, myName = c.myName;
    return ScreenStateView<List<BehaviourRecord>>(
      state: state,
      onRefresh: c.reload,
      onRetry: () => c.load(force: true),
      emptyIcon: classes.isEmpty ? Icons.school_outlined : Icons.emoji_events_outlined,
      emptyTitle: classes.isEmpty ? "You aren't assigned to any class yet" : 'No behaviour recorded yet',
      emptySubtitle: classes.isEmpty ? 'Behaviour is logged for the students of your classes. Ask your school admin to assign you to a class.' : 'Tap "Log behaviour" to record a merit, a concern or a note.',
      padding: EmSpacing.listPaddingFab,
      header: [
        const EmCaptionLine('Merits, concerns and notes'),
        if (c.canView) const ParentVisibleNote(text: 'Everything recorded here is visible to the student\'s parents in their app.'),
        if (state.hasData) ...[
          EmSegmentedTabs<BehaviourScope>(
            segments: [EmSegment(BehaviourScope.mine, 'My entries ($myCount)'), EmSegment(BehaviourScope.classes, 'My classes ($total)')],
            selected: scope == BehaviourScope.mine ? BehaviourScope.mine : BehaviourScope.classes,
            onChanged: c.setScope,
          ),
          const SizedBox(height: EmSpacing.row),
          if (classes.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: EmSpacing.row),
              child: FilterChipsRow(chips: [
                ('All classes', -1, filter < 0, () => c.setClassFilter(-1), 'cls_all'),
                for (var i = 0; i < classes.length; i++) (classes[i].label, -1, filter == i, () => c.setClassFilter(i), 'cls_$i'),
              ]),
            ),
          EmSearchPill(fieldKey: const Key('beh_search'), controller: search, hint: 'Search by student or title', onChanged: (v) => c.query.value = v, onSubmitted: c.submitSearch),
          const SizedBox(height: EmSpacing.row),
          _FilterBar(c: c, onOpen: () => _openFilters(context)),
        ],
      ],
      builder: (_) {
        if (visible.isEmpty) {
          return [
            Padding(
              padding: const EdgeInsets.only(top: EmSpacing.s24),
              child: AppEmptyView(
                key: const Key('beh_filter_empty'),
                icon: Icons.filter_alt_off_outlined,
                title: q.isNotEmpty ? 'Nothing matches "$q"' : (scope == BehaviourScope.mine ? "You haven't logged anything yet" : 'No records for this class'),
              ),
            ),
          ];
        }
        return [
          for (final r in visible)
            () {
              final mine = r.isMine(userId: myId, userName: myName);
              return BehaviourTile(
                record: r,
                mine: mine,
                onTap: () => showBehaviourDetailSheet(
                  context,
                  r,
                  mine: mine,
                  actions: BehaviourSheetActions(
                    onEdit: c.canLog ? (rec) => Get.toNamed(Routes.behaviourNew, arguments: rec) : null,
                    onResolved: c.canLog ? c.replaceRecord : null,
                    onOpenStudent: (rec) => Get.toNamed(Routes.behaviourStudentOf(rec.studentId)),
                  ),
                ),
              );
            }(),
          _LoadMore(c: c),
        ];
      },
    );
  }
}


/// "Filters" button + a chip per active filter (tap a chip to drop it).
class _FilterBar extends StatelessWidget {
  final BehaviourController c;
  final VoidCallback onOpen;
  const _FilterBar({required this.c, required this.onOpen});

  @override
  Widget build(BuildContext context) => Obx(() {
        final f = c.filters.value;
        final chips = <(String, RecordFilters)>[
          if (f.type != null) (BehaviourKind.fromWire(f.type)?.label ?? f.type!, f.copyWith(type: null)),
          if (f.severity != null) ('${severityLabel(f.severity!)} severity', f.copyWith(severity: null)),
          if (f.resolved != null) (f.resolved! ? 'Resolved' : 'Open', f.copyWith(resolved: null)),
          if (f.from != null) ('From ${shortDay(f.from!)}', f.copyWith(from: null)),
          if (f.to != null) ('To ${shortDay(f.to!)}', f.copyWith(to: null)),
        ];
        return Padding(
          padding: const EdgeInsets.only(bottom: EmSpacing.row),
          child: Wrap(spacing: EmSpacing.s8, runSpacing: EmSpacing.s8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            EmChip(key: const Key('beh_filter_btn'), label: f.count == 0 ? 'Filters' : 'Filters (${f.count})', icon: Icons.tune_rounded, selected: f.count > 0, onTap: onOpen),
            for (final (label, without) in chips) EmChip(key: Key('beh_filter_$label'), label: label, icon: Icons.close_rounded, selected: true, onTap: () => c.setFilters(without)),
          ]),
        );
      });
}

class _LoadMore extends StatelessWidget {
  final BehaviourController c;
  const _LoadMore({required this.c});

  @override
  Widget build(BuildContext context) => Obx(() {
        if (!c.hasMore.value) return const SizedBox.shrink();
        final err = c.loadMoreError.value;
        return Padding(
          padding: const EdgeInsets.only(top: EmSpacing.s8, bottom: EmSpacing.block),
          child: Column(children: [
            if (err != null) Padding(padding: const EdgeInsets.only(bottom: EmSpacing.s8), child: Text(err, key: const Key('beh_load_more_error'), textAlign: TextAlign.center, style: EmType.body.copyWith(color: EmColors.error))),
            EmSecondaryButton(key: const Key('beh_load_more'), label: err != null ? 'Try again' : 'Load more', loading: c.loadingMore.value, onPressed: c.loadingMore.value ? null : c.loadMore),
          ]),
        );
      });
}

/// type / severity / status / date range, applied together.
class _FilterSheet extends StatefulWidget {
  final RecordFilters initial;
  final void Function(RecordFilters) onApply;
  const _FilterSheet({required this.initial, required this.onApply});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late RecordFilters f = widget.initial;

  Widget _group(String label, List<Widget> chips) => Padding(
        padding: const EdgeInsets.only(bottom: EmSpacing.block),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [FormLabel(label), Wrap(spacing: EmSpacing.s8, runSpacing: EmSpacing.s8, children: chips)]),
      );

  Future<void> _pick(bool from) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cur = (from ? f.from : f.to) ?? today;
    final picked = await showAppDatePicker(context, initialDate: cur, firstDate: DateTime(today.year - 2), lastDate: today);
    if (picked != null) setState(() => f = from ? f.copyWith(from: picked) : f.copyWith(to: picked));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(EmSpacing.screenH, 0, EmSpacing.screenH, EmSpacing.s16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _group('Type', [
          for (final k in BehaviourKind.values) EmChip(key: Key('f_type_${k.wire}'), label: k.label, selected: f.type == k.wire, onTap: () => setState(() => f = f.copyWith(type: f.type == k.wire ? null : k.wire))),
        ]),
        _group('Severity', [
          for (final sv in kSeverities) EmChip(key: Key('f_sev_$sv'), label: severityLabel(sv), selected: f.severity == sv, onTap: () => setState(() => f = f.copyWith(severity: f.severity == sv ? null : sv))),
        ]),
        _group('Status', [
          EmChip(key: const Key('f_res_open'), label: 'Open', selected: f.resolved == false, onTap: () => setState(() => f = f.copyWith(resolved: f.resolved == false ? null : false))),
          EmChip(key: const Key('f_res_resolved'), label: 'Resolved', selected: f.resolved == true, onTap: () => setState(() => f = f.copyWith(resolved: f.resolved == true ? null : true))),
        ]),
        const FormLabel('Date range'),
        Row(children: [
          Expanded(child: KeyedSubtree(key: const Key('f_from'), child: EmSelectField(icon: Icons.event_rounded, trailingIcon: null, title: f.from == null ? null : '${shortDay(f.from!)} ${f.from!.year}', placeholder: 'From', onTap: () => _pick(true)))),
          const SizedBox(width: EmSpacing.s8),
          Expanded(child: KeyedSubtree(key: const Key('f_to'), child: EmSelectField(icon: Icons.event_rounded, trailingIcon: null, title: f.to == null ? null : '${shortDay(f.to!)} ${f.to!.year}', placeholder: 'To', onTap: () => _pick(false)))),
        ]),
        const SizedBox(height: EmSpacing.block),
        EmPrimaryButton(key: const Key('f_apply'), label: 'Apply filters', onPressed: () => widget.onApply(f)),
        const SizedBox(height: EmSpacing.s8),
        EmTextAction(key: const Key('f_clear'), onPressed: () => widget.onApply(RecordFilters.none.copyWith(search: f.search)), icon: Icons.filter_alt_off_outlined, label: 'Clear filters'),
      ]),
    );
  }
}
