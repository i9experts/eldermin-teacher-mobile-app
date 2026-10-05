import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/student_leaves_controller.dart';

/// Student leave requests - route shell (`/student-leaves`). Honest placeholder until built.
class StudentLeavesScreen extends GetView<StudentLeavesController> {
  const StudentLeavesScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Student leave requests');
}
