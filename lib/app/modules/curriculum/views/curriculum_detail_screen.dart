import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/assessments/reference_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/custom_text.dart';
import '../controllers/curriculum_controller.dart';

/// One curriculum (`/curriculum/:id`): SLOs grouped by strand and the standards mapping. Read-only.
class CurriculumDetailScreen extends GetView<CurriculumDetailController> {
  const CurriculumDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const CustomText(text: 'Curriculum', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
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
    return [
      CustomText(text: k.name.isEmpty ? k.subjectName : k.name, fontWeight: FontWeight.w800, color: AppColors.primaryColor, fontSize: 18),
      const SizedBox(height: 4),
      CustomText(text: [k.gradeLevel, k.subjectName, k.academicYearLabel, k.framework].where((e) => e.isNotEmpty).join(' · '), color: AppColors.muted, fontSize: 12),
      const SizedBox(height: 14),
      if (k.slos.isEmpty) const AppEmptyView(key: Key('cur_no_slos'), icon: Icons.list_alt_outlined, title: 'No learning outcomes listed yet'),
      for (final e in strands.entries) ...[
        SubHeading('${e.key} (${e.value.length})'),
        for (final s in e.value)
          AppCard(
            key: ValueKey('slo_${s.code}'),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: CustomText(text: s.code.isEmpty ? 'SLO' : s.code, fontWeight: FontWeight.w800, color: AppColors.primaryColor, fontSize: 12.5)),
                if (s.bloomsLevel.isNotEmpty) AppTag(s.bloomsLevel.toUpperCase(), style: TagStyle.info),
              ]),
              const SizedBox(height: 4),
              CustomText(text: s.description, color: AppColors.black, fontSize: 13, height: 1.4),
              if (s.isAssessed) Padding(padding: const EdgeInsets.only(top: 4), child: CustomText(text: s.assessmentType.isEmpty ? 'Assessed' : 'Assessed: ${s.assessmentType}', color: AppColors.muted, fontSize: 11.5)),
            ]),
          ),
      ],
      if (k.standards.isNotEmpty) ...[
        const SubHeading('Standards'),
        for (final m in k.standards)
          AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CustomText(text: [m.standard, m.code].where((e) => e.isNotEmpty).join(' · '), fontWeight: FontWeight.w800, color: AppColors.primaryColor, fontSize: 12.5),
            if (m.description.isNotEmpty) CustomText(text: m.description, color: AppColors.black, fontSize: 12.5, height: 1.4),
          ])),
      ],
    ];
  }
}
