import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/students_controller.dart';

/// Student 360 - route shell (`/students/:id`). Honest placeholder until built.
class StudentDetailScreen extends GetView<StudentsController> {
  const StudentDetailScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Student 360');
}
