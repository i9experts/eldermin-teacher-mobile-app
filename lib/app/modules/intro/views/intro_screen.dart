import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/intro_controller.dart';

/// Welcome - route shell (`/intro`). Honest placeholder until built.
class IntroScreen extends GetView<IntroController> {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Welcome');
}
