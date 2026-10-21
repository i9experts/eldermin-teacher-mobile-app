import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/design/design.dart';
import '../../../../core/utils/home_time.dart';
import '../../../components/custom_refresh_wrapper.dart';
import '../../../routes/app_routes.dart';
import '../controllers/home_dashboard_controller.dart';
import '../controllers/home_shell_controller.dart';
import 'widgets/home_sections.dart';
import 'widgets/section_view.dart';

/// Home tab: today's date and independent dashboard sections (the greeting header
/// and the bell live in the shell; quick actions are the shell's centre FAB).
/// Pull-to-refresh re-fetches `/staff-portal/me` and then every section.
class HomeDashboardScreen extends GetView<HomeDashboardController> {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return CustomRefreshWrapper(
      onRefresh: c.refreshAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(EmSpacing.screenH, EmSpacing.s8, EmSpacing.screenH, EmSpacing.s24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _TodayHeading(c),
          Obx(() => c.showClassCard
              ? SectionView(
                  title: 'My class',
                  state: c.classCard.value,
                  onRetry: c.loadClassCard,
                  emptyTitle: 'No class data',
                  skeletonRows: 1,
                  builder: (s) => ClassTeacherCard(snap: s, onMarkAttendance: () => Get.toNamed(Routes.attendanceMark)),
                )
              : const SizedBox.shrink()),
          Obx(() => c.showTimetable
              ? SectionView(
                  title: "Today's classes",
                  state: c.timetable.value,
                  onRetry: c.loadTimetable,
                  onSeeAll: () => Get.toNamed(Routes.timetable),
                  builder: (_) => TimetableStrip(periods: c.todayTimetable),
                )
              : const SizedBox.shrink()),
          Obx(() => c.showSubstitutions
              ? SectionView(
                  title: "Today's substitutions",
                  state: c.substitutions.value,
                  onRetry: c.loadSubstitutions,
                  onSeeAll: () => Get.toNamed(Routes.fixtures),
                  emptyIcon: Icons.swap_horiz_rounded,
                  emptyTitle: 'No substitutions today',
                  builder: (d) => SubstitutionsCard(data: d, onOpen: (_) => Get.toNamed(Routes.fixtures)),
                )
              : const SizedBox.shrink()),
          Obx(() => c.showHomework
              ? SectionView(
                  title: 'Homework to grade',
                  state: c.homework.value,
                  onRetry: c.loadHomework,
                  onSeeAll: () => Get.toNamed(Routes.homework),
                  emptyIcon: Icons.task_alt_rounded,
                  emptyTitle: 'Nothing to grade',
                  emptySubtitle: 'No submissions are waiting.',
                  builder: (d) => HomeworkCard(data: d, onOpen: (a) => Get.toNamed(Routes.homeworkSubmissionsOf(a.assignmentId))),
                )
              : const SizedBox.shrink()),
          Obx(() => c.showLessonPlans
              ? SectionView(
                  title: 'Lesson plans',
                  state: c.lessonPlans.value,
                  onRetry: c.loadLessonPlans,
                  onSeeAll: () => Get.toNamed(Routes.lessonPlans),
                  emptyIcon: Icons.edit_note_rounded,
                  emptyTitle: 'All caught up',
                  emptySubtitle: 'No plans awaiting approval or rejected.',
                  builder: (d) => LessonPlansCard(data: d, onOpen: (p) => Get.toNamed(Routes.lessonPlanDetailOf(p.id)), onOpenFilter: (s) => Get.toNamed(Routes.lessonPlans, arguments: s)),
                )
              : const SizedBox.shrink()),
          Obx(() => c.showPtms
              ? SectionView(
                  title: 'Parent meetings',
                  state: c.ptms.value,
                  onRetry: c.loadPtms,
                  onSeeAll: () => Get.toNamed(Routes.ptm),
                  emptyIcon: Icons.handshake_outlined,
                  emptyTitle: 'No meetings today or coming up',
                  builder: (_) => PtmList(agenda: c.ptmAgenda, onOpen: (m) => Get.toNamed(Routes.ptmDetailOf(m.id))),
                )
              : const SizedBox.shrink()),
          Obx(() => SectionView(
                title: 'Messages',
                state: c.messages.value,
                onRetry: () => c.badges.refreshThreads(userInitiated: true),
                hideWhenUnavailable: true,
                hideWhenForbidden: false,
                emptyIcon: Icons.mark_email_read_outlined,
                emptyTitle: "You're all caught up",
                emptySubtitle: 'No unread messages.',
                builder: (d) => d.unreadCount == 0
                    ? const _CaughtUp()
                    : MessagesSummary(data: d, onOpen: () => Get.find<HomeShellController>().changeTab(HomeShellController.messagesTab)),
              )),
        ]),
      ),
    );
  }
}

class _CaughtUp extends StatelessWidget {
  const _CaughtUp();
  @override
  Widget build(BuildContext context) => EmCard(
        key: const Key('messages_caught_up'),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: EmColors.successContainer, shape: BoxShape.circle),
            child: const ExcludeSemantics(child: Icon(Icons.mark_email_read_outlined, color: EmColors.onSuccessContainer, size: 22)),
          ),
          const SizedBox(width: EmSpacing.s12),
          Expanded(
            child: Text("You're all caught up - no unread messages", maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.bodyLarge.copyWith(color: EmColors.ink)),
          ),
        ]),
      );
}

/// Today's date (the greeting itself is in the shell header).
class _TodayHeading extends StatelessWidget {
  final HomeDashboardController c;
  const _TodayHeading(this.c);

  @override
  Widget build(BuildContext context) {
    return Obx(() => Padding(
          padding: const EdgeInsetsDirectional.only(bottom: EmSpacing.s4),
          child: Text(longDateOf(c.now.value),
              key: const Key('greeting_date'), style: EmType.body.copyWith(color: EmColors.textSecondary)),
        ));
  }
}
