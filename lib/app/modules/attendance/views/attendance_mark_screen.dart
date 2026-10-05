import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/attendance_controller.dart';

/// Mark attendance - route shell (`/attendance/mark`). Honest placeholder until built.
class AttendanceMarkScreen extends GetView<AttendanceController> {
  const AttendanceMarkScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Mark attendance');
}
