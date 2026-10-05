import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/about_controller.dart';

/// About - route shell (`/about`). Honest placeholder until built.
class AboutScreen extends GetView<AboutController> {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'About');
}
