import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/classroom/attendance_models.dart';
import '../../../../core/models/classroom/student_360.dart';
import '../../../../core/services/permission_service.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../behaviour/views/behaviour_detail_sheet.dart';
import '../../../../core/utils/timetable_week.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../routes/app_routes.dart';
import '../../home/models/section_state.dart';
import '../../attendance/views/widgets/attendance_widgets.dart';
import '../controllers/student_detail_controller.dart';
import 'widgets/student_widgets.dart';
import '../../../../core/design/design.dart';

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
    return EmScaffold(
      appBar: EmAppBar(title: 'Student 360'),
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
        if (d.allergies.isNotEmpty || d.bloodGroup.isNotEmpty) _MedicalAlertCard(allergies: d.allergies, bloodGroup: d.bloodGroup),
        const SectionRow(title: 'Attendance'),
        _AttendanceCard(d: d.attendance, month: month, monthLabel: _monthLabel(c.monthStart)),
        const SectionRow(title: 'Recent behaviour'),
        _BehaviourCard(b: d.behaviour, studentId: d.student.id, studentName: d.student.fullName),
        const SectionRow(title: 'Recent results'),
        _ResultsCard(state: c.results.value),
        if (d.guardiansKnown) ...[
          const SectionRow(title: 'Guardians'),
          _GuardiansCard(guardians: d.guardians),
        ],
        const SizedBox(height: EmSpacing.s8),
        // Guardian contact details are never shown to teachers; messages go through the app only.
        EmSecondaryButton(
          key: const Key('student_message_guardian'),
          expand: true,
          icon: Icons.chat_bubble_outline_rounded,
          label: 'Message guardian',
          onPressed: () => Get.toNamed(Routes.messageNew, arguments: d.student),
        ),
        Padding(
          padding: const EdgeInsets.only(top: EmSpacing.row),
          child: Text(
            'Read-only. Fees, finance and contact details are not shown in this app.',
            key: const Key('student_privacy_note'),
            textAlign: TextAlign.center,
            style: EmType.caption.copyWith(color: EmColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
String _monthLabel(DateTime d) => '${_months[d.month - 1]} ${d.year}';

String _date(DateTime? d) => d == null ? '' : '${dayMonthShort(d.toUtc())} ${d.toUtc().year}';

/// A card of this screen: the shared card with the 12dp gap below it.
class _Section extends StatelessWidget {
  final Key? cardKey;
  final Widget child;
  const _Section({this.cardKey, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: EmSpacing.row),
        child: EmCard(key: cardKey, child: child),
      );
}

class _Quiet extends StatelessWidget {
  final String text;
  final Key? textKey;
  final Color? color;
  const _Quiet(this.text, {this.textKey, this.color});

  @override
  Widget build(BuildContext context) => Text(text, key: textKey, style: EmType.body.copyWith(color: color ?? EmColors.textSecondary, fontWeight: FontWeight.w400));
}

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
    final ids = [if (s.studentId.isNotEmpty) s.studentId, if ((s.grNo ?? '').isNotEmpty) s.grNo!].join(' · ');
    return _Section(
      cardKey: const Key('student_profile'),
      child: Row(children: [
        StudentAvatar(student: s, size: 64),
        const SizedBox(width: EmSpacing.s16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.fullName, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.heading.copyWith(color: EmColors.ink)),
            if (lines.isNotEmpty) Text(lines, style: EmType.body.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400)),
            if (ids.isNotEmpty) Text(ids, style: EmType.caption.copyWith(color: EmColors.textSecondary)),
            if (!s.isActive) ...[const SizedBox(height: EmSpacing.s8), AppTag(s.status.replaceAll('_', ' '), style: EmTone.warning)],
          ]),
        ),
      ]),
    );
  }
}

/// Critical medical alerts the backend sends to teachers: allergies, and the blood group when the payload carries it (never invented).
class _MedicalAlertCard extends StatelessWidget {
  final List<String> allergies;
  final String bloodGroup;
  const _MedicalAlertCard({required this.allergies, required this.bloodGroup});

