import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/notifications_controller.dart';

/// Notifications - route shell (`/notifications`). Honest placeholder until built.
class NotificationsScreen extends GetView<NotificationsController> {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Notifications');
}
