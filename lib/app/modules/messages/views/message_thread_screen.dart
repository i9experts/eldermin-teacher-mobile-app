import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/messages_controller.dart';

/// Conversation - route shell (`/messages/:threadId`). Honest placeholder until built.
class MessageThreadScreen extends GetView<MessagesController> {
  const MessageThreadScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Conversation');
}
