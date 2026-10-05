import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/assessments_controller.dart';

/// Assessments - route shell (`/assessments`). Honest placeholder until built.
class AssessmentsScreen extends GetView<AssessmentsController> {
  const AssessmentsScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Assessments');
}
