import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/attendance_controller.dart';

/// Attendance history - route shell (`/attendance/history`). Honest placeholder until built.
class AttendanceHistoryScreen extends GetView<AttendanceController> {
  const AttendanceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Attendance history');
}
