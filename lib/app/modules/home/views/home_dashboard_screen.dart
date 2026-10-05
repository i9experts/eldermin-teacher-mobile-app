import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/home_time.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../components/custom_refresh_wrapper.dart';
import '../../../components/custom_text.dart';
import '../../../routes/app_routes.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/home_dashboard_controller.dart';
import '../controllers/home_shell_controller.dart';
import 'widgets/home_sections.dart';
import 'widgets/section_view.dart';

/// Home tab: greeting, quick actions and independent dashboard sections.
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _Greeting(c),
          Obx(() {
            final actions = c.quickActions;
            if (actions.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final a in actions)
                  ActionChip(
                    key: Key('quick_${a.label}'),
                    avatar: Icon(a.icon, size: 16, color: AppColors.blue),
                    label: CustomText(text: a.label, fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryColor),
                    backgroundColor: AppColors.surface,
                    side: const BorderSide(color: AppColors.line),
                    onPressed: () => Get.toNamed(a.route),
                  ),
              ]),
            );
          }),
          Obx(() => c.showClassCard
              ? SectionView(
                  title: 'My class',
                  state: c.classCard.value,
                  onRetry: c.loadClassCard,
                  emptyTitle: 'No class data',
                  skeletonRows: 1,
                  builder: (s) => ClassTeacherCard(snap: s, onMarkAttendance: () => Get.toNamed(Routes.attendance)),
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
                  builder: (d) => HomeworkCard(data: d, onOpen: (a) => Get.toNamed(Routes.homeworkSubmissionsOf(a.id))),
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
                  builder: (d) => LessonPlansCard(data: d, onOpen: (p) => Get.toNamed(Routes.lessonPlanDetailOf(p.id))),
                )
              : const SizedBox.shrink()),
          Obx(() => c.showPtms
              ? SectionView(
                  title: 'Upcoming parent meetings',
                  state: c.ptms.value,
                  onRetry: c.loadPtms,
                  onSeeAll: () => Get.toNamed(Routes.ptm),
                  emptyIcon: Icons.handshake_outlined,
                  emptyTitle: 'No upcoming meetings',
                  builder: (d) => PtmList(meetings: d, onOpen: (m) => Get.toNamed(Routes.ptmDetailOf(m.id))),
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
  Widget build(BuildContext context) => const AppCard(
        key: Key('messages_caught_up'),
        child: Row(children: [
          Icon(Icons.mark_email_read_outlined, color: AppColors.faint, size: 22),
          SizedBox(width: 12),
          CustomText(text: "You're all caught up - no unread messages", color: AppColors.primaryColor, fontWeight: FontWeight.w700, fontSize: 12),
        ]),
      );
}

class _Greeting extends StatelessWidget {
  final HomeDashboardController c;
  const _Greeting(this.c);

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return Obx(() {
      final now = c.now.value;
      final name = (auth.user.value?.name ?? '').trim();
      final first = name.isEmpty ? '' : ', ${name.split(RegExp(r'\s+')).first}';
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CustomText(text: '${greetingFor(now)}$first', key: const Key('greeting'), fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primaryColor),
          CustomText(text: longDateOf(now), key: const Key('greeting_date'), fontSize: 12, color: AppColors.muted),
        ]),
      );
    });
  }
}
