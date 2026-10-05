import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/homework_controller.dart';

/// Submissions - route shell (`/homework/:id/submissions`). Honest placeholder until built.
class HomeworkSubmissionsScreen extends GetView<HomeworkController> {
  const HomeworkSubmissionsScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Submissions');
}
