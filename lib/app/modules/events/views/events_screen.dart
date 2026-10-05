import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/events_controller.dart';

/// Events - route shell (`/events`). Honest placeholder until built.
class EventsScreen extends GetView<EventsController> {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Events');
}
