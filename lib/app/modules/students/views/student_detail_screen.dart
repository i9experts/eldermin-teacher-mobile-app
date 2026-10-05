import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/classroom/attendance_models.dart';
import '../../../../core/models/classroom/student_360.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/timetable_week.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/custom_text.dart';
import '../../../routes/app_routes.dart';
import '../../home/models/section_state.dart';
import '../../attendance/views/widgets/attendance_widgets.dart';
import '../controllers/student_detail_controller.dart';
import 'widgets/student_widgets.dart';

/// Student 360 (`/students/:id`), READ-ONLY. Built from a whitelist of teacher-relevant sections:
/// profile basics, allergy flag, attendance, recent behaviour, recent results, guardian names.
/// Fees, finance and guardian/student contact data are never parsed or shown (see Student360).
class StudentDetailScreen extends StatefulWidget {
  /// Optional explicit id (tests); the app passes it through the route parameter `:id`.
  final String? studentId;
  const StudentDetailScreen({super.key, this.studentId});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  late final String id = widget.studentId ?? Get.parameters['id'] ?? '';
  late final StudentDetailController controller;
  bool _owned = false;

  @override
  void initState() {
    super.initState();
    // One controller PER opened student (tagged by id), created here and removed on dispose, so opening
    // student B never shows student A's cached data. A pre-registered one (tests) is reused.
    if (Get.isRegistered<StudentDetailController>(tag: id)) {
      controller = Get.find<StudentDetailController>(tag: id);
    } else {
      controller = Get.put(StudentDetailController(id), tag: id);
      _owned = true;
    }
  }

  @override
  void dispose() {
    if (_owned && Get.isRegistered<StudentDetailController>(tag: id)) Get.delete<StudentDetailController>(tag: id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const CustomText(text: 'Student 360', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
      body: Obx(_body),
    );
  }

  Widget _body() {
    final c = controller;
    if (c.outOfScope.value) {
      return const AppEmptyView(
        key: Key('student_out_of_scope'),
        icon: Icons.lock_outline_rounded,
        title: "This student isn't in one of your classes",
        subtitle: 'You can only open students of the classes you teach.',
      );
    }
    final month = c.month.value;
    return ScreenStateView<Student360>(
      state: c.detail.value,
      onRefresh: c.reload,
      onRetry: c.load,
      emptyIcon: Icons.person_off_outlined,
      emptyTitle: 'Student not found',
      skeletonRows: 4,
      builder: (d) => [
        _ProfileCard(d: d),
        if (d.allergies.isNotEmpty) _AllergyCard(allergies: d.allergies),
        const SubHeading('Attendance'),
        _AttendanceCard(d: d.attendance, month: month, monthLabel: _monthLabel(c.monthStart)),
        const SubHeading('Recent behaviour'),
        _BehaviourCard(b: d.behaviour, studentId: d.student.id),
        const SubHeading('Recent results'),
        _ResultsCard(results: d.results),
        const SubHeading('Guardians'),
        _GuardiansCard(guardians: d.guardians),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: CustomText(
            key: Key('student_privacy_note'),
            text: 'Read-only. Fees, finance and contact details are not shown in this app.',
            color: AppColors.faint,
            fontSize: 10.5,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
String _monthLabel(DateTime d) => '${_months[d.month - 1]} ${d.year}';

String _date(DateTime? d) => d == null ? '' : '${dayMonthShort(d.toUtc())} ${d.toUtc().year}';

class _ProfileCard extends StatelessWidget {
  final Student360 d;
  const _ProfileCard({required this.d});

  @override
  Widget build(BuildContext context) {
    final s = d.student;
    final lines = [
      if (s.classLabel.isNotEmpty) s.classLabel,
      if ((s.rollNumber ?? '').isNotEmpty) 'Roll ${s.rollNumber}',
    ].join(' · ');
    return AppCard(
      key: const Key('student_profile'),
      child: Row(children: [
        StudentAvatar(student: s, size: 56),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CustomText(text: s.fullName, fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primaryColor, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (lines.isNotEmpty) CustomText(text: lines, color: AppColors.muted, fontSize: 12),
            CustomText(
              text: [if (s.studentId.isNotEmpty) s.studentId, if ((s.grNo ?? '').isNotEmpty) s.grNo!].join(' · '),
              color: AppColors.faint,
              fontSize: 10.5,
            ),
            if (!s.isActive) ...[const SizedBox(height: 6), AppTag(s.status.replaceAll('_', ' '), style: TagStyle.amber)],
          ]),
        ),
      ]),
    );
  }
}

class _AllergyCard extends StatelessWidget {
  final List<String> allergies;
  const _AllergyCard({required this.allergies});

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('student_allergies'),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.amberBg, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.amber)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.amberText, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CustomText(text: 'Allergies', color: AppColors.amberText, fontWeight: FontWeight.w800, fontSize: 12),
              CustomText(text: allergies.join(', '), color: AppColors.ink, fontSize: 13),
            ]),
          ),
        ]),
      );
}

