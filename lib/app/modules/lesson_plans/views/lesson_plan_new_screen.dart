import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/lesson_plans_controller.dart';

/// New lesson plan - route shell (`/lesson-plans/new`). Honest placeholder until built.
class LessonPlanNewScreen extends GetView<LessonPlansController> {
  const LessonPlanNewScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'New lesson plan');
}
