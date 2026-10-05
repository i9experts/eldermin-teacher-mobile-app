import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/lesson_plans_controller.dart';

/// Upload lesson plan - route shell (`/lesson-plans/upload`). Honest placeholder until built.
class LessonPlanUploadScreen extends GetView<LessonPlansController> {
  const LessonPlanUploadScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Upload lesson plan');
}
