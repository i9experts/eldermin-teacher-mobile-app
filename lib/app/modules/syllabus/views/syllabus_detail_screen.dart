import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/syllabus_controller.dart';

/// Syllabus - route shell (`/syllabus/:id`). Honest placeholder until built.
class SyllabusDetailScreen extends GetView<SyllabusController> {
  const SyllabusDetailScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Syllabus');
}
