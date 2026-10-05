import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/leave_controller.dart';

/// Apply for leave - route shell (`/leave/apply`). Honest placeholder until built.
class LeaveApplyScreen extends GetView<LeaveController> {
  const LeaveApplyScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Apply for leave');
}