  @override
  Widget build(BuildContext context) {
    final label = EmType.label.copyWith(color: EmColors.onWarningContainer);
    final value = EmType.body.copyWith(color: EmColors.ink);
    return Padding(
      padding: const EdgeInsets.only(bottom: EmSpacing.row),
      child: EmCard(
        key: const Key('student_medical_alert'),
        color: EmColors.warningContainer,
        padding: EmSpacing.cardPad,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const ExcludeSemantics(child: Icon(Icons.warning_amber_rounded, color: EmColors.onWarningContainer, size: 24)),
          const SizedBox(width: EmSpacing.row),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (allergies.isNotEmpty) ...[
                Text('Allergies', style: label),
                Text(allergies.join(', '), key: const Key('student_allergies'), style: value),
              ],
              if (bloodGroup.isNotEmpty) ...[
                if (allergies.isNotEmpty) const SizedBox(height: EmSpacing.s8),
                Text('Blood group', style: label),
                Text(bloodGroup, key: const Key('student_blood_group'), style: value),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  final Attendance360 d;
  final SectionState<StatusCounts> month;
  final String monthLabel;
  const _AttendanceCard({required this.d, required this.month, required this.monthLabel});

  @override
  Widget build(BuildContext context) {
    if (d.totalDays == 0) {
      return const _Section(cardKey: Key('student_attendance'), child: _Quiet('No attendance has been recorded this academic year.'));
    }
    final recent = d.recent.reversed.toList(); // oldest -> newest
    final pct = d.percentage.round().clamp(0, 100);
    final ringColor = d.percentage >= 90 ? EmColors.success : (d.percentage >= 75 ? EmColors.warning : EmColors.error);
    return _Section(
      cardKey: const Key('student_attendance'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          EmProgressRing(value: pct / 100, size: 84, strokeWidth: 9, knob: false, color: ringColor, centerText: '$pct%', semanticLabel: 'Attendance $pct percent'),
          const SizedBox(width: EmSpacing.s16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_pct(d.percentage)}% attendance', key: const Key('attendance_percentage'), style: EmType.bodyLarge.copyWith(color: EmColors.ink, fontWeight: FontWeight.w600)),
              Text('${d.presentDays} of ${d.totalDays} days present or late this academic year', style: EmType.caption.copyWith(color: EmColors.textSecondary)),
              const SizedBox(height: EmSpacing.s8),
              StatusCountPills(counts: d.counts),
            ]),
          ),
        ]),
        const SizedBox(height: EmSpacing.s16),
        Text('This month · $monthLabel', style: EmType.label.copyWith(color: EmColors.ink)),
        const SizedBox(height: EmSpacing.s8),
        _monthRow(),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: EmSpacing.s16),
          Text('Last ${recent.length} recorded days', style: EmType.label.copyWith(color: EmColors.ink)),
          const SizedBox(height: EmSpacing.s8),
          // each square carries the status glyph as well as its colour
          Wrap(key: const Key('attendance_recent'), spacing: EmSpacing.s4, runSpacing: EmSpacing.s4, children: [
            for (final r in recent)
              Tooltip(
                message: '${r.dayKey} · ${r.status?.label ?? 'Other'}',
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(color: r.status == null ? EmColors.border : statusColors(r.status!).fg, shape: BoxShape.circle),
                  child: Icon(r.status == null ? Icons.remove_rounded : statusIcon(r.status!), size: 14, color: EmColors.surface),
                ),
              ),
          ]),
        ],
      ]),
    );
  }

  Widget _monthRow() {
    switch (month.status) {
      case SectionStatus.loading:
        return const _Quiet('Loading…');
      case SectionStatus.data:
        final c = month.data!;
        return c.total == 0 ? const _Quiet('Nothing recorded this month.', textKey: Key('month_none')) : StatusCountPills(key: const Key('month_counts'), counts: c);
      case SectionStatus.forbidden:
        return const _Quiet("You don't have access");
      default:
        return const _Quiet("Couldn't load this month.", textKey: Key('month_error'), color: EmColors.error);
    }
  }

  String _pct(double p) => p == p.roundToDouble() ? p.round().toString() : p.toStringAsFixed(1);
}

class _BehaviourCard extends StatelessWidget {
  final Behaviour360 b;
  final String studentId;
  final String studentName;
  const _BehaviourCard({required this.b, required this.studentId, this.studentName = ''});

