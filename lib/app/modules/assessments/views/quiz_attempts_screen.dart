import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/assessments_controller.dart';

/// Quiz attempts - route shell (`/assessments/quiz-attempts`). Honest placeholder until built.
class QuizAttemptsScreen extends GetView<AssessmentsController> {
  const QuizAttemptsScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Quiz attempts');
}
