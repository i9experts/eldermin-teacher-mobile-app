import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/students_controller.dart';

/// My students - route shell (`/students`). Honest placeholder until built.
class StudentsScreen extends GetView<StudentsController> {
  const StudentsScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'My students');
}
