import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/calendar_controller.dart';

/// School calendar - route shell (`/calendar`). Honest placeholder until built.
class CalendarScreen extends GetView<CalendarController> {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'School calendar');
}
