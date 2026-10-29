import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/behaviour/behaviour_models.dart';
import '../../../../core/models/classroom/student_models.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../routes/app_routes.dart';
import '../../home/models/section_state.dart';
import '../controllers/behaviour_student_controller.dart';
import '../controllers/tarbiyah_form_controller.dart';
import 'behaviour_detail_sheet.dart';
import 'widgets/behaviour_widgets.dart';
import '../../../../core/design/design.dart';

final _quiet = EmType.body.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400);

/// One student's behaviour and Tarbiyah history (`/behaviour/student/:id`). Only for students in MY classes.
class BehaviourStudentScreen extends GetView<BehaviourStudentController> {
  const BehaviourStudentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return EmScaffold(
      appBar: EmAppBar(title: 'Student behaviour'),
      floatingActionButton: Obx(() {
        final s = c.student.value.data;
        return s != null && c.canLog
            ? EmDiamondFab(
                key: const Key('beh_student_log'),
                icon: Icons.add_rounded,
                semanticLabel: 'Log behaviour',
                onPressed: () async {
                  await Get.toNamed(Routes.behaviourNew, arguments: s);
                  c.load();
                },
              )
            : const SizedBox.shrink();
      }),
      body: Obx(() {
        final st = c.student.value;
        // reactive reads here, not in the builder
        final recs = c.records.value;
        final tar = c.tarbiyah.value;
        final pts = c.totalPoints;
        final more = c.recordsHasMore.value;
        final moreErr = c.recordsLoadMoreError.value;
        final loadingMore = c.loadingMoreRecords.value;
        final cfg = c.settings.value;
        final myId = c.myId, myName = c.myName;
        return ScreenStateView<StudentSummary>(
          state: st,
          onRefresh: c.reload,
          onRetry: c.load,
          emptyIcon: Icons.lock_outline_rounded,
          emptyTitle: "This student isn't in one of your classes",
          emptySubtitle: 'You can only see behaviour for the students you teach.',
          padding: EmSpacing.listPaddingFab,
          builder: (s) => [
            Text(s.fullName, style: EmType.title.copyWith(color: EmColors.ink)),
            EmCaptionLine([if (s.grade.isNotEmpty) '${s.grade}${s.section.isEmpty ? '' : ' - ${s.section}'}', if ((s.rollNumber ?? '').isNotEmpty) 'Roll ${s.rollNumber}'].join(' · ')),
            if (recs.hasData) StatsRow(items: [('${recs.data!.length}', 'Records', null), (pointsText(pts), 'Points', null)]),
            const SubHeading('Behaviour records'),
            ..._section<List<BehaviourRecord>>(
              recs,
              emptyKey: 'student_no_records',
              emptyText: 'No behaviour recorded for this student yet.',
              retry: c.load,
              builder: (list) => [
                for (final r in list)
                  () {
                    final mine = r.isMine(userId: myId, userName: myName);
                    return BehaviourTile(
                      record: r,
                      mine: mine,
                      showStudent: false,
                      onTap: () => showBehaviourDetailSheet(
                        context,
                        r,
                        mine: mine,
                        actions: BehaviourSheetActions(
                          onEdit: c.canLog
                              ? (rec) async {
                                  await Get.toNamed(Routes.behaviourNew, arguments: rec);
                                  c.load();
                                }
                              : null,
                          onResolved: c.canLog ? c.replaceRecord : null,
                        ),
                      ),
                    );
                  }(),
                if (more)
                  Padding(
                    padding: const EdgeInsets.only(top: EmSpacing.s8, bottom: EmSpacing.s16),
                    child: Column(children: [
                      if (moreErr != null) Padding(padding: const EdgeInsets.only(bottom: EmSpacing.s8), child: Text(moreErr, key: const Key('student_load_more_error'), textAlign: TextAlign.center, style: EmType.body.copyWith(color: EmColors.error))),
                      EmSecondaryButton(key: const Key('student_load_more'), label: moreErr != null ? 'Try again' : 'Load more records', loading: loadingMore, onPressed: loadingMore ? null : c.loadMoreRecords),
                    ]),
                  ),
              ],
            ),
            SubHeading('${cfg.programName} assessments'),
            if (c.canLog && tar.status != SectionStatus.loading && tar.status != SectionStatus.forbidden)
              Padding(
                padding: const EdgeInsets.only(bottom: EmSpacing.row),
                child: EmSecondaryButton(
                  key: const Key('tarbiyah_add'),
                  expand: true,
                  icon: Icons.add_rounded,
                  label: 'New ${cfg.programName} assessment',
                  onPressed: () => Get.toNamed(Routes.tarbiyahForm, arguments: TarbiyahFormArgs(student: s, settings: cfg, existing: tar.data ?? const [])),
                ),
              ),
            ..._section<List<TarbiyahAssessment>>(
              tar,
              emptyKey: 'student_no_tarbiyah',
              emptyText: c.canLog ? 'No ${cfg.programName} assessment on record yet.' : 'No ${cfg.programName} assessment on record.',
              retry: c.load,
              builder: (list) => [
                for (final a in list)
                  TarbiyahCard(
                    a: a,
                    settings: cfg,
                    onEdit: c.canEditTarbiyah(a) ? () => Get.toNamed(Routes.tarbiyahForm, arguments: TarbiyahFormArgs(student: s, settings: cfg, existing: list, editing: a)) : null,
                  ),
              ],
            ),
          ],
        );
      }),
    );
  }

  List<Widget> _section<T>(SectionState<T> s, {required String emptyKey, required String emptyText, required VoidCallback retry, required List<Widget> Function(T) builder}) {
    switch (s.status) {
      case SectionStatus.loading:
        return [const Padding(padding: EdgeInsets.symmetric(vertical: EmSpacing.block), child: AppLoader())];
      case SectionStatus.data:
        return builder(s.data as T);
      case SectionStatus.empty:
        return [AppCard(child: Text(emptyText, key: Key(emptyKey), style: _quiet))];
      case SectionStatus.forbidden:
        return [AppCard(child: Text("You don't have access to this.", key: const Key('section_forbidden'), style: _quiet))];
      case SectionStatus.unavailable:
        return [AppCard(child: Text('Not available on this server yet.', key: const Key('section_unavailable'), style: _quiet))];
      case SectionStatus.error:
        return [AppErrorView(message: s.message ?? 'Something went wrong', onRetry: retry)];
    }
  }
}
