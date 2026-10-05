import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/help_controller.dart';

/// Help - route shell (`/help`). Honest placeholder until built.
class HelpScreen extends GetView<HelpController> {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Help');
}
