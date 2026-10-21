import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/assessments/reference_models.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../controllers/curriculum_controller.dart';
import '../../../../core/design/design.dart';

/// One curriculum (`/curriculum/:id`): SLOs grouped by strand and the standards mapping. Read-only.
class CurriculumDetailScreen extends GetView<CurriculumDetailController> {
  const CurriculumDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return EmScaffold(
      appBar: EmAppBar(title: 'Curriculum'),
      body: Obx(() {
        final c = controller;
        return ScreenStateView<Curriculum>(
          state: c.state.value,
          onRefresh: () => c.load(force: true),
          onRetry: () => c.load(force: true),
          emptyTitle: 'Not found',
          builder: _content,
        );
      }),
    );
  }

  List<Widget> _content(Curriculum k) {
    final strands = k.byStrand;
    final quiet = EmType.caption.copyWith(color: EmColors.textSecondary);
    final body = EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w400, height: 1.5);
    return [
      Text(k.name.isEmpty ? k.subjectName : k.name, style: EmType.title.copyWith(color: EmColors.ink)),
      const SizedBox(height: EmSpacing.s4),
      EmCaptionLine([k.gradeLevel, k.subjectName, k.academicYearLabel, k.framework].where((e) => e.isNotEmpty).join(' · ')),
      if (k.slos.isEmpty) const AppEmptyView(key: Key('cur_no_slos'), icon: Icons.list_alt_outlined, title: 'No learning outcomes listed yet'),
      for (final e in strands.entries) ...[
        SectionRow(title: '${e.key} (${e.value.length})'),
        for (final s in e.value)
          AppCard(
            key: ValueKey('slo_${s.code}'),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(s.code.isEmpty ? 'SLO' : s.code, style: EmType.label.copyWith(color: EmColors.ink))),
                if (s.bloomsLevel.isNotEmpty) ...[const SizedBox(width: EmSpacing.s8), AppTag(s.bloomsLevel.toUpperCase(), style: EmTone.info)],
              ]),
              const SizedBox(height: EmSpacing.s4),
              Text(s.description, style: body),
              if (s.isAssessed) Padding(padding: const EdgeInsets.only(top: EmSpacing.s4), child: Text(s.assessmentType.isEmpty ? 'Assessed' : 'Assessed: ${s.assessmentType}', style: quiet)),
            ]),
          ),
      ],
      if (k.standards.isNotEmpty) ...[
        const SectionRow(title: 'Standards'),
        for (final m in k.standards)
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text([m.standard, m.code].where((e) => e.isNotEmpty).join(' · '), style: EmType.label.copyWith(color: EmColors.ink)),
              if (m.description.isNotEmpty) Text(m.description, style: body),
            ]),
          ),
      ],
    ];
  }
}
