import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/timetable_controller.dart';

/// Timetable - route shell (`/timetable`). Honest placeholder until built.
class TimetableScreen extends GetView<TimetableController> {
  final bool embedded;
  const TimetableScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) => ComingSoonScreen(title: 'Timetable', embedded: embedded);
}
