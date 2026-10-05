import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/leave_controller.dart';

/// My leave - route shell (`/leave`). Honest placeholder until built.
class LeaveScreen extends GetView<LeaveController> {
  const LeaveScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'My leave');
}
