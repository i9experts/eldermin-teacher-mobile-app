import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/messages_controller.dart';

/// Messages - route shell (`/home/messages`). Honest placeholder until built.
class MessagesScreen extends GetView<MessagesController> {
  final bool embedded;
  const MessagesScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) => ComingSoonScreen(title: 'Messages', embedded: embedded);
}
