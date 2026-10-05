import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/events_controller.dart';

/// Event - route shell (`/events/:id`). Honest placeholder until built.
class EventDetailScreen extends GetView<EventsController> {
  const EventDetailScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Event');
}
