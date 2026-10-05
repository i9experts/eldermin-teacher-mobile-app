import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/lesson_plans_controller.dart';

/// Lesson plans - route shell (`/lesson-plans`). Honest placeholder until built.
class LessonPlansScreen extends GetView<LessonPlansController> {
  const LessonPlansScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Lesson plans');
}
