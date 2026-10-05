import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/lesson_plans_controller.dart';

/// Lesson plan - route shell (`/lesson-plans/:id`). Honest placeholder until built.
class LessonPlanDetailScreen extends GetView<LessonPlansController> {
  const LessonPlanDetailScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Lesson plan');
}
