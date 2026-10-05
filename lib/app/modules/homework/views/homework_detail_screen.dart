import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/homework_controller.dart';

/// Homework - route shell (`/homework/:id`). Honest placeholder until built.
class HomeworkDetailScreen extends GetView<HomeworkController> {
  const HomeworkDetailScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Homework');
}
