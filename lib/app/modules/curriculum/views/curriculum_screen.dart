import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/curriculum_controller.dart';

/// Curriculum - route shell (`/curriculum`). Honest placeholder until built.
class CurriculumScreen extends GetView<CurriculumController> {
  const CurriculumScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Curriculum');
}
