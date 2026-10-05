import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/student_leaves_controller.dart';

/// Leave request - route shell (`/student-leaves/:id`). Honest placeholder until built.
class StudentLeaveDetailScreen extends GetView<StudentLeavesController> {
  const StudentLeaveDetailScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Leave request');
}
