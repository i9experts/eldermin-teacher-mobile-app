import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/assessments_controller.dart';

/// Enter marks - route shell (`/assessments/:id/marks`). Honest placeholder until built.
class AssessmentMarksScreen extends GetView<AssessmentsController> {
  const AssessmentMarksScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Enter marks');
}