class _AttendanceCard extends StatelessWidget {
  final Attendance360 d;
  final SectionState<StatusCounts> month;
  final String monthLabel;
  const _AttendanceCard({required this.d, required this.month, required this.monthLabel});

  @override
  Widget build(BuildContext context) {
    if (d.totalDays == 0) {
      return const AppCard(key: Key('student_attendance'), child: CustomText(text: 'No attendance has been recorded this academic year.', color: AppColors.muted, fontSize: 12));
    }
    final recent = d.recent.reversed.toList(); // oldest -> newest
    return AppCard(
      key: const Key('student_attendance'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          DonutRing(percent: d.percentage.round().clamp(0, 100), color: d.percentage >= 90 ? AppColors.green : d.percentage >= 75 ? AppColors.amber : AppColors.red, size: 76),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CustomText(key: const Key('attendance_percentage'), text: '${_pct(d.percentage)}% attendance', fontWeight: FontWeight.w800, color: AppColors.primaryColor, fontSize: 15),
              CustomText(text: '${d.presentDays} of ${d.totalDays} days present or late this academic year', color: AppColors.muted, fontSize: 11),
              const SizedBox(height: 8),
              StatusCountPills(counts: d.counts),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        CustomText(text: 'This month · $monthLabel', color: AppColors.primaryColor, fontWeight: FontWeight.w800, fontSize: 11),
        const SizedBox(height: 6),
        _monthRow(),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 12),
          CustomText(text: 'Last ${recent.length} recorded days', color: AppColors.primaryColor, fontWeight: FontWeight.w800, fontSize: 11),
          const SizedBox(height: 6),
          Wrap(key: const Key('attendance_recent'), spacing: 3, runSpacing: 3, children: [
            for (final r in recent)
              Tooltip(
                message: '${r.dayKey} · ${r.status?.label ?? 'Other'}',
                child: Container(width: 14, height: 14, decoration: BoxDecoration(color: r.status == null ? AppColors.line : statusColors(r.status!).fg, borderRadius: BorderRadius.circular(4))),
              ),
          ]),
        ],
      ]),
    );
  }

  Widget _monthRow() {
    switch (month.status) {
      case SectionStatus.loading:
        return const CustomText(text: 'Loading…', color: AppColors.faint, fontSize: 11);
      case SectionStatus.data:
        final c = month.data!;
        return c.total == 0 ? const CustomText(key: Key('month_none'), text: 'Nothing recorded this month.', color: AppColors.muted, fontSize: 11) : StatusCountPills(key: const Key('month_counts'), counts: c);
      case SectionStatus.forbidden:
        return const CustomText(text: "You don't have access", color: AppColors.muted, fontSize: 11);
      default:
        return const CustomText(key: Key('month_error'), text: "Couldn't load this month.", color: AppColors.red, fontSize: 11);
    }
  }

  String _pct(double p) => p == p.roundToDouble() ? p.round().toString() : p.toStringAsFixed(1);
}

class _BehaviourCard extends StatelessWidget {
  final Behaviour360 b;
  final String studentId;
  const _BehaviourCard({required this.b, required this.studentId});

