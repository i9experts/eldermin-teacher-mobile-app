import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/syllabus_controller.dart';

/// Syllabus - route shell (`/syllabus`). Honest placeholder until built.
class SyllabusScreen extends GetView<SyllabusController> {
  const SyllabusScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Syllabus');
}
