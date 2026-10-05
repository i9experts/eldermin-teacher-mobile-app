import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/attendance_controller.dart';

/// Attendance - route shell (`/attendance`). Honest placeholder until built.
class AttendanceScreen extends GetView<AttendanceController> {
  final bool embedded;
  const AttendanceScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) => ComingSoonScreen(title: 'Attendance', embedded: embedded);
}