  @override
  Widget build(BuildContext context) {
    // The 360 reads the student-profile behaviour log (collection student_behaviour, students.service.ts:1517-1531), which is a
    // DIFFERENT store from the Behaviour & Tarbiyah records the parent app and this app's "Behaviour" module use
    // (collection behaviour_records). The link below opens the latter.
    final canOpen = Get.isRegistered<PermissionService>() && Get.find<PermissionService>().canAccess('behaviour:view');
    final link = canOpen
        ? Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('student_behaviour_history'),
              onPressed: () => Get.toNamed(Routes.behaviourStudentOf(studentId)),
              icon: const Icon(Icons.history_rounded, size: 18),
              label: const CustomText(text: 'Behaviour history and Tarbiyah', color: AppColors.primaryColor, fontWeight: FontWeight.w800, fontSize: 12),
            ),
          )
        : const SizedBox.shrink();
    if (b.recent.isEmpty) {
      return AppCard(
        key: const Key('student_behaviour'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const CustomText(text: 'No behaviour records on the student profile.', color: AppColors.muted, fontSize: 12),
          link,
        ]),
      );
    }
    return AppCard(
      key: const Key('student_behaviour'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CustomText(text: 'Behaviour points this year: ${b.totalPoints}', color: AppColors.primaryColor, fontWeight: FontWeight.w800, fontSize: 12),
        const SizedBox(height: 8),
        for (final i in b.recent)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(i.type == 'positive' ? Icons.thumb_up_alt_outlined : i.type == 'negative' ? Icons.flag_outlined : Icons.chat_bubble_outline_rounded,
                  size: 18, color: i.type == 'positive' ? AppColors.green : i.type == 'negative' ? AppColors.red : AppColors.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CustomText(text: '${i.categoryLabel} · ${_date(i.date)}', color: AppColors.primaryColor, fontWeight: FontWeight.w700, fontSize: 12),
                  if (i.description.isNotEmpty) CustomText(text: i.description, color: AppColors.muted, fontSize: 11.5),
                ]),
              ),
              if (i.type == 'negative' && !i.resolved) const AppTag('Open', style: TagStyle.amber),
            ]),
          ),
        link,
      ]),
    );
  }
}

class _ResultsCard extends StatelessWidget {
  final List<ResultItem> results;
  const _ResultsCard({required this.results});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const AppCard(key: Key('student_results'), child: CustomText(text: 'No recent results.', color: AppColors.muted, fontSize: 12));
    }
    return AppCard(
      key: const Key('student_results'),
      child: Column(children: [
        for (final r in results)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CustomText(text: r.title, color: AppColors.primaryColor, fontWeight: FontWeight.w700, fontSize: 12.5),
                  CustomText(text: [if (r.type.isNotEmpty) r.type, if (r.date != null) _date(r.date)].join(' · '), color: AppColors.faint, fontSize: 10.5),
                ]),
              ),
              if (r.percentage != null) CustomText(text: '${r.percentage!.round()}%${r.overallGrade != null ? ' · ${r.overallGrade}' : ''}', color: AppColors.primaryColor, fontWeight: FontWeight.w800, fontSize: 12.5),
            ]),
          ),
      ]),
    );
  }
}

class _GuardiansCard extends StatelessWidget {
  final List<GuardianInfo> guardians;
  const _GuardiansCard({required this.guardians});

  @override
  Widget build(BuildContext context) {
    if (guardians.isEmpty) {
      return const AppCard(key: Key('student_guardians'), child: CustomText(text: 'No guardians on record.', color: AppColors.muted, fontSize: 12));
    }
    return AppCard(
      key: const Key('student_guardians'),
      child: Column(children: [
        for (final g in guardians)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              const Icon(Icons.person_outline_rounded, size: 18, color: AppColors.blue),
              const SizedBox(width: 10),
              Expanded(child: CustomText(text: g.name, color: AppColors.primaryColor, fontWeight: FontWeight.w700, fontSize: 12.5)),
              if (g.relationLabel.isNotEmpty) AppTag(g.relationLabel, style: TagStyle.neutral),
              if (g.isPrimary) ...[const SizedBox(width: 6), const AppTag('Primary', style: TagStyle.info)],
            ]),
          ),
      ]),
    );
  }
}