  /// Tap a row: the full record (or, for a legacy row, what the 360 has). Edit / resolve only where the Behaviour module allows them.
  void _open(BuildContext context, BehaviourItem item) {
    final auth = Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null;
    final perms = Get.isRegistered<PermissionService>() ? Get.find<PermissionService>() : null;
    final canLog = perms?.canAccess('behaviour:manage') ?? false;
    showBehaviourItemSheet(
      context,
      item,
      studentId: studentId,
      studentName: studentName,
      myId: auth?.user.value?.id ?? '',
      myName: auth?.user.value?.name ?? '',
      actions: BehaviourSheetActions(
        onEdit: canLog ? (rec) => Get.toNamed(Routes.behaviourNew, arguments: rec) : null,
        onResolved: canLog ? (_) {} : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The 360 reads the student-profile behaviour log (collection student_behaviour, students.service.ts:1517-1531), which is a
    // DIFFERENT store from the Behaviour & Tarbiyah records the parent app and this app's "Behaviour" module use
    // (collection behaviour_records). The link below opens the latter.
    final canOpen = Get.isRegistered<PermissionService>() && Get.find<PermissionService>().canAccess('behaviour:view');
    final link = canOpen
        ? Align(
            alignment: AlignmentDirectional.centerStart,
            child: EmTextAction(
              key: const Key('student_behaviour_history'),
              onPressed: () => Get.toNamed(Routes.behaviourStudentOf(studentId)),
              icon: Icons.history_rounded,
              label: 'Behaviour history and Tarbiyah',
            ),
          )
        : const SizedBox.shrink();
    if (b.recent.isEmpty) {
      return _Section(
        cardKey: const Key('student_behaviour'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const _Quiet('No behaviour records on the student profile.'), link]),
      );
    }
    return _Section(
      cardKey: const Key('student_behaviour'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Behaviour points this year: ${b.totalPoints}', style: EmType.label.copyWith(color: EmColors.ink)),
        const SizedBox(height: EmSpacing.s12),
        for (final i in b.recent)
          InkWell(
            key: ValueKey('b360_${i.id.isEmpty ? i.hashCode : i.id}'),
            onTap: () => _open(context, i),
            child: Padding(
            padding: const EdgeInsets.only(bottom: EmSpacing.s12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ExcludeSemantics(
                child: Icon(
                  i.type == 'positive' ? Icons.thumb_up_alt_outlined : (i.type == 'negative' ? Icons.flag_outlined : Icons.chat_bubble_outline_rounded),
                  size: 20,
                  color: i.type == 'positive' ? EmColors.success : (i.type == 'negative' ? EmColors.error : EmColors.textSecondary),
                ),
              ),
              const SizedBox(width: EmSpacing.row),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${i.title.isEmpty ? i.categoryLabel : i.title} · ${_date(i.date)}', style: EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w600)),
                  if (i.description.isNotEmpty) Text(i.description, style: EmType.caption.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400)),
                ]),
              ),
              if (i.type == 'negative' && !i.resolved) ...[const SizedBox(width: EmSpacing.s8), const AppTag('Open', style: EmTone.warning)],
            ]),
          ),
          ),
        link,
      ]),
    );
  }
}

class _ResultsCard extends StatelessWidget {
  final SectionState<List<ResultItem>> state;
  const _ResultsCard({required this.state});

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case SectionStatus.loading:
        return const _Section(cardKey: Key('student_results'), child: _Quiet('Loading…'));
      case SectionStatus.forbidden:
        return const _Section(cardKey: Key('student_results'), child: _Quiet("You don't have access to results."));
      case SectionStatus.error:
      case SectionStatus.unavailable:
        if (state.data == null) {
          return const _Section(
              cardKey: Key('student_results'), child: _Quiet("Couldn't load results.", textKey: Key('results_error'), color: EmColors.error));
        }
      case SectionStatus.data:
      case SectionStatus.empty:
    }
    final results = state.data ?? const <ResultItem>[];
    if (results.isEmpty) return const _Section(cardKey: Key('student_results'), child: _Quiet('No recent results.'));
    return _Section(
      cardKey: const Key('student_results'),
      child: Column(children: [
        for (final r in results)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: EmSpacing.s8),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.title, style: EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w600)),
                  Text([if (r.type.isNotEmpty) r.type, if (r.date != null) _date(r.date)].join(' · '), style: EmType.caption.copyWith(color: EmColors.textSecondary)),
                ]),
              ),
              if (r.percentage != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: EmSpacing.s8),
                  child: Text('${r.percentage!.round()}%${r.overallGrade != null ? ' · ${r.overallGrade}' : ''}', style: EmType.valueSmall.copyWith(color: EmColors.ink)),
                ),
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
    if (guardians.isEmpty) return const _Section(cardKey: Key('student_guardians'), child: _Quiet('No guardians on record.'));
    return _Section(
      cardKey: const Key('student_guardians'),
      child: Column(children: [
        for (final g in guardians)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: EmSpacing.s8),
            child: Row(children: [
              const ExcludeSemantics(child: Icon(Icons.person_outline_rounded, size: 20, color: EmColors.primary)),
              const SizedBox(width: EmSpacing.row),
              Expanded(child: Text(g.name, style: EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w600))),
              if (g.relationLabel.isNotEmpty) AppTag(g.relationLabel, style: EmTone.neutral),
              if (g.isPrimary) ...[const SizedBox(width: EmSpacing.s8), const AppTag('Primary', style: EmTone.info)],
            ]),
          ),
      ]),
    );
  }
}
