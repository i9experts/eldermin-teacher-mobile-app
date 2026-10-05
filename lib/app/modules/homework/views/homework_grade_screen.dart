import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/homework_controller.dart';

/// Grade submission - route shell (`/homework/:id/submissions/:sid/grade`). Honest placeholder until built.
class HomeworkGradeScreen extends GetView<HomeworkController> {
  const HomeworkGradeScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Grade submission');
}
