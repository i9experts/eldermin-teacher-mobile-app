import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/behaviour/behaviour_models.dart';
import '../../../../core/models/classroom/student_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/custom_text.dart';
import '../../../routes/app_routes.dart';
import '../../home/models/section_state.dart';
import '../controllers/behaviour_student_controller.dart';
import 'widgets/behaviour_widgets.dart';

/// One student's behaviour and Tarbiyah history (`/behaviour/student/:id`). Only for students in MY classes.
class BehaviourStudentScreen extends GetView<BehaviourStudentController> {
  const BehaviourStudentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Scaffold(
      appBar: AppBar(title: const CustomText(text: 'Student behaviour', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
      floatingActionButton: Obx(() {
        final s = c.student.value.data;
        return s != null && c.canLog
            ? FloatingActionButton.extended(
                key: const Key('beh_student_log'),
                backgroundColor: AppColors.primaryColor,
                onPressed: () async {
                  await Get.toNamed(Routes.behaviourNew, arguments: s);
                  c.load();
                },
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: const CustomText(text: 'Log behaviour', color: Colors.white, fontWeight: FontWeight.w700),
              )
            : const SizedBox.shrink();
      }),
      body: Obx(() {
        final st = c.student.value;
        // reactive reads here, not in the builder
        final recs = c.records.value;
        final tar = c.tarbiyah.value;
        final pts = c.totalPoints;
        final myId = c.myId, myName = c.myName;
        return ScreenStateView<StudentSummary>(
          state: st,
          onRefresh: c.reload,
          onRetry: c.load,
          emptyIcon: Icons.lock_outline_rounded,
          emptyTitle: "This student isn't in one of your classes",
          emptySubtitle: 'You can only see behaviour for the students you teach.',
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          builder: (s) => [
            ScreenHeader(title: s.fullName, caption: [if (s.grade.isNotEmpty) '${s.grade}${s.section.isEmpty ? '' : ' - ${s.section}'}', if ((s.rollNumber ?? '').isNotEmpty) 'Roll ${s.rollNumber}'].join(' · ')),
            if (recs.hasData) StatsRow(items: [('${recs.data!.length}', 'Records', null), (pointsText(pts), 'Points', null)]),
            if (recs.hasData) const SizedBox(height: 10),
            const SubHeading('Behaviour records'),
            ..._section<List<BehaviourRecord>>(
              recs,
              emptyKey: 'student_no_records',
              emptyText: 'No behaviour recorded for this student yet.',
              retry: c.load,
              builder: (list) => [for (final r in list) BehaviourTile(record: r, mine: r.isMine(userId: myId, userName: myName), showStudent: false)],
            ),
            const SubHeading('Tarbiyah assessments'),
            ..._section<List<TarbiyahAssessment>>(
              tar,
              emptyKey: 'student_no_tarbiyah',
              emptyText: 'No Tarbiyah assessment on record. (Assessments are created by the school on the web.)',
              retry: c.load,
              builder: (list) => [for (final a in list) TarbiyahCard(a: a)],
            ),
          ],
        );
      }),
    );
  }

  List<Widget> _section<T>(SectionState<T> s, {required String emptyKey, required String emptyText, required VoidCallback retry, required List<Widget> Function(T) builder}) {
    switch (s.status) {
      case SectionStatus.loading:
        return [const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: AppLoader())];
      case SectionStatus.data:
        return builder(s.data as T);
      case SectionStatus.empty:
        return [AppCard(child: CustomText(key: Key(emptyKey), text: emptyText, color: AppColors.muted, fontSize: 12))];
      case SectionStatus.forbidden:
        return [const AppCard(child: CustomText(key: Key('section_forbidden'), text: "You don't have access to this.", color: AppColors.muted, fontSize: 12))];
      case SectionStatus.unavailable:
        return [const AppCard(child: CustomText(key: Key('section_unavailable'), text: 'Not available on this server yet.', color: AppColors.muted, fontSize: 12))];
      case SectionStatus.error:
        return [AppErrorView(message: s.message ?? 'Something went wrong', onRetry: retry)];
    }
  }
}
